import axios from 'axios';

/**
 * Deepgram Realtime speech-to-text relay.
 *
 * Deepgram supports Token-Based Authentication: the server mints a short-lived
 * JWT access token via `POST /v1/auth/grant` (30-3600 s TTL) that grants
 * `usage:write` for the realtime `/v1/listen` WebSocket. The mobile client
 * connects directly to Deepgram with `Authorization: Bearer <jwt>`, so the
 * permanent DEEPGRAM_API_KEY never leaves this server and is never embedded
 * in the app. The token only needs to be valid while the WebSocket connects;
 * the socket stays open as long as audio is streamed.
 */

const DEEPGRAM_BASE = process.env.DEEPGRAM_BASE_URL ?? 'https://api.deepgram.com';

export const DEEPGRAM_REALTIME_MODEL = 'nova-3';
export const DEEPGRAM_SAMPLE_RATE = 16000;

/** VidhAI language codes (ISO-639-1 style) for the AI Live language selector. */
export const REALTIME_LANGUAGES = [
  'en',
  'ta',
  'te',
  'kn',
  'ml',
  'hi',
  'bn',
  'mr',
  'gu',
  'pa',
  'or',
  'as',
  'ur',
] as const;

const LANGUAGE_WHITELIST = new Set<string>(REALTIME_LANGUAGES);

/**
 * Languages recognised by the Deepgram Nova-3 realtime `/v1/listen` endpoint
 * (BCP-47 tags). Malayalam (`ml`) and Odia/Oriya (`or`) are NOT offered by any
 * Deepgram streaming model, so they are rejected with a clear error instead of
 * silently producing unusable transcripts.
 */
const NOVA3_LANGUAGES: ReadonlyMap<string, string> = new Map<string, string>([
  ['en', 'en'],
  ['ta', 'ta'],
  ['te', 'te'],
  ['kn', 'kn'],
  ['hi', 'hi'],
  ['bn', 'bn'],
  ['mr', 'mr'],
  ['gu', 'gu'],
  ['pa', 'pa'],
  ['ur', 'ur'],
  ['as', 'as'],
]);

const UNSUPPORTED_REALTIME_LANGUAGES: ReadonlySet<string> = new Set<string>(['ml', 'or']);

export interface DeepgramRealtimeConfig {
  model: string;
  /** BCP-47 language tag passed to Deepgram. */
  language: string;
  wsUrl: string;
  sampleRate: number;
  encoding: string;
}

export interface DeepgramRealtimeSessionResult extends DeepgramRealtimeConfig {
  accessToken: string;
  expiresIn: number;
}

export function isSupportedDeepgramLanguage(code: string): boolean {
  return NOVA3_LANGUAGES.has(code);
}

/**
 * Returns how to transcribe the given VidhAI language code with Deepgram, or
 * null when the language is not supported by any Deepgram streaming model.
 */
export function deepgramConfigForLanguage(
  languageCode: string,
): DeepgramRealtimeConfig | null {
  const language = NOVA3_LANGUAGES.get(languageCode) ?? NOVA3_LANGUAGES.get('en');
  if (!language) return null;
  const model = DEEPGRAM_REALTIME_MODEL;
  const params = new URLSearchParams({
    model,
    language,
    encoding: 'linear16',
    sample_rate: String(DEEPGRAM_SAMPLE_RATE),
    channels: '1',
    interim_results: 'true',
    smart_format: 'true',
    punctuate: 'true',
    vad_events: 'true',
    utterance_end_ms: '1000',
    endpointing: '300',
  });
  return {
    model,
    language,
    sampleRate: DEEPGRAM_SAMPLE_RATE,
    encoding: 'linear16',
    wsUrl: `${DEEPGRAM_BASE}/v1/listen?${params.toString()}`,
  };
}

/**
 * Mints a short-lived Deepgram access token (JWT) that is safe to hand to the
 * mobile client. Throws when the server DEEPGRAM_API_KEY is missing or the
 * grant fails.
 */
export async function createDeepgramRealtimeSession(opts: {
  languageCode?: string;
} = {}): Promise<DeepgramRealtimeSessionResult> {
  const apiKey = process.env.DEEPGRAM_API_KEY;
  if (!apiKey) {
    throw new Error('DEEPGRAM_API_KEY is not configured on the server.');
  }

  const languageCode = opts.languageCode ?? 'en';
  const config = deepgramConfigForLanguage(languageCode);
  if (!config) {
    throw new Error(
      `Deepgram realtime transcription is not supported for language '${languageCode}'.`,
    );
  }

  // The token only needs to cover the WebSocket handshake; 180 s comfortably
  // covers the mobile client's connect + a few reconnect attempts.
  const ttlSeconds = 180;
  const grant = await axios.post(
    `${DEEPGRAM_BASE}/v1/auth/grant`,
    { ttl_seconds: ttlSeconds },
    {
      headers: {
        Authorization: `Token ${apiKey}`,
        'Content-Type': 'application/json',
      },
      timeout: 30_000,
    },
  );
  const data = grant.data ?? {};
  const accessToken = data.access_token;
  if (typeof accessToken !== 'string' || accessToken.length === 0) {
    throw new Error('Deepgram did not return an access token for the session.');
  }
  const expiresIn =
    typeof data.expires_in === 'number'
      ? data.expires_in
      : typeof data.expires_in === 'string'
        ? Number(data.expires_in)
        : ttlSeconds;

  return { ...config, accessToken, expiresIn };
}

export { UNSUPPORTED_REALTIME_LANGUAGES, LANGUAGE_WHITELIST };