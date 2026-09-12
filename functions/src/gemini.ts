import axios from 'axios';

import { GroqChatMessage, ToolSpec } from './groq';

/**
 * Gemini relays: vision (crop images) + chat central brain.
 * Keys live server-side only (GEMINI_API_KEY).
 */

const GEMINI_MODEL = process.env.GEMINI_MODEL ?? 'gemini-2.0-flash';
const GEMINI_BASE =
  process.env.GEMINI_BASE_URL ?? 'https://generativelanguage.googleapis.com/v1beta';

export interface VisionImage {
  base64: string;
  mimeType: string;
}

export interface VisionResult {
  content: string;
  model: string;
}

const VISION_TIMEOUT_MS = 120_000;

export async function geminiVision(
  prompt: string,
  images: VisionImage[],
  opts: { language?: string } = {},
): Promise<VisionResult> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    throw new Error('GEMINI_API_KEY is not configured on the server.');
  }

  const langLine = opts.language ? ` Respond in the language: ${opts.language}.` : '';
  const system =
    'You are VidhAI, an agricultural image analyst. Give practical, farmer-friendly guidance. ' +
    'This is an AI-based assessment, not a confirmed diagnosis. If the image is unclear or ' +
    'insufficient, say so and recommend capturing a better photo or consulting a local expert. ' +
    'Never invent a diagnosis with false certainty.' +
    langLine;

  const parts: Array<Record<string, unknown>> = [{ text: `${system}\n\nUser request: ${prompt}` }];
  for (const img of images) {
    parts.push({
      inline_data: {
        mime_type: img.mimeType,
        data: img.base64,
      },
    });
  }

  const res = await axios.post(
    `${GEMINI_BASE}/models/${GEMINI_MODEL}:generateContent?key=${apiKey}`,
    {
      contents: [{ parts }],
      generationConfig: { temperature: 0.4, maxOutputTokens: 2048 },
    },
    { timeout: VISION_TIMEOUT_MS },
  );

  const text = res.data?.candidates?.[0]?.content?.parts
    ?.map((p: { text?: string }) => p.text ?? '')
    .filter(Boolean)
    .join('\n');

  if (!text) {
    throw new Error('Gemini returned no content.');
  }
  return { content: text, model: GEMINI_MODEL };
}

export interface GeminiChatResult {
  content: string;
  toolCalls: Array<{
    id: string;
    type: 'function';
    function: { name: string; arguments: string };
  }> | null;
  model: string;
  usage?: Record<string, number>;
}

const CHAT_TIMEOUT_MS = 240_000;

function geminiSystemPrompt(language: string | undefined): string {
  const langName = language ?? 'en';
  return [
    'You are VidhAI, a helpful agricultural assistant for Indian farmers. You are embedded in the VidhAI app.',
    '- Be short when the question is simple; be detailed when it matters.',
    '- Use plain, farmer-friendly language. Avoid unnecessary technical jargon.',
    '- Respond in the language requested: ' + langName,
    '- When the user asks you to perform an action (open a screen, fetch prices, show weather, create a task, fill a form field), USE the provided tool/function rather than only explaining it.',
    '- Never invent live market prices, weather, or farm data. If a tool result is unavailable, say so honestly.',
  ].join('\n');
}

/** Converts Groq/OpenAI-wire history into Gemini contents turns. */
function toGeminiContents(
  messages: GroqChatMessage[],
): Array<Record<string, unknown>> {
  const contents: Array<Record<string, unknown>> = [];
  const callIdToName = new Map<string, string>();

  for (const m of messages) {
    if (m.role === 'user') {
      contents.push({ role: 'user', parts: [{ text: m.content }] });
      continue;
    }
    if (m.role === 'assistant') {
      if (m.tool_calls && m.tool_calls.length > 0) {
        const parts: Array<Record<string, unknown>> = [];
        if (m.content.trim()) parts.push({ text: m.content });
        for (const c of m.tool_calls) {
          callIdToName.set(c.id, c.function.name);
          let args: unknown = {};
          try {
            args = JSON.parse(c.function.arguments || '{}');
          } catch (_) {
            args = c.function.arguments ?? {};
          }
          parts.push({ functionCall: { name: c.function.name, args } });
        }
        contents.push({ role: 'model', parts });
      } else if (m.content.trim()) {
        contents.push({ role: 'model', parts: [{ text: m.content }] });
      }
      continue;
    }
    if (m.role === 'tool') {
      const id = m.tool_call_id ?? '';
      const name = callIdToName.get(id) ?? id;
      let response: unknown = {};
      try {
        response = JSON.parse(m.content || '{}');
      } catch (_) {
        response = { text: m.content };
      }
      contents.push({
        role: 'function',
        parts: [{ functionResponse: { name, response } }],
      });
    }
  }
  return contents;
}

function toFunctionDeclarations(tools: ToolSpec[]): Array<Record<string, unknown>> {
  return tools
    .map((t) => ({
      name: t.function.name,
      description: t.function.description,
      ...(t.function.parameters ? { parameters: t.function.parameters } : {}),
    }))
    .filter((f) => Boolean(f.name));
}

/** Gemini central brain: chat + function calling via the current text model. */
export async function geminiChat(
  messages: GroqChatMessage[],
  opts: { language?: string; tools?: ToolSpec[] } = {},
): Promise<GeminiChatResult> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    throw new Error('GEMINI_API_KEY is not configured on the server.');
  }

  const body: Record<string, unknown> = {
    contents: toGeminiContents(messages),
    systemInstruction: { parts: [{ text: geminiSystemPrompt(opts.language) }] },
    generationConfig: { temperature: 0.4, maxOutputTokens: 2048 },
  };
  if (opts.tools && opts.tools.length > 0) {
    body.tools = [{ functionDeclarations: toFunctionDeclarations(opts.tools) }];
  }

  const res = await axios.post(
    `${GEMINI_BASE}/models/${GEMINI_MODEL}:generateContent?key=${apiKey}`,
    body,
    { timeout: CHAT_TIMEOUT_MS },
  );

  const cand = res.data?.candidates?.[0];
  if (!cand) {
    throw new Error('Gemini returned no candidates.');
  }
  const parts: Array<Record<string, unknown>> = cand?.content?.parts ?? [];
  const content = parts
    .map((p) => (typeof p.text === 'string' ? p.text : ''))
    .join('\n')
    .trim();

  const toolCalls: GeminiChatResult['toolCalls'] = [];
  for (const p of parts) {
    const fc = p.functionCall as Record<string, unknown> | undefined;
    if (fc && typeof fc.name === 'string') {
      toolCalls!.push({
        id: fc.name,
        type: 'function',
        function: {
          name: fc.name,
          arguments:
            typeof fc.args === 'string' ? fc.args : JSON.stringify(fc.args ?? {}),
        },
      });
    }
  }

  return {
    content,
    toolCalls: toolCalls.length > 0 ? toolCalls : null,
    model: GEMINI_MODEL,
  };
}