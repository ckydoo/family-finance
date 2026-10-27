// Google Play Real-time Developer Notifications (Pub/Sub push receiver).
// Configure the Supabase function without gateway JWT verification and rely
// on the verified Google OIDC push identity below. Re-query Play before any
// entitlement write; notification payloads alone never grant access.

type Json = Record<string, unknown>;
const json = (body: Json, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { 'Content-Type': 'application/json' },
});
const decodePart = (value: string) => JSON.parse(atob(
  value.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4 - value.length % 4) % 4),
));
const b64url = (bytes: Uint8Array) => {
  let raw = '';
  for (const byte of bytes) raw += String.fromCharCode(byte);
  return btoa(raw).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
};
const hashToken = async (token: string) => {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(token));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, '0')).join('');
};

async function verifyPushIdentity(req: Request) {
  const auth = req.headers.get('Authorization') ?? '';
  const match = /^Bearer ([^ ]+)$/.exec(auth);
  if (!match) return false;
  const parts = match[1].split('.');
  if (parts.length !== 3) return false;
  try {
    const header = decodePart(parts[0]);
    const claims = decodePart(parts[1]);
    if (header.alg !== 'RS256' || typeof header.kid !== 'string') return false;
    const issuer = String(claims.iss ?? '');
    const expectedAudience = Deno.env.get('GOOGLE_PLAY_RTDN_AUDIENCE');
    const expectedEmail = Deno.env.get('GOOGLE_PLAY_PUBSUB_SERVICE_ACCOUNT');
    if (!['accounts.google.com', 'https://accounts.google.com'].includes(issuer) ||
        claims.aud !== expectedAudience || claims.email !== expectedEmail ||
        claims.email_verified !== true || Number(claims.exp) <= Date.now() / 1000 ||
        Number(claims.iat) > Date.now() / 1000 + 60) return false;
    const keyRes = await fetch('https://www.googleapis.com/oauth2/v3/certs');
    if (!keyRes.ok) return false;
    const keySet = await keyRes.json();
    const jwk = keySet.keys?.find((key: Json) => key.kid === header.kid);
    if (!jwk) return false;
    const key = await crypto.subtle.importKey('jwk', jwk, {
      name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256',
    }, false, ['verify']);
    const signature = Uint8Array.from(atob(parts[2].replace(/-/g, '+').replace(/_/g, '/')),
      (c) => c.charCodeAt(0));
    return await crypto.subtle.verify('RSASSA-PKCS1-v1_5', key, signature,
      new TextEncoder().encode(`${parts[0]}.${parts[1]}`));
  } catch (_) {
    return false;
  }
}

