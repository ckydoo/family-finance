// Phase 1 server-side entitlement lookup/verification boundary.
// Intentionally fail-closed until Google Play Publisher API credentials and
// package/product configuration are supplied. Never trust client `isPlus`.

type Json = Record<string, unknown>;

const json = (body: Json, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });

const base64Url = (bytes: Uint8Array) => {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
};

const encodeJson = (value: Json) =>
  base64Url(new TextEncoder().encode(JSON.stringify(value)));

async function publisherAccessToken(credentials: {
  client_email: string;
  private_key: string;
  token_uri?: string;
}) {
  const now = Math.floor(Date.now() / 1000);
  const unsigned = `${encodeJson({ alg: 'RS256', typ: 'JWT' })}.${encodeJson({
    iss: credentials.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: credentials.token_uri ?? 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  })}`;
  const pem = credentials.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s/g, '');
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    'pkcs8', der, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false,
    ['sign'],
  );
  const signature = new Uint8Array(await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned),
  ));
  const assertion = `${unsigned}.${base64Url(signature)}`;
  const tokenRes = await fetch(credentials.token_uri ?? 'https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!tokenRes.ok) throw new Error('PLAY_OAUTH_FAILED');
  const tokenBody = await tokenRes.json();
  const token = String(tokenBody.access_token ?? '');
  if (!token) throw new Error('PLAY_OAUTH_FAILED');
  return token;
}

