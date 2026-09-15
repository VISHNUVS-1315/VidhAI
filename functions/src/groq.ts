import axios from 'axios';

/**
 * Groq relay: OpenAI-compatible chat (GPT-OSS-20B by default, with tool
 * calling and structured JSON output) + Whisper Large V3 Turbo STT.
 * API keys live only server-side; the Flutter client never sees them.
 *
 * The model is configurable at deploy time via GROQ_MODEL so the UI never
 * needs to change when the model ID changes.
 */

const GROQ_BASE = process.env.GROQ_BASE_URL ?? 'https://api.groq.com/openai/v1';
const GROQ_MODEL = process.env.GROQ_MODEL ?? 'openai/gpt-oss-20b';
const WHISPER_MODEL = process.env.WHISPER_MODEL ?? 'whisper-large-v3-turbo';
// Optional: Groq models that support a "reasoning" tier accept this field.
// Set GROQ_REASONING=medium at deploy time to enable it; empty = default.
const REASONING_EFFORT = process.env.GROQ_REASONING?.trim() || undefined;

// NVIDIA NIM (integrate.api.nvidia.com) is an OpenAI-compatible fallback
// provider. It also hosts `openai/gpt-oss-20b`, so the SAME model id serves
// both providers and the UI/model config never needs to change.
export const NVIDIA_BASE = process.env.NVIDIA_BASE_URL ?? 'https://integrate.api.nvidia.com/v1';
const NVIDIA_MODEL = process.env.NVIDIA_MODEL ?? GROQ_MODEL;

export interface LlmProvider {
  name: 'groq' | 'nvidia';
  base: string;
  key: string;
  model: string;
  supportsReasoning: boolean;
}

/** Builds a provider handle for a specific NVIDIA-hosted model + optional key. */
export function nvidiaProvider(model: string, key?: string): LlmProvider {
  return {
    name: 'nvidia',
    base: NVIDIA_BASE,
    key: key ?? process.env.NVIDIA_API_KEY ?? '',
    model,
    supportsReasoning: false,
  };
}

/** Picks the configured LLM provider: Groq when keyed, otherwise NVIDIA. */
function resolveLlm(): LlmProvider {
  if (process.env.GROQ_API_KEY) {
    return {
      name: 'groq',
      base: GROQ_BASE,
      key: process.env.GROQ_API_KEY,
      model: GROQ_MODEL,
      supportsReasoning: true,
    };
  }
  if (process.env.NVIDIA_API_KEY) {
    return {
      name: 'nvidia',
      base: NVIDIA_BASE,
      key: process.env.NVIDIA_API_KEY,
      model: NVIDIA_MODEL,
      supportsReasoning: false,
    };
  }
  throw new Error(
    'No LLM API key is configured on the server (set GROQ_API_KEY or NVIDIA_API_KEY).',
  );
}

export interface ToolSpec {
  type: 'function';
  function: {
    name: string;
    description: string;
    parameters: Record<string, unknown>;
  };
}

export interface GroqChatMessage {
  role: 'system' | 'user' | 'assistant' | 'tool';
  content: string;
  tool_call_id?: string;
  tool_calls?: Array<{
    id: string;
    type: 'function';
    function: { name: string; arguments: string };
  }>;
}

export interface GroqChatResult {
  content: string;
  toolCalls: GroqChatMessage['tool_calls'] | null;
  model: string;
  usage?: Record<string, number>;
}

const LLM_TIMEOUT_MS = 280_000;

export async function llmPost<T>(
  path: string,
  body: Record<string, unknown>,
  provider: LlmProvider,
  opts: { timeout?: number; maxBodyLength?: number; maxContentLength?: number } = {},
): Promise<T> {
  const res = await axios.post<T>(
    `${provider.base}${path}`,
    body as unknown as string,
    {
      headers: {
        Authorization: `Bearer ${provider.key}`,
        'Content-Type': 'application/json',
      },
      timeout: opts.timeout ?? LLM_TIMEOUT_MS,
      maxBodyLength: opts.maxBodyLength ?? 150 * 1024 * 1024,
      maxContentLength: opts.maxContentLength ?? 150 * 1024 * 1024,
    },
  );
  if (res.status !== 200) {
    const err: unknown = new Error(
      `${provider.name} (${provider.model}) returned HTTP ${res.status}`,
    );
    (err as Error & { raw?: unknown }).raw = res.data;
    throw err;
  }
  return res.data;
}

