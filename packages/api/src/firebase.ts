import { readFileSync } from 'node:fs';
import admin from 'firebase-admin';
import { env } from './env';

// Single firebase-admin app shared by FCM push (push.ts) and ID-token
// verification (routes/auth.ts firebase-login). Lazy + idempotent so the API
// still boots in dev when no credentials are configured.

let initAttempted = false;
let app: admin.app.App | null = null;

export function getFirebaseApp(): admin.app.App | null {
  if (initAttempted) return app;
  initAttempted = true;

  let credentialJson: string | null = null;
  if (env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    credentialJson = env.FIREBASE_SERVICE_ACCOUNT_JSON;
  } else if (env.FIREBASE_SERVICE_ACCOUNT_PATH) {
    try {
      credentialJson = readFileSync(env.FIREBASE_SERVICE_ACCOUNT_PATH, 'utf-8');
    } catch (e) {
      console.warn('[firebase] failed to read service account file', e);
      return null;
    }
  } else {
    console.log('[firebase:dev] no credentials — FCM logs to stdout, auth verify will fail');
    return null;
  }

  try {
    const parsed = JSON.parse(credentialJson);
    app = admin.initializeApp({ credential: admin.credential.cert(parsed) });
    console.log('[firebase] admin SDK initialised');
    return app;
  } catch (e) {
    console.warn('[firebase] failed to init admin SDK', e);
    return null;
  }
}