const plusState = (subscription: Json): string => {
  const state = String(subscription.subscriptionState ?? '');
  if (state === 'SUBSCRIPTION_STATE_ACTIVE') return 'active';
  if (state === 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD') return 'gracePeriod';
  if (state === 'SUBSCRIPTION_STATE_CANCELED') return 'canceledActive';
  if (state === 'SUBSCRIPTION_STATE_ON_HOLD' ||
      state === 'SUBSCRIPTION_STATE_PAUSED' ||
      state === 'SUBSCRIPTION_STATE_PENDING') return 'billingIssue';
  if (state === 'SUBSCRIPTION_STATE_EXPIRED') return 'expired';
  return 'revoked';
};

async function hashToken(token: string) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(token));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, '0')).join('');
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'POST_ONLY' }, 405);

  const baseUrl = Deno.env.get('SUPABASE_URL')?.replace(/\/+$/, '');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const authHeader = req.headers.get('Authorization');
  if (!baseUrl || !serviceKey) return json({ error: 'SERVER_CONFIG' }, 500);
  if (!authHeader?.startsWith('Bearer ')) {
    return json({ error: 'NOT_AUTHENTICATED' }, 401);
  }

  let input: Json;
  try {
    input = await req.json();
  } catch (_) {
    return json({ error: 'BAD_REQUEST' }, 400);
  }
  const familyId = String(input.family_id ?? '').trim();
  if (!familyId) return json({ error: 'FAMILY_REQUIRED' }, 400);

  const requestedToken = input.purchase_token;
  if (requestedToken != null && (typeof requestedToken !== 'string' ||
      requestedToken.length < 20 || requestedToken.length > 4096)) {
    return json({ error: 'INVALID_PURCHASE_TOKEN' }, 400);
  }

  const adminHeaders = {
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`,
  };
  const userRes = await fetch(`${baseUrl}/auth/v1/user`, {
    headers: { apikey: serviceKey, Authorization: authHeader },
  });
  if (!userRes.ok) return json({ error: 'NOT_AUTHENTICATED' }, 401);
  const user = await userRes.json();
  const userId = String(user.id ?? '');
  if (!userId) return json({ error: 'NOT_AUTHENTICATED' }, 401);

  // Verify family membership server-side; never accept a family chosen by a
  // client without checking the authenticated caller belongs to it.
  const memberUrl = new URL(`${baseUrl}/rest/v1/membership`);
  memberUrl.searchParams.set('select', 'space_id');
  memberUrl.searchParams.set('space_id', `eq.${familyId}`);
  memberUrl.searchParams.set('user_id', `eq.${userId}`);
  memberUrl.searchParams.set('invite_status', 'eq.active');
  memberUrl.searchParams.set('limit', '1');
  const memberRes = await fetch(memberUrl, { headers: adminHeaders });
  if (!memberRes.ok) return json({ error: 'MEMBERSHIP_LOOKUP_FAILED' }, 502);
  const memberships = await memberRes.json();
  if (!Array.isArray(memberships) || memberships.length === 0) {
    return json({ error: 'FAMILY_ACCESS_DENIED' }, 403);
  }

  // A posted token is accepted only after Publisher API verification.
  const purchaseToken = requestedToken;
  if (purchaseToken != null) {
    const packageName = Deno.env.get('MHURI_ANDROID_PACKAGE_NAME');
    const credentialsJson = Deno.env.get('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON');
    if (!packageName || !credentialsJson || typeof purchaseToken !== 'string' ||
        purchaseToken.length < 20 || purchaseToken.length > 4096) {
      return json({ error: 'STORE_VERIFICATION_NOT_CONFIGURED' }, 503);
    }
    let credentials: { client_email: string; private_key: string; token_uri?: string };
    try {
      credentials = JSON.parse(credentialsJson);
      if (!credentials.client_email || !credentials.private_key) throw new Error();
    } catch (_) {
      return json({ error: 'STORE_VERIFICATION_NOT_CONFIGURED' }, 503);
    }
    try {
      const accessToken = await publisherAccessToken(credentials);
      const playUrl = new URL(
        `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(packageName)}/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`,
      );
      const playRes = await fetch(playUrl, {
        headers: { Authorization: `Bearer ${accessToken}` },
      });
      if (!playRes.ok) {
        // Google explains whether verification failed because of permissions,
        // package ownership, or an invalid token. Keep the purchase token and
        // credentials out of logs while retaining that actionable response.
        const playError = (await playRes.text()).slice(0, 1000);
        console.error('PLAY_SUBSCRIPTION_VERIFICATION_FAILED', {
          status: playRes.status,
          packageName,
          response: playError,
        });
        return json({
          // Keep the status in the existing error field because released app
          // versions surface that field but do not preserve extra JSON fields.
          error: `PURCHASE_NOT_VERIFIED_GOOGLE_${playRes.status}`,
          play_status: playRes.status,
        }, 422);
      }
      const subscription = await playRes.json() as Json;
      const lineItems = Array.isArray(subscription.lineItems) ? subscription.lineItems : [];
      const configuredProducts = new Set([
        Deno.env.get('GOOGLE_PLAY_MONTHLY_PRODUCT_ID') ?? '',
        Deno.env.get('GOOGLE_PLAY_ANNUAL_PRODUCT_ID') ?? '',
      ].filter(Boolean));
      if (configuredProducts.size === 0) {
        return json({ error: 'STORE_PRODUCTS_NOT_CONFIGURED' }, 503);
      }
      const line = lineItems.find((item: Json) =>
        configuredProducts.has(String(item.productId ?? ''))
      ) as Json | undefined;
      if (!line) return json({ error: 'UNKNOWN_PRODUCT' }, 422);
      if (input.product_id != null &&
          String(input.product_id) !== String(line.productId ?? '')) {
        return json({ error: 'PRODUCT_MISMATCH' }, 422);
      }

      const status = plusState(subscription);
      const expiry = typeof line.expiryTime === 'string' ? line.expiryTime : null;
      const active = ['active', 'gracePeriod', 'canceledActive'].includes(status) &&
        (!expiry || Date.parse(expiry) > Date.now());
      const features = active
        ? ['smart_commitments', 'advanced_insights', 'advanced_reports', 'enhanced_reports',
          'cash_flow_forecast', 'savings_projections',
          'period_preparation', 'financial_health', 'debt_planning',
          'family_polls_pins', 'enhanced_family_chat',
          'advanced_chat_search', 'ask_mhuri']
        : [];
      const verifiedAt = new Date().toISOString();
      const tokenHash = await hashToken(purchaseToken);
      const existingUrl = new URL(`${baseUrl}/rest/v1/billing_purchase_verification`);
      existingUrl.searchParams.set('select', 'id,space_id');
      existingUrl.searchParams.set('purchase_token_hash', `eq.${tokenHash}`);
      existingUrl.searchParams.set('limit', '1');
      const existingRes = await fetch(existingUrl, { headers: adminHeaders });
      if (!existingRes.ok) return json({ error: 'VERIFICATION_LOOKUP_FAILED' }, 502);
      const existingRows = await existingRes.json();
      const existing = Array.isArray(existingRows) ? existingRows[0] : null;
      let entitlementFamilyId = familyId;
      let inheritedRestore = false;
      if (existing && String(existing.space_id) !== familyId) {
        const grantUrl = new URL(`${baseUrl}/rest/v1/family_plus_space_grant`);
        grantUrl.searchParams.set('select', 'source_space_id');
        grantUrl.searchParams.set('space_id', `eq.${familyId}`);
        grantUrl.searchParams.set('limit', '1');
        const grantRes = await fetch(grantUrl, { headers: adminHeaders });
        if (!grantRes.ok) return json({ error: 'VERIFICATION_LOOKUP_FAILED' }, 502);
        const grantRows = await grantRes.json();
        const grant = Array.isArray(grantRows) ? grantRows[0] : null;
        if (!grant || String(grant.source_space_id) !== String(existing.space_id)) {
          return json({ error: 'PURCHASE_ALREADY_CLAIMED' }, 409);
        }
        entitlementFamilyId = String(existing.space_id);
        inheritedRestore = true;
      }
      if (!existing) {
        const currentEntitlementUrl = new URL(`${baseUrl}/rest/v1/family_entitlement`);
        currentEntitlementUrl.searchParams.set('select', 'status,expires_at');
        currentEntitlementUrl.searchParams.set('space_id', `eq.${entitlementFamilyId}`);
        currentEntitlementUrl.searchParams.set('limit', '1');
        const currentEntRes = await fetch(currentEntitlementUrl, { headers: adminHeaders });
        if (!currentEntRes.ok) return json({ error: 'VERIFICATION_LOOKUP_FAILED' }, 502);
        const currentEntRows = await currentEntRes.json();
        const currentEnt = Array.isArray(currentEntRows) ? currentEntRows[0] : null;
        const currentStillActive = currentEnt &&
          ['active', 'gracePeriod', 'canceledActive'].includes(String(currentEnt.status ?? '')) &&
          (!currentEnt.expires_at || Date.parse(String(currentEnt.expires_at)) > Date.now());
        if (currentStillActive) {
          return json({ error: 'FAMILY_ALREADY_HAS_PURCHASE' }, 409);
        }
      }
      const verificationRow = {
        space_id: entitlementFamilyId,
        store: 'google_play',
        product_id: String(line.productId),
        purchase_token_hash: tokenHash,
        state: active ? 'verified' : status === 'revoked' ? 'revoked' : 'rejected',
        verified_at: verifiedAt,
      };
      const recordRes = existing
        ? await fetch(`${baseUrl}/rest/v1/billing_purchase_verification?id=eq.${encodeURIComponent(String(existing.id))}`, {
          method: 'PATCH',
          headers: { ...adminHeaders, 'Content-Type': 'application/json', Prefer: 'return=minimal' },
          body: JSON.stringify(verificationRow),
        })
        : await fetch(`${baseUrl}/rest/v1/billing_purchase_verification`, {
          method: 'POST',
          headers: { ...adminHeaders, 'Content-Type': 'application/json', Prefer: 'return=minimal' },
          body: JSON.stringify({ ...verificationRow, purchase_token_hash: tokenHash }),
        });
      if (!recordRes.ok) return json({ error: 'VERIFICATION_RECORD_FAILED' }, 502);

      // A granted family uses the source family's subscription until the user
      // starts a separate purchase for this space. Once verified, detach it so
      // later lifecycle events for the old subscription cannot overwrite it.
      if (!inheritedRestore) {
        const detachGrantRes = await fetch(
          `${baseUrl}/rest/v1/family_plus_space_grant?space_id=eq.${encodeURIComponent(familyId)}`,
          { method: 'DELETE', headers: adminHeaders },
        );
        if (!detachGrantRes.ok) return json({ error: 'ENTITLEMENT_UPDATE_FAILED' }, 502);
      }

      const entitlementRes = await fetch(`${baseUrl}/rest/v1/family_entitlement?on_conflict=space_id`, {
        method: 'POST',
        headers: {
          ...adminHeaders,
          'Content-Type': 'application/json',
          Prefer: 'resolution=merge-duplicates,return=representation',
        },
        body: JSON.stringify({
          space_id: entitlementFamilyId,
          status,
          features,
          product_id: String(line.productId),
          store: 'google_play',
          expires_at: expiry,
          verified_at: verifiedAt,
          updated_at: verifiedAt,
        }),
      });
      if (!entitlementRes.ok) return json({ error: 'ENTITLEMENT_UPDATE_FAILED' }, 502);
      return json({
        family_id: familyId,
        status,
        features,
        expires_at: expiry,
        verified_at: verifiedAt,
      });
    } catch (_) {
      return json({ error: 'STORE_VERIFICATION_UNAVAILABLE' }, 503);
    }
  }

  const entitlementUrl = new URL(`${baseUrl}/rest/v1/family_entitlement`);
  entitlementUrl.searchParams.set('select', '*');
  entitlementUrl.searchParams.set('space_id', `eq.${familyId}`);
  entitlementUrl.searchParams.set('limit', '1');
  const entitlementRes = await fetch(entitlementUrl, { headers: adminHeaders });
  if (!entitlementRes.ok) return json({ error: 'ENTITLEMENT_LOOKUP_FAILED' }, 502);
  const rows = await entitlementRes.json();
  const row = Array.isArray(rows) ? rows[0] : null;
  return json(row ? {
    family_id: familyId,
    status: row.status,
    features: row.features,
    expires_at: row.expires_at,
    verified_at: row.verified_at,
  } : {
    family_id: familyId,
    status: 'free',
    features: [],
    expires_at: null,
    verified_at: null,
  });
});