/** System prompt that keeps VidhAI a practical, multilingual, farmer-friendly assistant. */
export function buildSystemPrompt(
  language: string | undefined,
  context: Record<string, unknown> | undefined,
): string {
  const langName = language ?? 'en';
  const lines: string[] = [
    'You are VidhAI, a helpful agricultural assistant for Indian farmers. You are embedded in the VidhAI app.',
    '- Be short when the question is simple; be detailed when it matters.',
    '- Use plain, farmer-friendly language. Avoid unnecessary technical jargon.',
    '- Respond in the language requested: ' + langName,
    '- When the user asks you to perform an action (open a screen, fetch prices, show weather, create a task), USE the provided tool/function rather than only explaining it.',
    '- Never invent live market prices, weather, or farm data. If a tool result is unavailable, say so honestly.',
  ];

  const profile = context?.userProfile as Record<string, unknown> | undefined;
  const farms = Array.isArray(context?.farms) ? (context.farms as Array<Record<string, unknown>>) : [];

  // Source-aware tailoring: where the user opened the assistant from.
  const source = context?.source;
  if (typeof source === 'string' && source.length > 0) {
    lines.push(`The user is on the "${source}" screen of the VidhAI app. Tailor guidance to that context.`);
  }

  if (profile) {
    const fields: string[] = [];
    if (profile['displayName'] ?? profile['fullName']) {
      fields.push(`farmer: ${profile['displayName'] ?? profile['fullName']}`);
    }
    if (profile['role']) fields.push(`console: ${profile['role']}`);
    if (fields.length > 0) lines.push('Farmer context: ' + fields.join(', '));
  }

  // Location-aware: prefer farm district/state so prices & advisories are local.
  const preferredLocation = resolveLocation(context);
  if (preferredLocation) {
    lines.push(`Farmer location (preferred for prices/weather/advice): ${preferredLocation}`);
  }

  if (farms.length > 0) {
    const summary = farms.map((f) => {
      const name = f['farmName'] ?? f['farm'] ?? 'farm';
      const soil = f['soilType'];
      const size = f['farmSize'];
      const loc = f['farmLocation'] as Record<string, unknown> | undefined;
      const district = typeof loc?.district === 'string' && loc.district ? loc.district : undefined;
      const parts = [String(name)];
      if (district) parts.push(`located:${district}`);
      if (soil) parts.push(`soil:${soil}`);
      if (size) parts.push(`${size} ${f['farmSizeUnit'] ?? ''}`.trim());
      return parts.join(' ');
    }).join(' | ');
    if (summary) lines.push('User farms: ' + summary);
  }

  return lines.join('\n');
}

/**
 * Resolves the best location for the farmer from most specific to least
 * specific, so answers use real, relevant context instead of guesses:
 *   farm district/state -> profile district/state -> profile address -> none.
 */
function resolveLocation(context: Record<string, unknown> | undefined): string | null {
  const profile = context?.userProfile as Record<string, unknown> | undefined;
  const farms = Array.isArray(context?.farms) ? (context.farms as Array<Record<string, unknown>>) : [];

  const district = (v: unknown) =>
    typeof v === 'string' && v.trim().length > 0 ? v.trim() : null;
  const state = (v: unknown) =>
    typeof v === 'string' && v.trim().length > 0 ? v.trim() : null;

  const joinCityDistrictState = (loc: Record<string, unknown> | undefined): string | null => {
    if (!loc) return null;
    const city = district(loc['city']);
    const d = district(loc['district']);
    const s = state(loc['state']);
    const cityDistrict = city && d ? `${city}, ${d}` : (city ?? d);
    if (cityDistrict && s) return `${cityDistrict}, ${s}`;
    if (d && s) return `${d}, ${s}`;
    if (cityDistrict) return cityDistrict;
    if (s) return s;
    return null;
  };

  // 1) A specific farm's location (most accurate).
  for (const f of farms) {
    const viaFarmLocation = joinCityDistrictState(
      f['farmLocation'] as Record<string, unknown> | undefined,
    );
    if (viaFarmLocation) return viaFarmLocation;
    // Flat keys, in case the client sends them at farm level.
    const d = district(f['district']);
    const s = state(f['state']);
    if (d && s) return `${d}, ${s}`;
    if (d) return d;
    if (s) return s;
  }
  // 2) The farmer profile's address.
  const viaAddress = joinCityDistrictState(
    profile?.['address'] as Record<string, unknown> | undefined,
  );
  if (viaAddress) return viaAddress;
  // 3) Flat profile keys.
  const pd = district(profile?.['district']);
  const ps = state(profile?.['state']);
  if (pd && ps) return `${pd}, ${ps}`;
  if (pd) return pd;
  if (ps) return ps;
  return null;
}

