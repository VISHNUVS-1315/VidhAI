import { TextToSpeechClient } from '@google-cloud/text-to-speech';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';

/**
 * Google Cloud Text-to-Speech relay.
 * By default runs on the Cloud Function runtime service account (ADC).
 * For local/emulator use set GOOGLE_CLOUD_TTS_SA_JSON to a service-account JSON string.
 */

const GLOBAL_VOICES: Array<{ codes: string[]; defaultName: string; name: string }> = [
  { codes: ['ta', 'ta-IN'], defaultName: 'ta-IN-Standard-C', name: 'ta-IN-Standard-C' },
  { codes: ['hi', 'hi-IN'], defaultName: 'hi-IN-Standard-C', name: 'hi-IN-Standard-C' },
  { codes: ['te', 'te-IN'], defaultName: 'te-IN-Standard-C', name: 'te-IN-Standard-C' },
  { codes: ['kn', 'kn-IN'], defaultName: 'kn-IN-Standard-C', name: 'kn-IN-Standard-C' },
  { codes: ['ml', 'ml-IN'], defaultName: 'ml-IN-Standard-B', name: 'ml-IN-Standard-B' },
  { codes: ['mr', 'mr-IN'], defaultName: 'mr-IN-Standard-C', name: 'mr-IN-Standard-C' },
  { codes: ['bn', 'bn-IN'], defaultName: 'bn-IN-Standard-C', name: 'bn-IN-Standard-C' },
  { codes: ['gu', 'gu-IN'], defaultName: 'gu-IN-Standard-C', name: 'gu-IN-Standard-C' },
  { codes: ['pa', 'pa-IN'], defaultName: 'pa-IN-Standard-C', name: 'pa-IN-Standard-C' },
  { codes: ['or', 'or-IN'], defaultName: 'or-IN-Standard-C', name: 'or-IN-Standard-C' },
  { codes: ['as', 'as-IN'], defaultName: 'as-IN-Standard-C', name: 'as-IN-Standard-C' },
  { codes: ['ur', 'ur-IN'], defaultName: 'ur-IN-Standard-A', name: 'ur-IN-Standard-A' },
  { codes: ['en', 'en', 'en-IN'], defaultName: 'en-IN-Standard-D', name: 'en-IN-Standard-D' },
];

let client: TextToSpeechClient | null = null;

function getClient(): TextToSpeechClient {
  if (client) return client;
  // Support explicit service-account JSON for emulators / non-default runtimes.
  const saJson = process.env.GOOGLE_CLOUD_TTS_SA_JSON;
  if (saJson) {
    const tmp = path.join(os.tmpdir(), 'vidhai-tts-sa.json');
    fs.writeFileSync(tmp, saJson, { mode: 0o600 });
    process.env.GOOGLE_APPLICATION_CREDENTIALS = tmp;
  }
  client = new TextToSpeechClient();
  return client;
}

function pickVoice(language: string | undefined): { languageCode: string; name: string } {
  const lang = (language ?? 'en').toLowerCase().trim();
  const match = GLOBAL_VOICES.find((v) => v.codes.includes(lang));
  if (match) return { languageCode: match.codes[match.codes.length - 1], name: match.name };
  // Unknown language -> default to English (India).
  return { languageCode: 'en-IN', name: 'en-IN-Standard-D' };
}

export interface TtsResult {
  audioBase64: string;
  audioContentType: string;
  voice: string;
  languageCode: string;
}

export async function googleTts(
  text: string,
  opts: { language?: string; speakingRate?: number },
): Promise<TtsResult> {
  const trimmed = (text ?? '').trim();
  if (!trimmed) throw new Error('Empty text for TTS.');

  const { languageCode, name } = pickVoice(opts.language);
  const [response] = await getClient().synthesizeSpeech({
    input: { text: trimmed },
    voice: { languageCode, name },
    audioConfig: {
      audioEncoding: 'MP3',
      speakingRate: opts.speakingRate ?? 1.0,
      pitch: 0,
    },
  });

  const audioContent = response.audioContent;
  if (!audioContent) throw new Error('Google TTS returned no audio.');

  return {
    audioBase64: Buffer.from(audioContent as unknown as ArrayBuffer).toString('base64'),
    audioContentType: 'audio/mpeg',
    voice: name,
    languageCode,
  };
}