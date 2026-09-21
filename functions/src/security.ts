import express from 'express';

interface AuthedRequest extends express.Request {
  firebaseUid?: string;
}

interface Bucket {
  count: number;
  resetAt: number;
}

const minuteMs = 60_000;
const generalBuckets = new Map<string, Bucket>();
const aiBuckets = new Map<string, Bucket>();
let cleanupCounter = 0;

function envInt(name: string, fallback: number, min: number, max: number): number {
  const parsed = Number(process.env[name]);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(max, Math.max(min, Math.floor(parsed)));
}

function take(
  buckets: Map<string, Bucket>,
  key: string,
  limit: number,
  now = Date.now(),
): { allowed: boolean; remaining: number; resetAt: number } {
  const current = buckets.get(key);
  if (!current || current.resetAt <= now) {
    const bucket = { count: 1, resetAt: now + minuteMs };
    buckets.set(key, bucket);
    return { allowed: true, remaining: Math.max(0, limit - 1), resetAt: bucket.resetAt };
  }

  current.count += 1;
  const allowed = current.count <= limit;
  return {
    allowed,
    remaining: Math.max(0, limit - current.count),
    resetAt: current.resetAt,
  };
}

function cleanupExpired(now = Date.now()): void {
  cleanupCounter += 1;
  if (cleanupCounter % 250 !== 0) return;

  for (const [key, bucket] of generalBuckets.entries()) {
    if (bucket.resetAt <= now) generalBuckets.delete(key);
  }
  for (const [key, bucket] of aiBuckets.entries()) {
    if (bucket.resetAt <= now) aiBuckets.delete(key);
  }
}

function limiter(
  buckets: Map<string, Bucket>,
  envName: string,
  fallback: number,
): express.RequestHandler {
  return (req: AuthedRequest, res, next) => {
    const uid = req.firebaseUid;
    if (!uid) {
      res.status(401).json({ success: false, error: 'Authentication required.' });
      return;
    }

    const now = Date.now();
    cleanupExpired(now);
    const limit = envInt(envName, fallback, 1, 1000);
    const result = take(buckets, uid, limit, now);
    const retryAfter = Math.max(1, Math.ceil((result.resetAt - now) / 1000));

    res.setHeader('X-RateLimit-Limit', String(limit));
    res.setHeader('X-RateLimit-Remaining', String(result.remaining));
    res.setHeader('X-RateLimit-Reset', String(Math.ceil(result.resetAt / 1000)));

    if (!result.allowed) {
      res.setHeader('Retry-After', String(retryAfter));
      res.status(429).json({
        success: false,
        error: 'Too many requests. Please try again shortly.',
        retryAfterSeconds: retryAfter,
      });
      return;
    }

    next();
  };
}

export const perUserRateLimit = limiter(
  generalBuckets,
  'RATE_LIMIT_REQUESTS_PER_MINUTE',
  60,
);

export const perUserAiRateLimit = limiter(
  aiBuckets,
  'AI_RATE_LIMIT_REQUESTS_PER_MINUTE',
  20,
);

const forbiddenKeys = new Set(['__proto__', 'prototype', 'constructor']);
const maxDepth = 16;
const maxArrayItems = 200;
const maxNormalStringLength = 100_000;
const maxBase64StringLength = 12_000_000;

class UnsafeInputError extends Error {}

function cleanString(value: string, key?: string): string {
  const max = key === 'base64' ? maxBase64StringLength : maxNormalStringLength;
  if (value.length > max) {
    throw new UnsafeInputError(`${key ?? 'string'} is too large.`);
  }

  // Preserve normal Unicode, tabs and newlines while stripping NUL and
  // non-printing control characters that can cause parser/logging issues.
  return value
    .replace(/\u0000/g, '')
    .replace(/[\u0001-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, '');
}

function sanitizeValue(value: unknown, depth = 0, key?: string): unknown {
  if (depth > maxDepth) throw new UnsafeInputError('Request is too deeply nested.');

  if (typeof value === 'string') return cleanString(value, key);
  if (
    value === null ||
    typeof value === 'number' ||
    typeof value === 'boolean'
  ) {
    return value;
  }

  if (Array.isArray(value)) {
    if (value.length > maxArrayItems) {
      throw new UnsafeInputError('Request contains too many list items.');
    }
    return value.map((item) => sanitizeValue(item, depth + 1));
  }

  if (typeof value === 'object') {
    const source = value as Record<string, unknown>;
    const out: Record<string, unknown> = Object.create(null);

    for (const [rawKey, item] of Object.entries(source)) {
      if (forbiddenKeys.has(rawKey)) {
        throw new UnsafeInputError('Request contains an unsafe field name.');
      }
      const safeKey = cleanString(rawKey);
      out[safeKey] = sanitizeValue(item, depth + 1, safeKey);
    }
    return out;
  }

  throw new UnsafeInputError('Request contains an unsupported value.');
}

export const sanitizeRequestBody: express.RequestHandler = (req, res, next) => {
  try {
    if (req.body !== undefined) {
      req.body = sanitizeValue(req.body);
    }
    next();
  } catch (e) {
    const message = e instanceof UnsafeInputError ? e.message : 'Invalid request body.';
    res.status(400).json({ success: false, error: message });
  }
};

export const securityHeaders: express.RequestHandler = (_req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'no-referrer');
  res.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
  next();
};

export function safeClientError(error: unknown, status: number): string {
  if (status >= 500) return 'Service temporarily unavailable. Please try again.';
  if (error instanceof Error && error.message.trim()) return error.message;
  return 'Request could not be processed.';
}
