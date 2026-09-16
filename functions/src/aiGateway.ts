import { logger } from './config/logger';
import {
  NvidiaChatMessage,
  ToolSpec,
  buildSystemPrompt,
  llmPost,
  llmPostStream,
  nvidiaProvider,
} from './nvidia';

export type AiTier = 'main' | 'general' | 'fast' | 'vision' | 'safety' | 'creative';

export type AiErrorKind =
  | 'no_key'
  | 'timeout'
  | 'rate_limited'
  | 'http'
  | 'network'
  | 'malformed'
  | 'empty'
  | 'unsupported'
  | 'unknown';

export class AiGatewayError extends Error {
  readonly kind: AiErrorKind;
  constructor(kind: AiErrorKind, message: string) {
    super(message);
    this.kind = kind;
  }
}

export type ChatTier = Exclude<AiTier, 'safety' | 'vision'>;

export interface AiModelConfig {
  main: string;
  general: string;
  fast: string;
  vision: string;
  safety: string;
  creative: string;
}

export const AI_MODELS: AiModelConfig = {
  main: process.env.AI_MODEL_MAIN ?? 'nvidia/nemotron-3-ultra-550b-a55b',
  general:
    process.env.AI_MODEL_GENERAL ?? 'nvidia/nemotron-3.5-lightning-30b-a3b',
  fast: process.env.AI_MODEL_FAST ?? 'nvidia/nemotron-3.5-lightning-30b-a3b',
  vision:
    process.env.AI_MODEL_VISION ??
    'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning',
  safety:
    process.env.AI_MODEL_SAFETY ?? 'nvidia/nemotron-3.5-content-safety',
  creative:
    process.env.AI_MODEL_CREATIVE ?? 'nvidia/nemotron-3-ultra-550b-a55b',
};

function activeModelFor(tier: AiTier): string {
  return AI_MODELS[tier];
}

const TIER_TIMEOUT_MS: Record<AiTier, number> = {
  main: 240_000,
  general: 60_000,
  fast: 45_000,
  vision: 120_000,
  safety: 60_000,
  creative: 240_000,
};

const TIER_MAX_RETRIES: Record<AiTier, number> = {
  main: 2,
  general: 1,
  fast: 1,
  vision: 1,
  safety: 1,
  creative: 1,
};

// Per-tier output cap. Fast/simple requests never need more than ~512 tokens;
// general answers top out at ~1024; only main/creative (long analysis) allow
// the full budget. This bounds prompt latency for the common fast path.
const TIER_MAX_TOKENS: Record<AiTier, number> = {
  main: 4096,
  general: 1024,
  fast: 512,
  vision: 4096,
  safety: 60,
  creative: 4096,
};

// Keep only the last N non-system messages so prompt size (and therefore
// NVIDIA latency) stays bounded across long conversations.
const MAX_HISTORY_MESSAGES = 8;

const FALLBACK_CHAINS: Record<AiTier, AiTier[]> = {
  main: ['main', 'general'],
  general: ['general', 'main'],
  fast: ['fast', 'main'],
  vision: ['vision', 'main'],
  safety: ['safety'],
  creative: ['creative', 'general'],
};

const RETRY_DELAYS_MS = [600, 1800];

function providerFor(tier: AiTier) {
  try {
    return nvidiaProvider(activeModelFor(tier));
  } catch {
    throw new AiGatewayError(
      'no_key',
      'NVIDIA_API_KEY is not configured on the server.',
    );
  }
}