/** OpenAI-compatible chat call with optional function/tool schemas. */
export async function groqChat(
  messages: GroqChatMessage[],
  opts: { language?: string; context?: Record<string, unknown>; tools?: ToolSpec[] } = {},
): Promise<GroqChatResult> {
  const provider = resolveLlm();
  const system = buildSystemPrompt(opts.language, opts.context);
  const body: Record<string, unknown> = {
    model: provider.model,
    messages: [{ role: 'system', content: system }, ...messages],
    temperature: 0.4,
    max_completion_tokens: 2048,
  };
  if (opts.tools && opts.tools.length > 0) {
    body.tools = opts.tools;
    body.tool_choice = 'auto';
  }

  const data = await llmPost<{
    choices: Array<{ message: GroqChatMessage }>;
    usage?: Record<string, number>;
  }>('/chat/completions', body, provider);

  const message = data.choices[0]?.message;
  return {
    content: message?.content ?? '',
    toolCalls: message?.tool_calls ?? null,
    model: provider.model,
    usage: data.usage,
  };
}

/** OpenAI-compatible JSON Schema (Structured Output) for server-side validation. */
export interface JsonSchema {
  name: string;
  strict?: boolean;
  schema: Record<string, unknown>;
}

export interface GroqJsonResult<T = Record<string, unknown>> {
  data: T;
  model: string;
  usage?: Record<string, number>;
}

/**
 * Strict structured chat call.
 *
 * Uses Groq's JSON Schema response_format (Structured Outputs) when the model
 * accepts it, falling back to JSON mode (`json_object`) for models that only
 * support that. The returned payload is ALWAYS parsed and shape-checked on the
 * server — uncontrolled free-form model text is never passed through to the
 * client.
 */
export async function groqJson<T extends Record<string, unknown>>(
  messages: GroqChatMessage[],
  opts: {
    schema?: JsonSchema;
    temperature?: number;
    maxTokens?: number;
    context?: Record<string, unknown>;
    language?: string;
  } = {},
): Promise<GroqJsonResult<T>> {
  const provider = resolveLlm();
  const system = opts.context ? buildSystemPrompt(opts.language, opts.context) : opts.language ? `Respond in ${opts.language}.` : undefined;
  const body: Record<string, unknown> = {
    model: provider.model,
    messages: system
      ? [{ role: 'system', content: system }, ...messages]
      : messages,
    temperature: opts.temperature ?? 0.3,
    max_tokens: opts.maxTokens ?? 4096,
  };
  if (provider.supportsReasoning && REASONING_EFFORT && REASONING_EFFORT !== 'off') {
    body.reasoning_effort = REASONING_EFFORT;
  }

  // 1) Prefer real Structured Outputs (JSON Schema) on providers that support
  //    it reliably (e.g. Groq). NVIDIA's OpenAI-compatible gateway currently
  //    serves json_schema responses slowly and inconsistently, so NVIDIA goes
  //    straight to JSON mode (verified fast + clean).
  const skipSchema = provider.name === 'nvidia';
  if (opts.schema && !skipSchema) {
    body.response_format = {
      type: 'json_schema',
      json_schema: {
        name: opts.schema.name,
        strict: opts.schema.strict ?? true,
        schema: opts.schema.schema,
      },
    };
    try {
      const data = await llmPost<{ choices: Array<{ message: GroqChatMessage }>; usage?: Record<string, number> }>(
        '/chat/completions',
        body,
        provider,
      );
      const content = data.choices[0]?.message?.content ?? '';
      if (content) {
        try {
          return {
            data: parseJsonContent<T>(content, provider.name),
            model: provider.model,
            usage: data.usage,
          };
        } catch {
          // Strict response was malformed/trimmed -> retry in JSON mode below.
        }
      }
    } catch (e) {
      if (!isSchemaUnsupported(e)) throw e;
      // Model does not support json_schema -> retry with JSON mode below.
    }
  }

  // 2) Fallback: JSON mode + server-side shape validation.
  body.response_format = { type: 'json_object' };
  const data = await llmPost<{ choices: Array<{ message: GroqChatMessage }>; usage?: Record<string, number> }>(
    '/chat/completions',
    body,
    provider,
  );
  const content = data.choices[0]?.message?.content ?? '';
  if (!content) {
    throw new Error(`${provider.name} returned an empty response.`);
  }
  return {
    data: parseJsonContent<T>(content, provider.name),
    model: provider.model,
    usage: data.usage,
  };
}

