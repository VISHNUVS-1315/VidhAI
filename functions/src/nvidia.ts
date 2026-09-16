import axios from 'axios';
import { Readable } from 'stream';

export const NVIDIA_BASE =
  process.env.NVIDIA_BASE_URL ?? 'https://integrate.api.nvidia.com/v1';

export interface NvidiaProvider {
  name: 'nvidia';
  base: string;
  key: string;
  model: string;
}

export interface ToolSpec {
  type: 'function';
  function: {
    name: string;
    description: string;
    parameters: Record<string, unknown>;
  };
}

export interface NvidiaChatMessage {
  role: 'system' | 'user' | 'assistant' | 'tool';
  content: string;
  tool_call_id?: string;
  tool_calls?: Array<{
    id: string;
    type: 'function';
    function: { name: string; arguments: string };
  }>;
}

export interface NvidiaChatResult {
  content: string;
  toolCalls: NvidiaChatMessage['tool_calls'] | null;
  model: string;
  usage?: Record<string, number>;
}

export interface JsonSchema {
  name: string;
  strict?: boolean;
  schema: Record<string, unknown>;
}

export interface NvidiaJsonResult<T = Record<string, unknown>> {
  data: T;
  model: string;
  usage?: Record<string, number>;
}

export function nvidiaProvider(model: string): NvidiaProvider {
  const key = (process.env.NVIDIA_API_KEY ?? '').trim();
  if (!key) {
    throw new Error('NVIDIA_API_KEY is not configured on the server.');
  }
  return {
    name: 'nvidia',
    base: NVIDIA_BASE,
    key,
    model,
  };
}

const LLM_TIMEOUT_MS = 240_000;

export async function llmPost<T>(
  path: string,
  body: Record<string, unknown>,
  provider: NvidiaProvider,
  opts: {
    timeout?: number;
    maxBodyLength?: number;
    maxContentLength?: number;
  } = {},
): Promise<T> {
  const res = await axios.post<T>(
    `${provider.base}${path}`,
    body,
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
    const err = new Error(
      `NVIDIA (${provider.model}) returned HTTP ${res.status}`,
    ) as Error & { raw?: unknown };
    err.raw = res.data;
    throw err;
  }
  return res.data;
}

export interface NvidiaStreamResult {
  content: string;
  toolCalls: NvidiaChatMessage['tool_calls'] | null;
  finishReason: string | null;
}

/**
 * Streaming (SSE) OpenAI-compatible call against NVIDIA NIM.
 *
 * Frames are `data: {chunk}` with content and/or tool_call deltas, terminated
 * by `data: [DONE]`. Only text deltas are forwarded through [onDelta]; tool
 * calls are accumulated per index and returned in the final result so the
 * non-streaming routing contract stays identical.
 */
