import { readFileSync } from 'node:fs';
import admin from 'firebase-admin';
import { env } from './env';
import { query } from './db';

// Lazy init so the API still boots in dev without Firebase configured.
// In that mode every send falls back to a stdout log so the flow is visible.
let initAttempted = false;
let messaging: admin.messaging.Messaging | null = null;

function getMessaging(): admin.messaging.Messaging | null {
  if (initAttempted) return messaging;
  initAttempted = true;

  let credentialJson: string | null = null;
  if (env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    credentialJson = env.FIREBASE_SERVICE_ACCOUNT_JSON;
  } else if (env.FIREBASE_SERVICE_ACCOUNT_PATH) {
    try {
      credentialJson = readFileSync(env.FIREBASE_SERVICE_ACCOUNT_PATH, 'utf-8');
    } catch (e) {
      console.warn('[push] failed to read service account file', e);
      return null;
    }
  } else {
    console.log('[push:dev] no Firebase credentials — pushes will be logged to stdout');
    return null;
  }

  try {
    const parsed = JSON.parse(credentialJson);
    admin.initializeApp({ credential: admin.credential.cert(parsed) });
    messaging = admin.messaging();
    console.log('[push] firebase-admin initialised');
    return messaging;
  } catch (e) {
    console.warn('[push] failed to init firebase-admin', e);
    return null;
  }
}

export type PushPayload = {
  title: string;
  body: string;
  // Free-form key/values delivered to the client. Strings only — FCM
  // requires string values in the data block, so callers pre-stringify.
  data?: Record<string, string>;
};

async function loadTokensForAgent(agentId: string): Promise<string[]> {
  const { rows } = await query<{ token: string }>(
    `SELECT token FROM agent_devices WHERE agent_id = $1`,
    [agentId],
  );
  return rows.map((r) => r.token);
}

async function loadTokensForOnlineAgents(): Promise<string[]> {
  const { rows } = await query<{ token: string }>(
    `SELECT d.token
       FROM agent_devices d
       JOIN agents a ON a.id = d.agent_id
      WHERE a.is_online = TRUE AND a.is_active = TRUE`,
  );
  return rows.map((r) => r.token);
}

async function pruneInvalidTokens(badTokens: string[]) {
  if (badTokens.length === 0) return;
  await query(`DELETE FROM agent_devices WHERE token = ANY($1::text[])`, [badTokens]);
}

async function sendToTokens(tokens: string[], payload: PushPayload) {
  if (tokens.length === 0) return;
  const fcm = getMessaging();
  if (!fcm) {
    console.log(`[push:dev] would send to ${tokens.length} device(s):`, payload);
    return;
  }

  const res = await fcm.sendEachForMulticast({
    tokens,
    notification: { title: payload.title, body: payload.body },
    data: payload.data ?? {},
    android: { priority: 'high' },
    apns: { payload: { aps: { sound: 'default' } } },
  });

  const stale: string[] = [];
  res.responses.forEach((r, i) => {
    if (r.success) return;
    const code = r.error?.code;
    if (
      code === 'messaging/registration-token-not-registered' ||
      code === 'messaging/invalid-registration-token'
    ) {
      stale.push(tokens[i]);
    } else {
      console.warn('[push] send error', code, r.error?.message);
    }
  });
  if (stale.length) await pruneInvalidTokens(stale);
}

export async function sendPushToAgent(agentId: string, payload: PushPayload) {
  try {
    const tokens = await loadTokensForAgent(agentId);
    await sendToTokens(tokens, payload);
  } catch (e) {
    console.warn('[push] agent send failed', e);
  }
}

export async function sendPushToOnlineAgents(payload: PushPayload) {
  try {
    const tokens = await loadTokensForOnlineAgents();
    await sendToTokens(tokens, payload);
  } catch (e) {
    console.warn('[push] broadcast failed', e);
  }
}