function isSchemaUnsupported(e: unknown): boolean {
  if (!(e instanceof Error)) return false;
  const raw: unknown = (e as Error & { raw?: unknown }).raw;
  const text = typeof raw === 'string' ? raw : JSON.stringify(raw ?? e.message);
  return /json_schema|not supported|unsupported|invalid.*response_format|400/i.test(text);
}

/**
 * Parses model JSON content defensively: models occasionally wrap the object
 * in a code fence or emit a short preface / trailing commas. Extraction keeps
 * the outer JSON object and tolerates trailing commas so an otherwise-valid
 * Structured-Output response is never dropped.
 */
export function parseJsonContent<T extends Record<string, unknown>>(
  content: string,
  providerName: string,
): T {
  let cleaned = content.trim().replace(/^```(?:json)?/i, '').replace(/```\s*$/, '').trim();
  // Tolerate trailing commas inside objects/arrays (common with long output).
  const noTrailingCommas = cleaned.replace(/,\s*([}\]])/g, '$1');
  try {
    return JSON.parse(noTrailingCommas) as T;
  } catch {
    // Fall back to the outermost {...} span (drops any preface/trailing text).
    const start = noTrailingCommas.indexOf('{');
    const end = noTrailingCommas.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return JSON.parse(noTrailingCommas.slice(start, end + 1)) as T;
    }
    throw new Error(
      `${providerName} returned malformed JSON: ${content.slice(0, 120).replace(/\n/g, ' ')}`,
    );
  }
}

export interface SttResult {
  text: string;
  language?: string;
  duration?: number;
}

/**
 * Whisper Large V3 Turbo transcription.
 * Expects raw WAV/PCM bytes. `language` is an optional ISO-639-1 hint from the app.
 */
export async function groqStt(
  audio: Buffer,
  opts: { language?: string; filename?: string; mime?: string },
): Promise<SttResult> {
  const form = new FormData();
  form.append('model', WHISPER_MODEL);
  if (opts.language) form.append('language', opts.language);
  const wavBuffer = new ArrayBuffer(audio.byteLength);
  new Uint8Array(wavBuffer).set(audio);
  form.append(
    'file',
    new Blob([wavBuffer], { type: opts.mime ?? 'audio/wav' }),
    opts.filename ?? 'recording.wav',
  );

  const apiKey = process.env.GROQ_API_KEY;
  if (!apiKey) {
    throw new Error('GROQ_API_KEY is not configured on the server (Whisper STT).');
  }
  const res = await axios.post(
    `${GROQ_BASE}/audio/transcriptions`,
    form as unknown as string,
    { headers: { Authorization: `Bearer ${apiKey}` }, timeout: 120_000, maxBodyLength: 120 * 1024 * 1024 },
  );
  const data = res.data as { text: string; language?: string; duration?: number };
  return { text: data.text ?? '', language: data.language, duration: data.duration };
}