export async function llmPostStream(
  path: string,
  body: Record<string, unknown>,
  provider: NvidiaProvider,
  onDelta: (content: string) => void,
  opts: { timeout?: number } = {},
): Promise<NvidiaStreamResult> {
  const response = await axios.post<Readable>(
    `${provider.base}${path}`,
    body,
    {
      headers: {
        Authorization: `Bearer ${provider.key}`,
        'Content-Type': 'application/json',
        Accept: 'text/event-stream',
      },
      responseType: 'stream',
      timeout: opts.timeout ?? LLM_TIMEOUT_MS,
    },
  );

  if (response.status !== 200) {
    response.data.resume();
    const err = new Error(
      `NVIDIA (${provider.model}) returned HTTP ${response.status}`,
    ) as Error & { raw?: unknown };
    throw err;
  }

  const contentParts: string[] = [];
  const toolCallParts: Array<{ id: string; name: string; arguments: string }> =
    [];
  let finishReason: string | null = null;

  await new Promise<void>((resolve, reject) => {
    let buffer = '';
    response.data.on('data', (raw: Buffer | string) => {
      buffer += raw.toString('utf8');
      let newline: number;
      while ((newline = buffer.indexOf('\n')) >= 0) {
        const line = buffer.slice(0, newline).trim();
        buffer = buffer.slice(newline + 1);
        if (!line.startsWith('data:')) continue;
        const data = line.slice('data:'.length).trim();
        if (!data || data === '[DONE]') continue;

        let chunk: Record<string, unknown>;
        try {
          chunk = JSON.parse(data);
        } catch {
          continue;
        }

        const choice = (
          Array.isArray(chunk.choices) ? chunk.choices[0] : undefined
        ) as
          | {
              delta?: Record<string, unknown>;
              finish_reason?: unknown;
            }
          | undefined;
        const delta = choice?.delta;

        if (typeof delta?.content === 'string' && delta.content) {
          contentParts.push(delta.content);
          onDelta(delta.content);
        }

        if (Array.isArray(delta?.tool_calls)) {
          for (const call of delta.tool_calls as Array<{
            index?: number;
            id?: string;
            function?: { name?: string; arguments?: string };
          }>) {
            const idx =
              typeof call.index === 'number'
                ? call.index
                : toolCallParts.length - 1;
            if (idx >= 0 && idx < toolCallParts.length) {
              if (call.id) toolCallParts[idx].id = call.id;
              if (call.function?.name) {
                toolCallParts[idx].name = call.function.name;
              }
              if (call.function?.arguments) {
                toolCallParts[idx].arguments += call.function.arguments;
              }
            } else if (idx === toolCallParts.length || idx === -1) {
              toolCallParts.push({
                id: call.id ?? '',
                name: call.function?.name ?? '',
                arguments: call.function?.arguments ?? '',
              });
            }
          }
        }

        if (choice?.finish_reason != null) {
          finishReason = String(choice.finish_reason);
        }
      }
    });
    response.data.on('end', () => resolve());
    response.data.on('error', (err) => reject(err));
  });

  const toolCalls = toolCallParts
    .filter((t) => t.name)
    .map((t) => ({
      id: t.id,
      type: 'function' as const,
      function: { name: t.name, arguments: t.arguments },
    }));

  return {
    content: contentParts.join(''),
    toolCalls: toolCalls.length ? toolCalls : null,
    finishReason,
  };
}

export function buildSystemPrompt(
  language: string | undefined,
  context: Record<string, unknown> | undefined,
): string {
  const langName = language ?? 'en';
  const lines: string[] = [
    'You are VidhAI, a helpful agricultural assistant for Indian farmers.',
    'You are embedded in the VidhAI app.',
    '- Be short when the question is simple; be detailed when it matters.',
    '- Return only the final user-facing answer. Never expose analysis, chain-of-thought, scratchpad, or hidden reasoning.',
    '- Use plain, farmer-friendly language.',
    `- Respond in the requested language: ${langName}`,
    '- Use provided tools when the farmer asks for real app data or actions.',
    '- Never invent live market prices, weather, schemes, or farm data.',
    '- If a live-data tool returns nothing, say that clearly.',
  ];

  const profile = context?.userProfile as Record<string, unknown> | undefined;
  const farms = Array.isArray(context?.farms)
    ? (context!.farms as Array<Record<string, unknown>>)
    : [];

  if (profile) {
    const fields: string[] = [];
    const name = profile['displayName'] ?? profile['fullName'];
    if (name) fields.push(`farmer: ${name}`);
    if (profile['role']) fields.push(`console: ${profile['role']}`);
    if (fields.length) lines.push('Farmer context: ' + fields.join(', '));
  }

  if (farms.length) {
    const summary = farms
      .slice(0, 5)
      .map((farm) => {
        const name = String(farm['farmName'] ?? farm['farm'] ?? 'farm');
        const loc = farm['farmLocation'] as Record<string, unknown> | undefined;
        const parts = [name];
        if (loc?.district) parts.push(`district:${loc.district}`);
        if (loc?.state) parts.push(`state:${loc.state}`);
        if (farm['soilType']) parts.push(`soil:${farm['soilType']}`);
        if (farm['farmSize']) {
          parts.push(`${farm['farmSize']} ${farm['farmSizeUnit'] ?? ''}`.trim());
        }
        return parts.join(' ');
      })
      .join(' | ');
    if (summary) lines.push('User farms: ' + summary);
  }

  const source = context?.source;
  if (typeof source === 'string' && source) {
    lines.push(`Current VidhAI context: ${source}`);
  }

  return lines.join('\n');
}

