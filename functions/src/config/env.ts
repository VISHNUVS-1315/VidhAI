/**
 * Provider-neutral runtime configuration.
 *
 * The backend runs identically as:
 *  - a standalone Express/Node server (Render, local `npm start`)
 *  - a Firebase Cloud Function emulator / deployed function (via ./app.ts)
 *  - the Firebase Functions wrapper (src/index.ts)
 *
 * All secrets are read from process.env ONLY (Firebase emulator injects
 * .secret.local; Render / local .env inject env vars). No secret manager SDK
 * is required, so the deployment is not tied to Firebase Blaze.
 */

export const serviceName = 'vidhai-backend';

export const appVersion = process.env.APP_VERSION ?? '1.0.0';

export function nodeEnv(): string {
  return process.env.NODE_ENV ?? 'development';
}

export function serverPort(): number {
  const p = Number(process.env.PORT ?? 8080);
  return Number.isFinite(p) && p > 0 ? p : 8080;
}

/**
 * CORS policy. Defaults to reflecting any origin (needed by native mobile
 * clients that do not send an Origin). To lock down for web, set
 * CORS_ORIGINS to a comma-separated list, e.g. https://app.example.com.
 */
export function corsOrigins(): true | string[] {
  const raw = (process.env.CORS_ORIGINS ?? '').trim();
  if (!raw || raw === '*' || raw.toLowerCase() === 'true') return true;
  return raw
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
}

/**
 * True when running inside a Firebase-hosted runtime (emulator or deployed
 * Cloud Functions), used mainly for diagnostics/logging.
 */
export function isFirebaseRuntime(): boolean {
  return Boolean(
    process.env.FUNCTIONS_EMULATOR ||
      process.env.K_SERVICE ||
      process.env.FUNCTION_TARGET ||
      process.env.FIREBASE_CONFIG,
  );
}