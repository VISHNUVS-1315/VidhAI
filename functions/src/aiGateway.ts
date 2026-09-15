import axios from 'axios';

import { logger } from './config/logger';

import {
  GroqChatMessage,
  ToolSpec,
  buildSystemPrompt,
  groqStt,
  llmPost,
  nvidiaProvider,
} from './groq';
import { deepgramStt } from './deepgram';
import { geminiVision, VisionImage } from './gemini';
import { googleTts, TtsResult } from './tts';

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
  stt: string;
}

// Temporary routing switch: DeepSeek V4 Flash (AI_MODELS.general) repeatedly
// times out and stalls the fallback chain, so it is DISABLED by default. The
// model id and its dedicated key (AI_KEY_GENERAL) stay configured below â€” set
// ENABLE_DEEPSEEK=true (in .secret.local / env) to route the `general` tier
// back to DeepSeek once its latency improves.
const ENABLE_DEEPSEEK = process.env.ENABLE_DEEPSEEK === 'true';
const LIGHTNING_MODEL = process.env.AI_MODEL_FAST ?? 'nvidia/nemotron-3.5-lightning-30b-a3b';

export const AI_MODELS: AiModelConfig = {
  main: process.env.AI_MODEL_MAIN ?? 'nvidia/nemotron-3-ultra-550b-a55b',
  general: process.env.AI_MODEL_GENERAL ?? 'deepseek-ai/deepseek-v4-flash-0731',
  fast: process.env.AI_MODEL_FAST ?? 'nvidia/nemotron-3.5-lightning-30b-a3b',
  vision: process.env.AI_MODEL_VISION ?? 'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning',
  safety: process.env.AI_MODEL_SAFETY ?? 'nvidia/nemotron-3.5-content-safety',
  creative: process.env.AI_MODEL_CREATIVE ?? 'meta/muse-glimmer-30b',
  stt: process.env.AI_MODEL_STT ?? 'whisper-large-v3-turbo',
};

/** Model actually served for a tier. While DeepSeek is disabled the `general`
 *  tier is served by Nemotron Lightning instead of DeepSeek V4 Flash, so no
 *  request ever waits on (or falls back to) DeepSeek. */
function activeModelFor(tier: AiTier): string {
  if (!ENABLE_DEEPSEEK && tier === 'general') return LIGHTNING_MODEL;
  return AI_MODELS[tier];
}

const TIER_TIMEOUT_MS: Record<AiTier, number> = {
  main: 240_000,
  general: 45_000,
  fast: 45_000,
  vision: 120_000,
  safety: 60_000,
  creative: 300_000,
};

const TIER_MAX_RETRIES: Record<AiTier, number> = {
  main: 2,
  general: 1,
  fast: 1,
  vision: 1,
  safety: 1,
  creative: 0,
};

const FALLBACK_CHAINS: Record<AiTier, AiTier[]> = {
  main: ['main', 'general', 'fast'],
  general: ['general', 'fast', 'main'],
  fast: ['fast', 'general', 'main'],
  vision: ['vision', 'main'],
  safety: ['safety'],
  creative: ['creative', 'main', 'general'],
};

/** Active fallback chain for a tier. While DeepSeek is disabled, `general` and
 *  `fast` are the same Lightning model, so repeating tiers that resolve to the
 *  same model are dropped (e.g. general -> [general, fast, main] becomes
 *  [general, main]). DeepSeek is never on the active chain. */
function fallbackChainFor(tier: AiTier): AiTier[] {
  if (ENABLE_DEEPSEEK) return FALLBACK_CHAINS[tier] ?? [tier];
  const seenModels = new Set<string>();
  return (FALLBACK_CHAINS[tier] ?? [tier]).filter((t) => {
    const model = activeModelFor(t);
    if (seenModels.has(model)) return false;
    seenModels.add(model);
    return true;
  });
}

const RETRY_DELAYS_MS = [600, 1800];

const AURA_VOICES: Record<string, string> = {
  en: 'aura-asteria-en',
  hi: 'aura-hindi',
  ta: 'aura-tamil',
  te: 'aura-telugu',
  mr: 'aura-marathi',
  bn: 'aura-bengali',
  gu: 'aura-gujarati',
  kn: 'aura-kannada',
  ml: 'aura-malayalam',
  pa: 'aura-punjabi',
  or: 'aura-odia',
};

