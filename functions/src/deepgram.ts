import axios from 'axios';

/**
 * Deepgram Nova-3 speech-to-text relay.
 * Key lives server-side only (DEEPGRAM_API_KEY via Secret Manager).
 */

const DEEPGRAM_BASE =
  process.env.DEEPGRAM_BASE_URL ?? 'https://api.deepgram.com/v1';
const DEEPGRAM_MODEL = process.env.DEEPGRAM_MODEL ?? 'nova-3';

export interface DeepgramSttResult {
  text: string;
  confidence?: number;
  duration?: number;
}

const DEEPGRAM_TIMEOUT_MS = 120_000;

export async function deepgramStt(
  audio: Buffer,
  opts: { language?: string; mime?: string } = {},
): Promise<DeepgramSttResult> {
  const apiKey = process.env.DEEPGRAM_API_KEY;
  if (!apiKey) {
    throw new Error('DEEPGRAM_API_KEY is not configured on the server.');
  }

  const params: Record<string, string> = {
    model: DEEPGRAM_MODEL,
    smart_format: 'true',
  };
  if (opts.language) params.language = opts.language;

  const res = await axios.post(`${DEEPGRAM_BASE}/listen`, audio, {
    headers: {
      Authorization: `Token ${apiKey}`,
      'Content-Type': opts.mime ?? 'audio/wav',
    },
    params,
    timeout: DEEPGRAM_TIMEOUT_MS,
    maxBodyLength: 150 * 1024 * 1024,
  });

  const alt = res.data?.results?.channels?.[0]?.alternatives?.[0];
  const text = alt?.transcript ?? '';
  if (!text) {
    throw new Error('Deepgram returned no transcript.');
  }
  return {
    text,
    confidence: typeof alt?.confidence === 'number' ? alt.confidence : undefined,
    duration: typeof res.data?.metadata?.duration === 'number' ? res.data.metadata.duration : undefined,
  };
}