async function getPublisherToken(credentials: { client_email: string; private_key: string; token_uri?: string }) {
  const now = Math.floor(Date.now() / 1000);
  const issuer = credentials.token_uri ?? 'https://oauth2.googleapis.com/token';
  const unsigned = `${b64url(new TextEncoder().encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })))}.${b64url(new TextEncoder().encode(JSON.stringify({
    iss: credentials.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: issuer,
    iat: now,
    exp: now + 3600,
  })))}`;
  const pem = credentials.private_key.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, '');
  const key = await crypto.subtle.importKey('pkcs8', Uint8Array.from(atob(pem), (c) => c.charCodeAt(0)), {
    name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256',
  }, false, ['sign']);
  const signature = new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key,
    new TextEncoder().encode(unsigned)));
  const assertion = `${unsigned}.${b64url(signature)}`;
  const response = await fetch(issuer, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion,
    }),
  });
  if (!response.ok) throw new Error('PLAY_OAUTH_FAILED');
  const body = await response.json();
  if (typeof body.access_token !== 'string') throw new Error('PLAY_OAUTH_FAILED');
  return body.access_token as string;
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'POST_ONLY' }, 405);
  if (!await verifyPushIdentity(req)) return json({ error: 'INVALID_PUSH_IDENTITY' }, 401);

  const baseUrl = Deno.env.get('SUPABASE_URL')?.replace(/\/+$/, '');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const packageName = Deno.env.get('MHURI_ANDROID_PACKAGE_NAME');
  const credentialsJson = Deno.env.get('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON');
  if (!baseUrl || !serviceKey || !packageName || !credentialsJson) {
    return json({ error: 'SERVER_CONFIG' }, 503);
  }

  let notification: Json;
  try {
    const envelope = await req.json();
    const encoded = envelope.message?.data;
    if (typeof encoded !== 'string') throw new Error();
    const decoded = atob(encoded.replace(/-/g, '+').replace(/_/g, '/'));
    const event = JSON.parse(decoded);
    if (String(event.packageName ?? '') !== packageName || !event.subscriptionNotification) {
      return json({ received: true, ignored: true });
    }
    notification = event.subscriptionNotification;
  } catch (_) {
    return json({ error: 'BAD_PUBSUB_ENVELOPE' }, 400);
  }

  const purchaseToken = String(notification.purchaseToken ?? '');
  if (purchaseToken.length < 20 || purchaseToken.length > 4096) {
    return json({ error: 'BAD_PURCHASE_TOKEN' }, 400);
  }
  const adminHeaders = { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` };
  try {
    const tokenHash = await hashToken(purchaseToken);
    const verificationUrl = new URL(`${baseUrl}/rest/v1/billing_purchase_verification`);
    verificationUrl.searchParams.set('select', 'id,space_id');
    verificationUrl.searchParams.set('purchase_token_hash', `eq.${tokenHash}`);
    verificationUrl.searchParams.set('limit', '1');
    const lookup = await fetch(verificationUrl, { headers: adminHeaders });
    if (!lookup.ok) return json({ error: 'VERIFICATION_LOOKUP_FAILED' }, 502);
    const rows = await lookup.json();
    const verification = Array.isArray(rows) ? rows[0] : null;
    if (!verification) return json({ received: true, ignored: true });

    const credentials = JSON.parse(credentialsJson);
    if (!credentials.client_email || !credentials.private_key) throw new Error('BAD_CREDENTIALS');
    const publisherToken = await getPublisherToken(credentials);
    const subscriptionUrl = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(packageName)}/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`;
    const play = await fetch(subscriptionUrl, { headers: { Authorization: `Bearer ${publisherToken}` } });
    if (!play.ok) return json({ error: 'PLAY_RECHECK_FAILED' }, 502);
    const subscription = await play.json();
    const products = new Set([
      Deno.env.get('GOOGLE_PLAY_MONTHLY_PRODUCT_ID') ?? '',
      Deno.env.get('GOOGLE_PLAY_ANNUAL_PRODUCT_ID') ?? '',
    ].filter(Boolean));
    const items = Array.isArray(subscription.lineItems) ? subscription.lineItems : [];
    const line = items.find((item: Json) => products.has(String(item.productId ?? '')));
    if (!line) return json({ error: 'UNKNOWN_PRODUCT' }, 422);
    const state = String(subscription.subscriptionState ?? '');
    const mapped = state === 'SUBSCRIPTION_STATE_ACTIVE' ? 'active'
      : state === 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD' ? 'gracePeriod'
      : state === 'SUBSCRIPTION_STATE_CANCELED' ? 'canceledActive'
      : ['SUBSCRIPTION_STATE_ON_HOLD', 'SUBSCRIPTION_STATE_PAUSED', 'SUBSCRIPTION_STATE_PENDING'].includes(state) ? 'billingIssue'
      : state === 'SUBSCRIPTION_STATE_EXPIRED' ? 'expired' : 'revoked';
    const expiresAt = typeof line?.expiryTime === 'string' ? line.expiryTime : null;
    const active = !!line && ['active', 'gracePeriod', 'canceledActive'].includes(mapped) &&
      (!expiresAt || Date.parse(expiresAt) > Date.now());
    const features = active ? ['smart_commitments', 'advanced_insights', 'advanced_reports', 'enhanced_reports',
      'cash_flow_forecast', 'savings_projections', 'family_polls_pins',
      'enhanced_family_chat',
      'period_preparation', 'financial_health', 'debt_planning',
      'advanced_chat_search', 'ask_mhuri'] : [];
    const verifiedAt = new Date().toISOString();
    const update = await fetch(`${baseUrl}/rest/v1/family_entitlement?on_conflict=space_id`, {
      method: 'POST',
      headers: { ...adminHeaders, 'Content-Type': 'application/json',
        Prefer: 'resolution=merge-duplicates,return=minimal' },
      body: JSON.stringify({
        space_id: verification.space_id,
        status: mapped,
        features,
        product_id: line?.productId ?? null,
        store: 'google_play',
        expires_at: expiresAt,
        verified_at: verifiedAt,
        updated_at: verifiedAt,
      }),
    });
    if (!update.ok) return json({ error: 'ENTITLEMENT_UPDATE_FAILED' }, 502);
    const recordUpdate = await fetch(`${baseUrl}/rest/v1/billing_purchase_verification?id=eq.${encodeURIComponent(String(verification.id))}`, {
      method: 'PATCH',
      headers: { ...adminHeaders, 'Content-Type': 'application/json', Prefer: 'return=minimal' },
      body: JSON.stringify({
        product_id: line?.productId ?? notification.subscriptionId ?? 'unknown',
        state: active ? 'verified' : mapped === 'revoked' ? 'revoked' : 'rejected',
        verified_at: verifiedAt,
      }),
    });
    if (!recordUpdate.ok) return json({ error: 'VERIFICATION_UPDATE_FAILED' }, 502);
    return json({ received: true, updated: true });
  } catch (_) {
    return json({ error: 'RTDN_PROCESSING_FAILED' }, 503);
  }
});
