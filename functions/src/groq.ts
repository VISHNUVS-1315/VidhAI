import axios from 'axios';

/**
 * Groq relay: GPT-OSS-120B chat (with tool calling) + Whisper Large V3 Turbo STT.
 * API keys live only server-side; the Flutter client never sees them.
 */

const GROQ_BASE = process.env.GROQ_BASE_URL ?? 'https://api.groq.com/openai/v1';
const GROQ_MODEL = process.env.GROQ_MODEL ?? 'openai/gpt-oss-120b';
const WHISPER_MODEL = process.env.WHISPER_MODEL ?? 'whisper-large-v3-turbo';

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

const GROQ_TIMEOUT_MS = 240_000;

async function groqPost<T>(path: string, body: Record<string, unknown>, isForm = false): Promise<T> {
  const apiKey = process.env.GROQ_API_KEY;
  if (!apiKey) {
    throw new Error('GROQ_API_KEY is not configured on the server.');
  }
  const res = await axios.post<T>(`${GROQ_BASE}${path}`, body as unknown as string, {
    headers:
      isForm
        ? { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'multipart/form-data' }
        : { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
    timeout: GROQ_TIMEOUT_MS,
    maxBodyLength: 150 * 1024 * 1024,
    maxContentLength: 150 * 1024 * 1024,
  });
  if (res.status !== 200) {
    const err: unknown = new Error(`Groq returned HTTP ${res.status}`);
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
  const system = buildSystemPrompt(opts.language, opts.context);
  const body: Record<string, unknown> = {
    model: GROQ_MODEL,
    messages: [{ role: 'system', content: system }, ...messages],
    temperature: 0.4,
    max_completion_tokens: 2048,
  };
  if (opts.tools && opts.tools.length > 0) {
    body.tools = opts.tools;
    body.tool_choice = 'auto';
  }

  const data = await groqPost<{
    choices: Array<{ message: GroqChatMessage }>;
    usage?: Record<string, number>;
  }>('/chat/completions', body);

  const message = data.choices[0]?.message;
  return {
    content: message?.content ?? '',
    toolCalls: message?.tool_calls ?? null,
    model: GROQ_MODEL,
    usage: data.usage,
  };
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
  if (!apiKey) throw new Error('GROQ_API_KEY is not configured on the server.');
  const res = await axios.post(
    `${GROQ_BASE}/audio/transcriptions`,
    form as unknown as string,
    { headers: { Authorization: `Bearer ${apiKey}` }, timeout: 120_000, maxBodyLength: 120 * 1024 * 1024 },
  );
  const data = res.data as { text: string; language?: string; duration?: number };
  return { text: data.text ?? '', language: data.language, duration: data.duration };
}