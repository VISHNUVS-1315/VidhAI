/**
 * Provider-neutral structured logger.
 *
 * Mirrors the gateway logger surface while aggressively redacting credentials,
 * bearer tokens and secret-like fields. Never log request/response bodies that
 * may contain personal data or provider secrets.
 */

export interface LogPayload {
  error?: unknown;
  [key: string]: unknown;
}

const sensitiveKey =
  /(authorization|cookie|token|secret|password|api[-_]?key|credential|private[-_]?key|service[-_]?account)/i;

function redactString(value: string): string {
  return value
    .replace(/Bearer\s+[A-Za-z0-9._~+/=-]+/gi, 'Bearer [REDACTED]')
    .replace(/\bgsk_[A-Za-z0-9_-]+\b/g, '[REDACTED]')
    .replace(/\bsk-[A-Za-z0-9_-]+\b/g, '[REDACTED]')
    .replace(
      /-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----/g,
      '[REDACTED PRIVATE KEY]',
    );
}

function clean(payload: unknown, depth = 0): unknown {
  if (depth > 6) return '[TRUNCATED]';

  if (payload instanceof Error) {
    return {
      name: payload.name,
      error: redactString(payload.message),
    };
  }

  if (typeof payload === 'string') return redactString(payload);

  if (Array.isArray(payload)) {
    return payload.slice(0, 100).map((item) => clean(item, depth + 1));
  }

  if (payload && typeof payload === 'object') {
    const out: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(
      payload as Record<string, unknown>,
    )) {
      out[key] = sensitiveKey.test(key)
        ? '[REDACTED]'
        : clean(value, depth + 1);
    }
    return out;
  }

  return payload;
}

function write(
  level: 'INFO' | 'WARN' | 'ERROR',
  scope: string,
  payload?: unknown,
): void {
  const ts = new Date().toISOString();
  const parts = [ts, level, scope];
  if (payload !== undefined) {
    const cleanValue = clean(payload);
    parts.push(
      typeof cleanValue === 'string'
        ? cleanValue
        : JSON.stringify(cleanValue),
    );
  }
  const line = parts.join(' ');
  if (level === 'ERROR') console.error(line);
  else if (level === 'WARN') console.warn(line);
  else console.info(line);
}

export const logger = {
  info: (scope: string, payload?: unknown): void =>
    write('INFO', scope, payload),
  warn: (scope: string, payload?: unknown): void =>
    write('WARN', scope, payload),
  error: (scope: string, payload?: unknown): void =>
    write('ERROR', scope, payload),
};

export default logger;
