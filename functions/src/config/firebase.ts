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

const FIREBASE_PROJECT_ID =
  (process.env.FIREBASE_PROJECT_ID ?? process.env.GOOGLE_CLOUD_PROJECT ?? 'vidhai-app').trim();

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
      admin.initializeApp({
        credential: admin.credential.cert(creds),
        projectId: FIREBASE_PROJECT_ID || undefined,
      });
    } catch (e) {
      // Keep token verification usable even if a malformed credential was
      // supplied: Firebase Auth verification needs the project id to validate
      // aud/iss and fetches Google's public signing certificates.
      console.error(
        '[firebase] Could not parse FIREBASE_SERVICE_ACCOUNT_JSON; ' +
          `initializing with projectId only. ${e instanceof Error ? e.message : String(e)}`,
      );
      admin.initializeApp({ projectId: FIREBASE_PROJECT_ID || undefined });
    }
  } else {
    // Render is not a Google-managed runtime and therefore does not receive
    // GOOGLE_CLOUD_PROJECT automatically. Supplying projectId explicitly lets
    // verifyIdToken() validate Firebase client tokens even when Admin service
    // credentials are temporarily unavailable. Firestore Admin operations may
    // still require a service account; callers already degrade gracefully.
    admin.initializeApp({ projectId: FIREBASE_PROJECT_ID || undefined });
  }
  done = true;
  return admin;
}