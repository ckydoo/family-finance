// Webhook-authenticated push dispatcher for shared family events & chat.
// Gateway JWT verification is off (`verify_jwt: false`); every request must
// supply the Vault-managed `x-webhook-secret` shared secret.

type Activity = {
  space_id: string;
  actor_id: string;
  action: string;
  detail?: Record<string, unknown>;
};

type ChatMessage = {
  id: string;
  space_id: string;
  sender_id: string;
  sender_name?: string;
  text?: string;
  media_url?: string;
  media_type?: string;
  sticker?: string;
  deleted?: boolean;
};

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
};

const messages: Record<string, [string, string]> = {
  'tx.create': ['New family transaction', 'A transaction was added to your family ledger.'],
  'goal.contribute': ['Savings goal updated', 'A contribution was added to a family goal.'],
  'request.create': ['New family request', 'A family request is waiting for review.'],
  'request.approve': ['Request approved', 'A family request was approved.'],
  'request.decline': ['Request declined', 'A family request was declined.'],
};

const b64url = (bytes: Uint8Array): string => {
  let raw = '';
  for (const byte of bytes) raw += String.fromCharCode(byte);
  return btoa(raw).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
};

const constantTimeEqual = (a: string, b: string): boolean => {
  const enc = new TextEncoder();
  const ab = enc.encode(a);
  const bb = enc.encode(b);
  if (ab.length !== bb.length) return false;
  let diff = 0;
  for (let i = 0; i < ab.length; i++) diff |= ab[i] ^ bb[i];
  return diff === 0;
};

const truncateBody = (text: string, maxLen = 160): string =>
  text.length <= maxLen ? text : `${text.slice(0, maxLen - 1).trimEnd()}…`;