function tierKey(tier: AiTier): string | undefined {
  const override = process.env[`AI_KEY_${tier.toUpperCase()}`];
  if (override) return override;
  return process.env.NVIDIA_API_KEY;
}

function providerFor(tier: AiTier) {
  const key = tierKey(tier);
  if (!key) {
    throw new AiGatewayError(
      'no_key',
      `No NVIDIA API key is configured for the '${tier}' AI tier (set NVIDIA_API_KEY).`,
    );
  }
  return nvidiaProvider(activeModelFor(tier), key);
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function classifyError(e: unknown): AiGatewayError {
  if (e instanceof AiGatewayError) return e;
  const err = e as { response?: { status?: number }; code?: string; message?: string };
  const status = err?.response?.status;
  if (status === 429) {
    return new AiGatewayError('rate_limited', 'The AI service is rate-limiting requests right now.');
  }
  if (status) {
    return new AiGatewayError('http', `AI service returned HTTP ${status}.`);
  }
  const code = err?.code ?? '';
  const message = `${err?.message ?? ''}`;
  if (code === 'ECONNABORTED' || /timeout/i.test(message)) {
    return new AiGatewayError('timeout', 'The AI service took too long to respond.');
  }
  if (code === 'ENOTFOUND' || code === 'ECONNREFUSED' || code === 'ECONNRESET' || code === 'EAI_AGAIN') {
    return new AiGatewayError('network', 'Could not reach the AI service.');
  }
  if (status || /4\d\d|5\d\d/.test(message)) {
    return new AiGatewayError('http', 'AI service request failed.');
  }
  return new AiGatewayError('unknown', 'AI request failed.');
}

function isRetryable(e: AiGatewayError): boolean {
  return (
    e.kind === 'timeout' ||
    e.kind === 'network' ||
    e.kind === 'rate_limited' ||
    (e.kind === 'http' && /HTTP (408|409|425|429|500|502|503|504)/.test(e.message))
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
  let lastError: AiGatewayError = new AiGatewayError('unknown', 'AI request failed.');
  for (const t of chain) {
    triedTiers.push(t);
    const maxRetries = TIER_MAX_RETRIES[t];
    let attempts = 0;
    for (;;) {
      attempts += 1;
      try {
        const attempt = await fn(t);
        return { value: attempt.value, model: attempt.model, triedTiers, retries };
      } catch (e) {
        const ce = classifyError(e);
        lastError = ce;
        if (ce.kind === 'no_key' || ce.kind === 'malformed' || ce.kind === 'unsupported') {
          break;
        }
        const canRetry = attempts <= maxRetries && isRetryable(ce);
        if (canRetry) {
          await sleep(RETRY_DELAYS_MS[attempts - 1]);
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

function extractJsonObjectWithKey<T extends Record<string, unknown>>(
  content: string,
  key: string,
  providerName: string,
): T {
  let cleaned = content.trim().replace(/^```(?:json)?/i, '').replace(/```\s*$/, '').trim();
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
        if (ch === '"') {
          inString = true;
        } else if (ch === '{') {
          depth += 1;
        } else if (ch === '}') {
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
    throw new Error(
      `${providerName} returned malformed JSON: ${content.slice(0, 120).replace(/\n/g, ' ')}`,
    );
  }
}

function extractChoice(data: Record<string, unknown>) {
  const choices = Array.isArray(data.choices) ? data.choices : [];
  const first = choices[0] as
    | { message?: Record<string, unknown>; finish_reason?: unknown }
    | undefined;
  const message = first?.message;
  return {
    content: asText(message?.content),
    toolCalls: (message?.tool_calls as GroqChatMessage['tool_calls']) ?? null,
    finishReason: first?.finish_reason,
  };
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
  'what is the',
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
    return { intent: 'complex_query', complexity: 'high', tier: 'main', classifiedBy: 'rules' };
  }
  if (SIMPLE_WORDS.some((w) => lower.includes(w)) && len < 60) {
    return { intent: 'simple_command', complexity: 'low', tier: 'fast', classifiedBy: 'rules' };
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

export async function classifyIntent(opts: ClassifyOptions): Promise<IntentClassification> {
  const classification = ruleClassify(opts.text);
  if (!opts.useModel) return classification;
  try {
    const provider = providerFor('fast');
    const system =
      `You are an app intent classifier for VidhAI, an agricultural assistant for Indian farmers. ` +
      `Classify the user input into one intent from this list: ` +
      `simple_command, navigation, weather, market_prices, crop_advice, pest_disease, ` +
      `loan_scheme, community, general_chat, complex_query. ` +
      `Also pick complexity: low for short everyday queries, medium for multi-part questions, ` +
      `high for deep analysis/recommendation/planning. ` +
      `Respond with JSON only: {"intent":"...","complexity":"low|medium|high","why":"one short reason"}`;
    const data = await llmPost(
      '/chat/completions',
      {
        model: provider.model,
        messages: [
          { role: 'system', content: system },
          { role: 'user', content: opts.text },
        ],
        temperature: 0,
        max_tokens: 1000,
        response_format: { type: 'json_object' },
      } as Record<string, unknown>,
      provider,
      { timeout: TIER_TIMEOUT_MS.fast },
    );
    const parsed = extractJsonObjectWithKey<{ intent?: unknown; complexity?: unknown }>(
      extractChoice(data as Record<string, unknown>).content,
      'intent',
      provider.name,
    );
    const intent = typeof parsed.intent === 'string' ? parsed.intent : opts.label ?? 'general_chat';
    const complexity = ['low', 'medium', 'high'].includes(String(parsed.complexity))
      ? (String(parsed.complexity) as IntentClassification['complexity'])
      : classification.complexity;
    const tier: Exclude<AiTier, 'safety'> =
      complexity === 'high' || intent === 'complex_query' ? 'main' : complexity === 'low' ? 'fast' : 'general';
    return { intent, complexity, tier, label: opts.label, classifiedBy: 'model' };
  } catch (e) {
    logger.warn('intent classifier model fell back to rules', { error: `${e}` });
    return classification;
  }
}

export interface ChatRouterOptions {
  messages: GroqChatMessage[];
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
  toolCalls: GroqChatMessage['tool_calls'] | null;
  model: string;
  tier: AiTier;
  triedTiers: AiTier[];
  retries: number;
  classification: { intent: string; complexity: string; tier: AiTier; classifiedBy: string } | null;
}

export async function chatWithRouter(opts: ChatRouterOptions): Promise<ChatRouterResult> {
  const lastUser = [...opts.messages].reverse().find((m) => m.role === 'user');
  const userText = lastUser?.content ?? '';
  let classification: IntentClassification | null = null;

  if (opts.tier) {
    classification = {
      intent: opts.intent ?? 'explicit',
      complexity: opts.complexity ?? 'medium',
      tier: opts.tier,
      classifiedBy: 'rules',
    };
  } else if (opts.classify) {
    classification = await classifyIntent({
      text: userText,
      language: opts.language,
      useModel: true,
      label: opts.label,
    });
  } else if (opts.complexity === 'high' || opts.intent === 'complex_query') {
    classification = {
      intent: opts.intent ?? 'complex_query',
      complexity: 'high',
      tier: 'main',
      classifiedBy: 'rules',
    };
  } else {
    classification = ruleClassify(userText);
  }

  const tier = classification.tier;
  const system = buildSystemPrompt(opts.language, opts.context);
  const messages = [
    { role: 'system', content: system } as GroqChatMessage,
    ...opts.messages.filter((m) => m.role !== 'system'),
  ];

  const startedAt = Date.now();
  const outcome = await runWithFallback<{ content: string; toolCalls: GroqChatMessage['tool_calls'] | null }>(
    tier,
    async (t) => {
      const provider = providerFor(t);
      const body: Record<string, unknown> = {
        model: provider.model,
        messages: messages as unknown as Record<string, unknown>[],
        temperature: 0.4,
        max_tokens: t === 'main' ? 4096 : t === 'creative' ? 8192 : 2048,
      };
      if (opts.tools && opts.tools.length > 0) body.tools = opts.tools as unknown as string[];
      const data = (await llmPost(
        '/chat/completions',
        body,
        provider,
        { timeout: TIER_TIMEOUT_MS[t] },
      )) as Record<string, unknown>;
      const extracted = extractChoice(data);
      if (!extracted.content && !extracted.toolCalls) {
        throw new AiGatewayError('empty', `${activeModelFor(t)} returned no content.`);
      }
      return { value: { content: extracted.content, toolCalls: extracted.toolCalls }, model: provider.model };
    },
  );

  const latencyMs = Date.now() - startedAt;
  logAiCall({
    event: 'chat',
    tier,
    triedTiers: outcome.triedTiers,
    retries: outcome.retries,
    model: outcome.model,
    intendedModel: activeModelFor(classification.tier),
    latencyMs,
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

export interface VisionAnalyzeOptions {
  prompt: string;
  images: VisionImage[];
  language?: string;
  provider?: 'nvidia' | 'gemini';
}

export interface VisionAnalyzeResult {
  content: string;
  model: string;
  provider: 'nvidia' | 'gemini';
  fallbackUsed: string[];
}

export async function visionAnalyze(opts: VisionAnalyzeOptions): Promise<VisionAnalyzeResult> {
  if (opts.provider === 'gemini') {
    const result = await geminiVision(opts.prompt, opts.images, { language: opts.language });
    return { content: result.content, model: result.model, provider: 'gemini', fallbackUsed: [] };
  }
  const langLine = opts.language ? ` Respond in the language: ${opts.language}.` : '';
  const system =
    'You are VidhAI, an agricultural image analyst for Indian farmers. Give practical, ' +
    'farmer-friendly guidance. This is an AI-based assessment, not a confirmed diagnosis. ' +
    'If the image is unclear or insufficient, say so and recommend a better photo or a local expert. ' +
    'Never invent a diagnosis with false certainty.' +
    langLine;

  try {
    const outcome = await runWithFallback<{ content: string }>('vision', async (t) => {
      const provider = providerFor(t);
      const parts: Array<Record<string, unknown>> = [{ type: 'text', text: `${system}\n\nUser request: ${opts.prompt}` }];
      for (const img of opts.images) {
        parts.push({
          type: 'image_url',
          image_url: { url: `data:${img.mimeType};base64,${img.base64}` },
        });
      }
      const data = (await llmPost(
        '/chat/completions',
        {
          model: provider.model,
          messages: [{ role: 'user', content: parts }],
          temperature: 0.3,
          max_tokens: 4096,
        } as Record<string, unknown>,
        provider,
        { timeout: TIER_TIMEOUT_MS[t] },
      )) as Record<string, unknown>;
      const content = extractChoice(data).content;
      if (!content) {
        throw new AiGatewayError('empty', `${activeModelFor(t)} returned no analysis.`);
      }
      return { value: { content }, model: provider.model };
    });
    return {
      content: outcome.value.content,
      model: outcome.model,
      provider: 'nvidia',
      fallbackUsed: outcome.triedTiers.filter((t) => t !== 'vision'),
    };
  } catch (e) {
    logger.warn('nvidia vision failed, falling back to gemini', { error: `${e}` });
    const result = await geminiVision(opts.prompt, opts.images, { language: opts.language });
    return { content: result.content, model: result.model, provider: 'gemini', fallbackUsed: ['gemini'] };
  }
}

export interface ModerationResult {
  safe: boolean;
  label: string;
  category?: string;
  reviewed: boolean;
  model: string;
}

export async function moderateText(text: string, opts: { language?: string } = {}): Promise<ModerationResult> {
  const trimmed = (text ?? '').trim();
  if (!trimmed) return { safe: true, label: 'safe', reviewed: true, model: AI_MODELS.safety };
  try {
    const provider = providerFor('safety');
    const data = (await llmPost(
      '/chat/completions',
      {
        model: provider.model,
        messages: [
          {
            role: 'system',
            content:
              'You are a content safety classifier for an Indian farming community app. ' +
              'Classify user-generated text as safe or unsafe. Unsafe includes abuse, harassment, ' +
              'hate speech, explicit content, scams, misinformation, and personal data. ' +
              'Reply with exactly one line: "User Safety: safe" or "User Safety: unsafe". Nothing else.',
          },
          { role: 'user', content: trimmed },
        ],
        temperature: 0,
        max_tokens: 60,
      } as Record<string, unknown>,
      provider,
      { timeout: TIER_TIMEOUT_MS.safety },
    )) as Record<string, unknown>;
    const response = extractChoice(data).content.toLowerCase();
    const safe = response.includes('unsafe') ? false : response.includes('safe');
    return { safe, label: safe ? 'safe' : 'unsafe', reviewed: true, model: provider.model };
  } catch (e) {
    logger.warn('moderation unavailable, failing open', { error: `${e}` });
    return { safe: true, label: 'safe', reviewed: false, model: AI_MODELS.safety };
  }
}

export type SttProvider = 'deepgram' | 'groq' | 'nvidia';

export interface SttGatewayOptions {
  language?: string;
  mime?: string;
  filename?: string;
  provider?: SttProvider | string;
}

export interface SttGatewayResult {
  text: string;
  language?: string;
  duration?: number;
  engine: 'deepgram' | 'groq';
  model: string;
}

export async function sttGateway(audio: Buffer, opts: SttGatewayOptions = {}): Promise<SttGatewayResult> {
  const requested = String(opts.provider ?? '').toLowerCase();
  const hasGroq = Boolean(process.env.GROQ_API_KEY);
  const hasDeepgram = Boolean(process.env.DEEPGRAM_API_KEY);

  if (requested === 'deepgram') {
    if (!hasDeepgram) throw new AiGatewayError('no_key', 'DEEPGRAM_API_KEY is not configured on the server.');
    const result = await deepgramStt(audio, { language: opts.language, mime: opts.mime });
    return { ...result, engine: 'deepgram', model: 'nova-3' };
  }
  if (hasGroq) {
    const result = await groqStt(audio, {
      language: opts.language,
      filename: opts.filename,
      mime: opts.mime,
    });
    return { ...result, engine: 'groq', model: AI_MODELS.stt };
  }
  if (hasDeepgram) {
    const result = await deepgramStt(audio, { language: opts.language, mime: opts.mime });
    return { ...result, engine: 'deepgram', model: 'nova-3' };
  }
  throw new AiGatewayError(
    'no_key',
    'No STT engine is configured (set GROQ_API_KEY for Whisper or DEEPGRAM_API_KEY for Nova-3).',
  );
}

export type TtsEngine = 'google' | 'deepgram';

export interface TtsGatewayOptions {
  text: string;
  language?: string;
  speakingRate?: number;
  engine?: TtsEngine | string;
}

export interface TtsGatewayResult extends TtsResult {
  engine: TtsEngine;
  model: string;
}

export async function ttsGateway(opts: TtsGatewayOptions): Promise<TtsGatewayResult> {
  const requested = String(opts.engine ?? '').toLowerCase() === 'deepgram' ? 'deepgram' : 'google';
  if (requested === 'google') {
    const result = await googleTts(opts.text, {
      language: opts.language,
      speakingRate: opts.speakingRate,
    });
    return { ...result, engine: 'google', model: result.voice };
  }
  try {
    return await deepgramTts(opts.text, { language: opts.language });
  } catch (e) {
    logger.warn('deepgram tts failed, falling back to google', { error: `${e}` });
    const result = await googleTts(opts.text, {
      language: opts.language,
      speakingRate: opts.speakingRate,
    });
    return { ...result, engine: 'google', model: result.voice };
  }
}

async function deepgramTts(
  text: string,
  opts: { language?: string },
): Promise<TtsGatewayResult> {
  const apiKey = process.env.DEEPGRAM_API_KEY;
  if (!apiKey) throw new AiGatewayError('no_key', 'DEEPGRAM_API_KEY is not configured on the server.');
  const trimmed = (text ?? '').trim();
  if (!trimmed) throw new AiGatewayError('empty', 'Empty text for TTS.');
  const lang = (opts.language ?? 'en').toLowerCase().trim();
  const model = AURA_VOICES[lang] ?? 'aura-asteria-en';
  const res = await axios.post(
    `https://api.deepgram.com/v1/speak?model=${encodeURIComponent(model)}`,
    { text: trimmed },
    {
      headers: {
        Authorization: `Token ${apiKey}`,
        'Content-Type': 'application/json',
        Accept: 'audio/mp3',
      },
      responseType: 'arraybuffer',
      timeout: 60_000,
    },
  );
  if (res.status !== 200) {
    throw new AiGatewayError('http', `Deepgram TTS returned HTTP ${res.status}.`);
  }
  const buf = Buffer.from(res.data as ArrayBuffer);
  if (!buf || buf.length === 0) {
    throw new AiGatewayError('empty', 'Deepgram returned no audio.');
  }
  return {
    audioBase64: buf.toString('base64'),
    audioContentType: 'audio/mpeg',
    voice: model,
    languageCode: opts.language ?? 'en',
    engine: 'deepgram',
    model,
  };
}

export function httpStatusFor(error: AiGatewayError): number {
  switch (error.kind) {
    case 'timeout':
      return 504;
    case 'rate_limited':
      return 429;
    case 'http':
      return 502;
    case 'no_key':
      return 500;
    case 'malformed':
      return 502;
    default:
      return 500;
  }
}