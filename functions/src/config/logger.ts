/**
 * Provider-neutral structured logger.
 *
 * Mirrors the `functions.logger` surface used across the gateway
 * (info/warn/error with a scope + payload) so business modules do not depend
 * on firebase-functions. Never logs secret values.
 */

export interface LogPayload {
  error?: unknown;
  [key: string]: unknown;
}

function clean(payload: unknown): unknown {
  if (payload instanceof Error) return { error: payload.message };
  if (payload && typeof payload === 'object') {
    const out: Record<string, unknown> = { ...(payload as Record<string, unknown>) };
    if (out.error instanceof Error) out.error = out.error.message;
    return out;
  }
  return payload;
}

function write(level: 'INFO' | 'WARN' | 'ERROR', scope: string, payload?: unknown): void {
  const ts = new Date().toISOString();
  const parts = [ts, level, scope];
  if (payload !== undefined) {
    const cleanValue = clean(payload);
    parts.push(typeof cleanValue === 'string' ? cleanValue : JSON.stringify(cleanValue));
  }
  const line = parts.join(' ');
  if (level === 'ERROR') console.error(line);
  else if (level === 'WARN') console.warn(line);
  else console.info(line);
}

export const logger = {
  info: (scope: string, payload?: unknown): void => write('INFO', scope, payload),
  warn: (scope: string, payload?: unknown): void => write('WARN', scope, payload),
  error: (scope: string, payload?: unknown): void => write('ERROR', scope, payload),
};

export default logger;