function fallbackChainFor(tier: AiTier): AiTier[] {
  const seen = new Set<string>();
  return (FALLBACK_CHAINS[tier] ?? [tier]).filter((candidate) => {
    const model = activeModelFor(candidate);
    if (seen.has(model)) return false;
    seen.add(model);
    return true;
  });
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function classifyError(e: unknown): AiGatewayError {
  if (e instanceof AiGatewayError) return e;
  const err = e as {
    response?: { status?: number };
    code?: string;
    message?: string;
  };
  const status = err?.response?.status;
  if (status === 429) {
    return new AiGatewayError(
      'rate_limited',
      'The NVIDIA AI service is rate-limiting requests right now.',
    );
  }
  if (status) {
    return new AiGatewayError(
      'http',
      `NVIDIA AI service returned HTTP ${status}.`,
    );
  }
  const code = err?.code ?? '';
  const message = String(err?.message ?? '');
  if (code === 'ECONNABORTED' || /timeout/i.test(message)) {
    return new AiGatewayError(
      'timeout',
      'The NVIDIA AI service took too long to respond.',
    );
  }
  if (
    code === 'ENOTFOUND' ||
    code === 'ECONNREFUSED' ||
    code === 'ECONNRESET' ||
    code === 'EAI_AGAIN'
  ) {
    return new AiGatewayError('network', 'Could not reach the NVIDIA AI service.');
  }
  return new AiGatewayError('unknown', 'NVIDIA AI request failed.');
}

function isRetryable(e: AiGatewayError): boolean {
  return (
    e.kind === 'timeout' ||
    e.kind === 'network' ||
    e.kind === 'rate_limited' ||
    (e.kind === 'http' &&
      /HTTP (408|409|425|429|500|502|503|504)/.test(e.message))
  );
}

function logAiCall(event: Record<string, unknown>): void {
  logger.info('ai_gateway', event);
}

export interface TierAttempt<T> {
  value: T;
  model: string;
}

export interface TierRunOutcome<T> {
  value: T;
  model: string;
  triedTiers: AiTier[];
  retries: number;
}

export async function runWithFallback<T>(
  tier: AiTier,
  fn: (t: AiTier) => Promise<TierAttempt<T>>,
): Promise<TierRunOutcome<T>> {
  const chain = fallbackChainFor(tier);
  const triedTiers: AiTier[] = [];
  let retries = 0;
  let lastError = new AiGatewayError('unknown', 'NVIDIA AI request failed.');

  for (const t of chain) {
    triedTiers.push(t);
    const maxRetries = TIER_MAX_RETRIES[t];
    let attempts = 0;
    for (;;) {
      attempts += 1;
      try {
        const attempt = await fn(t);
        return {
          value: attempt.value,
          model: attempt.model,
          triedTiers,
          retries,
        };
      } catch (e) {
        const classified = classifyError(e);
        lastError = classified;
        const canRetry =
          attempts <= maxRetries && isRetryable(classified);
        if (canRetry) {
          await sleep(RETRY_DELAYS_MS[Math.min(attempts - 1, RETRY_DELAYS_MS.length - 1)]);
          retries += 1;
          continue;
        }
        break;
      }
    }
  }
  throw lastError;
}

function asText(content: unknown): string {
  return typeof content === 'string' ? content.trim() : '';
}

function extractChoice(data: Record<string, unknown>) {
  const choices = Array.isArray(data.choices) ? data.choices : [];
  const first = choices[0] as
    | { message?: Record<string, unknown>; finish_reason?: unknown }
    | undefined;
  const message = first?.message;
  return {
    content: asText(message?.content),
    toolCalls:
      (message?.tool_calls as NvidiaChatMessage['tool_calls']) ?? null,
  };
}

/**
 * Bounded conversation window. Keeps the last `keep` non-system messages but
 * never splits an in-flight tool exchange (assistant tool_calls → tool results),
 * so the multi-round tool loop stays coherent across the trim boundary.
 */
function trimHistory(
  messages: NvidiaChatMessage[],
  keep: number,
): NvidiaChatMessage[] {
  const nonSystem = messages.filter((m) => m.role !== 'system');

  let lastAssistantCall = -1;
  let lastTool = -1;
  for (let i = nonSystem.length - 1; i >= 0; i -= 1) {
    if (
      lastAssistantCall < 0 &&
      nonSystem[i].role === 'assistant' &&
      (nonSystem[i].tool_calls?.length ?? 0) > 0
    ) {
      lastAssistantCall = i;
    }
    if (lastTool < 0 && nonSystem[i].role === 'tool') lastTool = i;
    if (lastAssistantCall >= 0 && lastTool >= 0) break;
  }

  let start = Math.max(0, nonSystem.length - keep);
  const exchangeStart =
    lastAssistantCall >= 0 ? lastAssistantCall : lastTool >= 0 ? lastTool : -1;
  if (exchangeStart >= 0 && exchangeStart < start) {
    start = exchangeStart;
  }

  return nonSystem.slice(start);
}

/** Extra system instruction for the fast tier: brevity without losing intent. */
const FAST_BRIEF_PROMPT =
  '\nKeep answers brief: for simple questions respond concisely in 1-4 short, ' +
  'practical sentences, and go into more detail only when the farmer explicitly asks for it.';

function buildChatMessages(
  opts: ChatRouterOptions,
  tier: ChatTier,
): NvidiaChatMessage[] {
  const system = buildSystemPrompt(opts.language, opts.context);
  const content = tier === 'fast' ? `${system}${FAST_BRIEF_PROMPT}` : system;
  return [
    { role: 'system', content },
    ...trimHistory(opts.messages, MAX_HISTORY_MESSAGES),
  ];
}

function extractJsonObjectWithKey<T extends Record<string, unknown>>(
  content: string,
  key: string,
): T {
  let cleaned = content
    .trim()
    .replace(/^\`\`\`(?:json)?/i, '')
    .replace(/\`\`\`\s*$/, '')
    .trim();

  const keyIdx = cleaned.indexOf(`"${key}"`);
  if (keyIdx >= 0) {
    const openIdx = cleaned.lastIndexOf('{', keyIdx);
    if (openIdx >= 0) {
      let depth = 0;
      let inString = false;
      let escape = false;
      for (let i = openIdx; i < cleaned.length; i++) {
        const ch = cleaned[i];
        if (inString) {
          if (escape) {
            escape = false;
          } else if (ch === '\\') {
            escape = true;
          } else if (ch === '"') {
            inString = false;
          }
          continue;
        }
        if (ch === '"') inString = true;
        if (ch === '{') depth += 1;
        if (ch === '}') {
          depth -= 1;
          if (depth === 0) {
            return JSON.parse(cleaned.slice(openIdx, i + 1)) as T;
          }
        }
      }
    }
  }

  cleaned = cleaned.replace(/,\s*([}\]])/g, '$1');
  try {
    return JSON.parse(cleaned) as T;
  } catch {
    const start = cleaned.indexOf('{');
    const end = cleaned.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return JSON.parse(cleaned.slice(start, end + 1)) as T;
    }
    throw new AiGatewayError('malformed', 'NVIDIA returned malformed JSON.');
  }
}

export interface IntentClassification {
  intent: string;
  complexity: 'low' | 'medium' | 'high';
  tier: ChatTier;
  label?: string;
  classifiedBy: 'model' | 'rules';
}

const COMPLEX_WORDS = [
  'recommend',
  'plan',
  'compare',
  'why ',
  'should',
  ' best ',
  'analy',
  'strategy',
  'profit',
  'rotation',
  'disease',
  'pesticid',
  'yield',
  'forecast',
  'because',
  'how to',
  'scheme',
  'subsid',
  'loan',
];

const SIMPLE_WORDS = [
  'hi',
  'hello',
  'hey',
  'namaste',
  'open',
  'show',
  'weather',
  'price',
  'market',
  'task',
  'diary',
  'community',
  'home',
  'back',
  'help',
  'thanks',
  'thank',
  'ok',
  'yes',
  'no',
];

export function ruleClassify(text: string): IntentClassification {
  const lower = ` ${text.toLowerCase()} `;
  const len = lower.trim().length;
  if (COMPLEX_WORDS.some((w) => lower.includes(w)) || len > 220) {
    return {
      intent: 'complex_query',
      complexity: 'high',
      tier: 'main',
      classifiedBy: 'rules',
    };
  }
  if (SIMPLE_WORDS.some((w) => lower.includes(w)) && len < 60) {
    return {
      intent: 'simple_command',
      complexity: 'low',
      tier: 'fast',
      classifiedBy: 'rules',
    };
  }
  const complexity = len < 80 ? 'low' : 'medium';
  return {
    intent: 'general_chat',
    complexity,
    tier: complexity === 'low' ? 'fast' : 'general',
    classifiedBy: 'rules',
  };
}

export interface ClassifyOptions {
  text: string;
  language?: string;
  useModel?: boolean;
  label?: string;
}

export async function classifyIntent(
  opts: ClassifyOptions,
): Promise<IntentClassification> {
  const fallback = ruleClassify(opts.text);
  if (!opts.useModel) return fallback;

  try {
    const provider = providerFor('fast');
    const data = await llmPost<Record<string, unknown>>(
      '/chat/completions',
      {
        model: provider.model,
        messages: [
          {
            role: 'system',
            content:
              'Classify this VidhAI user request. Return JSON only with intent and complexity. ' +
              'Allowed intents: simple_command, navigation, weather, market_prices, crop_advice, ' +
              'pest_disease, loan_scheme, community, general_chat, complex_query. ' +
              'Allowed complexity: low, medium, high.',
          },
          { role: 'user', content: opts.text },
        ],
        temperature: 0,
        max_tokens: 300,
        response_format: { type: 'json_object' },
      },
      provider,
      { timeout: TIER_TIMEOUT_MS.fast },
    );

    const parsed = extractJsonObjectWithKey<{
      intent?: unknown;
      complexity?: unknown;
    }>(extractChoice(data).content, 'intent');

    const intent =
      typeof parsed.intent === 'string'
        ? parsed.intent
        : opts.label ?? 'general_chat';
    const complexity = ['low', 'medium', 'high'].includes(
      String(parsed.complexity),
    )
      ? (String(parsed.complexity) as IntentClassification['complexity'])
      : fallback.complexity;
    const tier: ChatTier =
      complexity === 'high' || intent === 'complex_query'
        ? 'main'
        : complexity === 'low'
          ? 'fast'
          : 'general';

    return {
      intent,
      complexity,
      tier,
      label: opts.label,
      classifiedBy: 'model',
    };
  } catch (e) {
    logger.warn('NVIDIA intent classifier fell back to rules', {
      error: String(e),
    });
    return fallback;
  }
}

export interface ChatRouterOptions {
  messages: NvidiaChatMessage[];
  language?: string;
  context?: Record<string, unknown>;
  tools?: ToolSpec[];
  tier?: ChatTier;
  classify?: boolean;
  complexity?: 'low' | 'medium' | 'high';
  intent?: string;
  label?: string;
}

export interface ChatRouterResult {
  content: string;
  toolCalls: NvidiaChatMessage['tool_calls'] | null;
  model: string;
  tier: AiTier;
  triedTiers: AiTier[];
  retries: number;
  classification: {
    intent: string;
    complexity: string;
    tier: AiTier;
    classifiedBy: string;
  };
}

async function classifyRequest(
  opts: ChatRouterOptions,
  userText: string,
): Promise<IntentClassification> {
  if (opts.tier) {
    return {
      intent: opts.intent ?? 'explicit',
      complexity: opts.complexity ?? 'medium',
      tier: opts.tier,
      classifiedBy: 'rules',
    };
  }
  if (opts.classify) {
    return classifyIntent({
      text: userText,
      language: opts.language,
      useModel: true,
      label: opts.label,
    });
  }
  if (opts.complexity === 'high' || opts.intent === 'complex_query') {
    return {
      intent: opts.intent ?? 'complex_query',
      complexity: 'high',
      tier: 'main',
      classifiedBy: 'rules',
    };
  }
  return ruleClassify(userText);
}

export async function chatWithRouter(
  opts: ChatRouterOptions,
): Promise<ChatRouterResult> {
  const lastUser = [...opts.messages].reverse().find((m) => m.role === 'user');
  const userText = lastUser?.content ?? '';

  const classification = await classifyRequest(opts, userText);
  const tier = classification.tier;
  const messages = buildChatMessages(opts, tier);

  const startedAt = Date.now();
  const outcome = await runWithFallback<{
    content: string;
    toolCalls: NvidiaChatMessage['tool_calls'] | null;
  }>(tier, async (candidateTier) => {
    const provider = providerFor(candidateTier);
    const body: Record<string, unknown> = {
      model: provider.model,
      messages,
      temperature: 0.4,
      max_tokens: TIER_MAX_TOKENS[candidateTier],
    };
    if (opts.tools?.length) body.tools = opts.tools;

    const data = await llmPost<Record<string, unknown>>(
      '/chat/completions',
      body,
      provider,
      { timeout: TIER_TIMEOUT_MS[candidateTier] },
    );
    const extracted = extractChoice(data);
    if (!extracted.content && !extracted.toolCalls) {
      throw new AiGatewayError(
        'empty',
        `${activeModelFor(candidateTier)} returned no content.`,
      );
    }
    return {
      value: {
        content: extracted.content,
        toolCalls: extracted.toolCalls,
      },
      model: provider.model,
    };
  });

  logAiCall({
    event: 'chat',
    tier,
    triedTiers: outcome.triedTiers,
    retries: outcome.retries,
    model: outcome.model,
    msgCount: messages.length,
    promptChars: messages.reduce(
      (sum, m) => sum + (typeof m.content === 'string' ? m.content.length : 0),
      0,
    ),
    latencyMs: Date.now() - startedAt,
    intent: classification.intent,
    complexity: classification.complexity,
    classifiedBy: classification.classifiedBy,
  });

  return {
    content: outcome.value.content,
    toolCalls: outcome.value.toolCalls,
    model: outcome.model,
    tier: outcome.triedTiers[outcome.triedTiers.length - 1],
    triedTiers: outcome.triedTiers,
    retries: outcome.retries,
    classification: {
      intent: classification.intent,
      complexity: classification.complexity,
      tier: classification.tier,
      classifiedBy: classification.classifiedBy,
    },
  };
}

export interface ChatRouterStreamResult {
  content: string;
  toolCalls: NvidiaChatMessage['tool_calls'] | null;
  model: string;
  tier: AiTier;
  triedTiers: AiTier[];
  retries: number;
  ttfMs: number;
  classification: {
    intent: string;
    complexity: string;
    tier: AiTier;
    classifiedBy: string;
  };
}

/**
 * Streaming chat route: identical routing/prompt policy to [chatWithRouter],
 * but forwards NVIDIA text deltas through [onDelta] and returns the final
 * content/tool calls from the stream.
 *
 * Retries and tier fallback only happen for failures BEFORE the first token is
 * emitted. Once the client has seen a delta, a mid-stream failure aborts with
 * an error instead of duplicating output.
 */
export async function chatWithRouterStream(
  opts: ChatRouterOptions,
  onDelta: (content: string) => void,
): Promise<ChatRouterStreamResult> {
  const lastUser = [...opts.messages].reverse().find((m) => m.role === 'user');
  const userText = lastUser?.content ?? '';

  const classification = await classifyRequest(opts, userText);
  const tier = classification.tier;
  const messages = buildChatMessages(opts, tier);

  const startedAt = Date.now();
  let ttfMs = 0;

  const outcome = await runWithFallback<{
    content: string;
    toolCalls: NvidiaChatMessage['tool_calls'] | null;
  }>(tier, async (candidateTier) => {
    const provider = providerFor(candidateTier);
    const body: Record<string, unknown> = {
      model: provider.model,
      messages,
      temperature: 0.4,
      max_tokens: TIER_MAX_TOKENS[candidateTier],
    };
    if (opts.tools?.length) body.tools = opts.tools;

    let streamedAny = false;
    try {
      const result = await llmPostStream(
        '/chat/completions',
        body,
        provider,
        (content) => {
          if (!streamedAny) {
            streamedAny = true;
            ttfMs = Date.now() - startedAt;
          }
          onDelta(content);
        },
        { timeout: TIER_TIMEOUT_MS[candidateTier] },
      );
      if (!result.content && !result.toolCalls) {
        throw new AiGatewayError(
          'empty',
          `${activeModelFor(candidateTier)} returned no content.`,
        );
      }
      return {
        value: { content: result.content, toolCalls: result.toolCalls },
        model: provider.model,
      };
    } catch (e) {
      if (streamedAny) {
        // Never retry or fall back once the client has begun receiving text.
        throw new AiGatewayError(
          'unknown',
          'NVIDIA interrupted the response mid-stream.',
        );
      }
      throw e;
    }
  });

  logAiCall({
    event: 'chat_stream',
    stream: true,
    tier,
    triedTiers: outcome.triedTiers,
    retries: outcome.retries,
    model: outcome.model,
    msgCount: messages.length,
    promptChars: messages.reduce(
      (sum, m) => sum + (typeof m.content === 'string' ? m.content.length : 0),
      0,
    ),
    ttfMs,
    latencyMs: Date.now() - startedAt,
    intent: classification.intent,
    complexity: classification.complexity,
    classifiedBy: classification.classifiedBy,
  });

  const usedTier = outcome.triedTiers[outcome.triedTiers.length - 1];
  return {
    content: outcome.value.content,
    toolCalls: outcome.value.toolCalls,
    model: outcome.model,
    tier: usedTier,
    triedTiers: outcome.triedTiers,
    retries: outcome.retries,
    ttfMs,
    classification: {
      intent: classification.intent,
      complexity: classification.complexity,
      tier: classification.tier,
      classifiedBy: classification.classifiedBy,
    },
  };
}

export interface VisionImage {
  base64: string;
  mimeType: string;
}

export interface VisionAnalyzeOptions {
  prompt: string;
  images: VisionImage[];
  language?: string;
}

export interface VisionAnalyzeResult {
  content: string;
  model: string;
  provider: 'nvidia';
  fallbackUsed: string[];
}

export async function visionAnalyze(
  opts: VisionAnalyzeOptions,
): Promise<VisionAnalyzeResult> {
  const languageLine = opts.language
    ? ` Respond in the language: ${opts.language}.`
    : '';
  const system =
    'You are VidhAI, an agricultural image analyst for Indian farmers. ' +
    'Give practical, farmer-friendly guidance. This is an AI-based assessment, not a confirmed diagnosis. ' +
    'If the image is unclear or insufficient, say so. Never invent a diagnosis with false certainty.' +
    languageLine;

  const outcome = await runWithFallback<{ content: string }>(
    'vision',
    async (tier) => {
      const provider = providerFor(tier);
      const parts: Array<Record<string, unknown>> = [
        {
          type: 'text',
          text: `${system}\n\nUser request: ${opts.prompt}`,
        },
      ];
      for (const image of opts.images) {
        parts.push({
          type: 'image_url',
          image_url: {
            url: `data:${image.mimeType};base64,${image.base64}`,
          },
        });
      }

      const data = await llmPost<Record<string, unknown>>(
        '/chat/completions',
        {
          model: provider.model,
          messages: [{ role: 'user', content: parts }],
          temperature: 0.3,
          max_tokens: 4096,
        },
        provider,
        { timeout: TIER_TIMEOUT_MS[tier] },
      );
      const content = extractChoice(data).content;
      if (!content) {
        throw new AiGatewayError(
          'empty',
          `${activeModelFor(tier)} returned no analysis.`,
        );
      }
      return {
        value: { content },
        model: provider.model,
      };
    },
  );

  return {
    content: outcome.value.content,
    model: outcome.model,
    provider: 'nvidia',
    fallbackUsed: outcome.triedTiers.filter((tier) => tier !== 'vision'),
  };
}

export interface ModerationResult {
  safe: boolean;
  label: string;
  reviewed: boolean;
  model: string;
}

export async function moderateText(
  text: string,
): Promise<ModerationResult> {
  const trimmed = text.trim();
  if (!trimmed) {
    return {
      safe: true,
      label: 'safe',
      reviewed: true,
      model: AI_MODELS.safety,
    };
  }

  try {
    const provider = providerFor('safety');
    const data = await llmPost<Record<string, unknown>>(
      '/chat/completions',
      {
        model: provider.model,
        messages: [
          {
            role: 'system',
            content:
              'Classify text for a farming community app. Reply with exactly: User Safety: safe OR User Safety: unsafe.',
          },
          { role: 'user', content: trimmed },
        ],
        temperature: 0,
        max_tokens: 60,
      },
      provider,
      { timeout: TIER_TIMEOUT_MS.safety },
    );
    const response = extractChoice(data).content.toLowerCase();
    const safe = !response.includes('unsafe');
    return {
      safe,
      label: safe ? 'safe' : 'unsafe',
      reviewed: true,
      model: provider.model,
    };
  } catch (e) {
    logger.warn('NVIDIA moderation unavailable, failing open', {
      error: String(e),
    });
    return {
      safe: true,
      label: 'safe',
      reviewed: false,
      model: AI_MODELS.safety,
    };
  }
}

export function httpStatusFor(error: AiGatewayError): number {
  switch (error.kind) {
    case 'timeout':
      return 504;
    case 'rate_limited':
      return 429;
    case 'http':
      return 502;
    case 'malformed':
      return 502;
    case 'no_key':
      return 500;
    default:
      return 500;
  }
}