export async function getFcmAccessToken(credentials: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const tokenUri = credentials.token_uri ?? 'https://oauth2.googleapis.com/token';
  const header = b64url(new TextEncoder().encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })));
  const claims = b64url(new TextEncoder().encode(JSON.stringify({
    iss: credentials.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: tokenUri,
    iat: now,
    exp: now + 3600,
  })));
  const unsigned = `${header}.${claims}`;
  const pem = credentials.private_key.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, '');
  const key = await crypto.subtle.importKey(
    'pkcs8',
    Uint8Array.from(atob(pem), (c) => c.charCodeAt(0)),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned)),
  );
  const assertion = `${unsigned}.${b64url(signature)}`;
  const res = await fetch(tokenUri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!res.ok) throw new Error(`FCM_OAUTH_${res.status}`);
  const body = await res.json() as Record<string, unknown>;
  if (typeof body.access_token !== 'string' || !body.access_token) {
    throw new Error('FCM_OAUTH_EMPTY_TOKEN');
  }
  return body.access_token;
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('POST only', { status: 405 });
  const webhookSecret = Deno.env.get('PUSH_WEBHOOK_SECRET') ?? '';
  const providedSecret = req.headers.get('x-webhook-secret') ?? '';
  if (!webhookSecret || !providedSecret || !constantTimeEqual(providedSecret, webhookSecret)) {
    return new Response('Unauthorized', { status: 401 });
  }

  let payload: Record<string, unknown>;
  try {
    payload = await req.json() as Record<string, unknown>;
  } catch (_) {
    return Response.json({ error: 'INVALID_JSON' }, { status: 400 });
  }

  const raw = (payload.record ?? payload) as Record<string, unknown>;
  const isChat = payload.table === 'family_chat_message';
  const chat = raw as unknown as ChatMessage;
  const record: Activity = isChat
    ? {
        space_id: String(chat.space_id ?? ''),
        actor_id: String(chat.sender_id ?? ''),
        action: 'chat.message',
      }
    : (raw as unknown as Activity);

  const copy: [string, string] | undefined = isChat && !chat.deleted
    ? [
        chat.sender_name?.trim() || 'New family message',
        truncateBody(
          chat.text?.trim() ||
            (chat.sticker ? `Sent a sticker ${chat.sticker}` : null) ||
            (chat.media_type === 'audio' ? 'Sent a voice note.' : null) ||
            (chat.media_url ? 'Sent a photo.' : null) ||
            'A family member sent an update.',
        ),
      ]
    : messages[record.action];
  if (!copy || !record.space_id) {
    return Response.json({ sent: 0, ignored: true });
  }

  const baseUrl = Deno.env.get('SUPABASE_URL')?.replace(/\/+$/, '');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const rawServiceAccount = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
  if (!baseUrl || !serviceKey || !rawServiceAccount) {
    return Response.json({ error: 'SERVER_CONFIG' }, { status: 503 });
  }

  let serviceAccount: ServiceAccount;
  try {
    serviceAccount = JSON.parse(rawServiceAccount) as ServiceAccount;
    if (!serviceAccount.project_id || !serviceAccount.client_email || !serviceAccount.private_key) {
      throw new Error('MISSING_FIREBASE_FIELDS');
    }
  } catch (_) {
    return Response.json({ error: 'SERVER_CONFIG' }, { status: 503 });
  }

  const adminHeaders = {
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`,
  };

  // CRITICAL: always filter `invite_status=eq.active` so former/removed
  // members (`left` / `removed`) never receive family chat or ledger pushes.
  const memberUrl = new URL(`${baseUrl}/rest/v1/membership`);
  memberUrl.searchParams.set('select', 'user_id');
  memberUrl.searchParams.set('space_id', `eq.${record.space_id}`);
  memberUrl.searchParams.set('invite_status', 'eq.active');

  if (record.action.startsWith('request.') && record.detail?.requester_id) {
    if (record.action === 'request.create') {
      memberUrl.searchParams.set('role', 'in.(owner,adult,co_parent)');
      if (record.actor_id) {
        memberUrl.searchParams.set('user_id', `neq.${record.actor_id}`);
      }
    } else {
      memberUrl.searchParams.set('user_id', `eq.${String(record.detail.requester_id)}`);
    }
  } else if (record.actor_id) {
    memberUrl.searchParams.set('user_id', `neq.${record.actor_id}`);
  }

  const memberRes = await fetch(memberUrl, { headers: adminHeaders });
  if (!memberRes.ok) {
    return Response.json({ error: 'MEMBERSHIP_LOOKUP_FAILED' }, { status: 502 });
  }
  const members = await memberRes.json() as Array<{ user_id?: string }>;
  const userIds = [
    ...new Set(
      (Array.isArray(members) ? members : [])
        .map((m) => String(m.user_id ?? ''))
        .filter(Boolean),
    ),
  ];
  if (userIds.length === 0) return Response.json({ sent: 0 });

  const deviceUrl = new URL(`${baseUrl}/rest/v1/push_device`);
  deviceUrl.searchParams.set('select', 'token');
  deviceUrl.searchParams.set('user_id', `in.(${userIds.join(',')})`);
  const deviceRes = await fetch(deviceUrl, { headers: adminHeaders });
  if (!deviceRes.ok) {
    return Response.json({ error: 'DEVICE_LOOKUP_FAILED' }, { status: 502 });
  }
  const devices = await deviceRes.json() as Array<{ token?: string }>;
  const tokens = [
    ...new Set(
      (Array.isArray(devices) ? devices : [])
        .map((d) => String(d.token ?? ''))
        .filter(Boolean),
    ),
  ];
  if (tokens.length === 0) return Response.json({ sent: 0 });

  let accessToken: string;
  try {
    accessToken = await getFcmAccessToken(serviceAccount);
  } catch (_) {
    return new Response('Could not authorize FCM', { status: 502 });
  }

  const endpoint = `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(serviceAccount.project_id)}/messages:send`;
  let sent = 0;
  for (const token of tokens) {
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: copy[0], body: copy[1] },
          data: { event: record.action, space_id: record.space_id },
          android: { priority: 'high', notification: { channel_id: 'mhuri_family_updates' } },
          apns: { payload: { aps: { sound: 'default' } } },
        },
      }),
    });
    if (response.ok) {
      sent++;
    } else {
      const errorBody = await response.text();
      if (errorBody.includes('UNREGISTERED') || errorBody.includes('NOT_FOUND')) {
        const pruneUrl = new URL(`${baseUrl}/rest/v1/push_device`);
        pruneUrl.searchParams.set('token', `eq.${token}`);
        await fetch(pruneUrl, { method: 'DELETE', headers: adminHeaders });
      }
    }
  }
  return Response.json({ sent });
});
