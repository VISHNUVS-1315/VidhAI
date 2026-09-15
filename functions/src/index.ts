/**
 * Firebase Cloud Functions wrapper — mounts the shared Express app.
 *
 * The emulator auto-injects functions/.secret.local into process.env, so no
 * defineSecret wiring is needed here. For a deployed Cloud Function, set the
 * same secrets as environment variables (or re-introduce defineSecret) if this
 * path is ever used again — the canonical deployment is the standalone server.
 */

import { onRequest } from 'firebase-functions/v2/https';
import { app } from './app';

export const api = onRequest(
  {
    timeoutSeconds: 300,
    memory: '1GiB',
    maxInstances: 10,
  },
  app,
);