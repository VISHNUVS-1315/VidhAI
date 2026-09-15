/**
 * Firebase Admin SDK bootstrap that is credentials-provider-neutral.
 *
 * - Firebase Cloud Functions / emulator: initializes with the ambient default
 *   application credentials (no env var needed).
 * - Standalone server (Render): reads FIREBASE_SERVICE_ACCOUNT_JSON
 *   (service-account JSON string set as a secret env var) and initializes with
 *   `credential.cert`. No serviceAccount.json file is ever committed or read.
 *
 * Idempotent and safe to call from multiple modules.
 */

import * as admin from 'firebase-admin';

let done = false;

export function ensureFirebaseAdmin(): typeof admin {
  if (done) return admin;
  if (admin.apps.length > 0) {
    done = true;
    return admin;
  }
  const saJson = (process.env.FIREBASE_SERVICE_ACCOUNT_JSON ?? '').trim();
  if (saJson) {
    try {
      const creds = JSON.parse(saJson) as admin.ServiceAccount;
      admin.initializeApp({ credential: admin.credential.cert(creds) });
    } catch (e) {
      // Malformed service account: keep the process usable but never crash
      // server startup silently; fall back to default credentials if present.
      console.error(
        '[firebase] Could not parse FIREBASE_SERVICE_ACCOUNT_JSON; ' +
          `falling back to default credentials. ${e instanceof Error ? e.message : String(e)}`,
      );
      admin.initializeApp();
    }
  } else {
    admin.initializeApp();
  }
  done = true;
  return admin;
}