function parseToolCalls(
  raw: unknown,
): NvidiaChatMessage['tool_calls'] | null {
  if (!Array.isArray(raw) || raw.length === 0) return null;
  return raw as NvidiaChatMessage['tool_calls'];
}

export async function nvidiaChat(
  messages: NvidiaChatMessage[],
  opts: {
    language?: string;
    context?: Record<string, unknown>;
    tools?: ToolSpec[];
    model?: string;
    temperature?: number;
    maxTokens?: number;
  } = {},
): Promise<NvidiaChatResult> {
  const model =
    opts.model ??
    process.env.AI_MODEL_GENERAL ??
    'nvidia/nemotron-3.5-lightning-30b-a3b';
  const provider = nvidiaProvider(model);
  const system = buildSystemPrompt(opts.language, opts.context);
  const body: Record<string, unknown> = {
    model,
    messages: [
      { role: 'system', content: system },
      ...messages.filter((m) => m.role !== 'system'),
    ],
    temperature: opts.temperature ?? 0.4,
    max_tokens: opts.maxTokens ?? 4096,
    chat_template_kwargs: { enable_thinking: false },
  };
  if (opts.tools?.length) body.tools = opts.tools;

  const data = await llmPost<{
    choices: Array<{
      message?: NvidiaChatMessage;
    }>;
    usage?: Record<string, number>;
  }>('/chat/completions', body, provider);

  const message = data.choices?.[0]?.message;
  return {
    content: message?.content ?? '',
    toolCalls: parseToolCalls(message?.tool_calls),
    model,
    usage: data.usage,
  };
}

export function parseJsonContent<T extends Record<string, unknown>>(
  content: string,
): T {
  let cleaned = content
    .trim()
    .replace(/^\`\`\`(?:json)?/i, '')
    .replace(/\`\`\`\s*$/, '')
    .trim()
    .replace(/,\s*([}\]])/g, '$1');

  try {
    return JSON.parse(cleaned) as T;
  } catch {
    const start = cleaned.indexOf('{');
    const end = cleaned.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return JSON.parse(cleaned.slice(start, end + 1)) as T;
    }
    throw new Error(
      `NVIDIA returned malformed JSON: ${content.slice(0, 120).replace(/\n/g, ' ')}`,
    );
  }
}

export async function nvidiaJson<T extends Record<string, unknown>>(
  messages: NvidiaChatMessage[],
  opts: {
    schema?: JsonSchema;
    language?: string;
    context?: Record<string, unknown>;
    model?: string;
    temperature?: number;
    maxTokens?: number;
  } = {},
): Promise<NvidiaJsonResult<T>> {
  const model =
    opts.model ??
    process.env.AI_MODEL_GENERAL ??
    'nvidia/nemotron-3.5-lightning-30b-a3b';
  const provider = nvidiaProvider(model);
  const system = buildSystemPrompt(opts.language, opts.context);

  const body: Record<string, unknown> = {
    model,
    messages: [
      { role: 'system', content: system },
      ...messages.filter((m) => m.role !== 'system'),
    ],
    temperature: opts.temperature ?? 0.3,
    max_tokens: opts.maxTokens ?? 8192,
    chat_template_kwargs: { enable_thinking: false },
    response_format: { type: 'json_object' },
  };

  const data = await llmPost<{
    choices: Array<{ message?: NvidiaChatMessage }>;
    usage?: Record<string, number>;
  }>('/chat/completions', body, provider);

  const content = data.choices?.[0]?.message?.content ?? '';
  if (!content.trim()) {
    throw new Error('NVIDIA returned an empty JSON response.');
  }

  const parsed = parseJsonContent<T>(content);

  // JSON schema is retained as a contract/documentation input for callers.
  // NVIDIA JSON mode is parsed and validated again by the domain service.
  void opts.schema;

  return {
    data: parsed,
    model,
    usage: data.usage,
  };
}
