// Secure assisted account creation for a family owner/parent.
//
// Deploy:
//   supabase functions deploy create-family-member
//
// Required server-side secrets (Supabase normally supplies both):
//   SUPABASE_URL
//   SUPABASE_SERVICE_ROLE_KEY
//
// The service-role key must NEVER be added to Flutter's .env. The caller is
// authenticated with their normal bearer token and authorized again against
// membership before any admin action is performed.

type Json = Record<string, unknown>;

const json = (body: Json, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'POST_ONLY' }, 405);

  const baseUrl = Deno.env.get('SUPABASE_URL')?.replace(/\/+$/, '');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const callerToken = req.headers.get('Authorization');
  if (!baseUrl || !serviceKey) return json({ error: 'SERVER_CONFIG' }, 500);
  if (!callerToken?.startsWith('Bearer ')) {
    return json({ error: 'NOT_AUTHENTICATED' }, 401);
  }

  let input: Json;
  try {
    input = await req.json();
  } catch (_) {
    return json({ error: 'BAD_REQUEST' }, 400);
  }

  const name = String(input.name ?? '').trim();
  const email = String(input.email ?? '').trim().toLowerCase();
  const password = String(input.temporary_password ?? '');
  const role = String(input.role ?? '');
  const roles = new Set(['adult', 'co_parent', 'teen', 'kid', 'viewer']);
  if (name.length < 2 || name.length > 80) {
    return json({ error: 'BAD_NAME' }, 400);
  }
  if (!/^\S+@\S+\.\S+$/.test(email) || email.length > 254) {
    return json({ error: 'BAD_EMAIL' }, 400);
  }
  if (password.length < 10 || !/[A-Za-z]/.test(password) || !/\d/.test(password)) {
    return json({ error: 'WEAK_PASSWORD' }, 400);
  }
  if (!roles.has(role)) return json({ error: 'BAD_ROLE' }, 400);

  const adminHeaders = {
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`,
    'Content-Type': 'application/json',
  };

  // Validate the caller token with Auth; never trust a user id from input.
  const userRes = await fetch(`${baseUrl}/auth/v1/user`, {
    headers: { apikey: serviceKey, Authorization: callerToken },
  });
  if (!userRes.ok) return json({ error: 'NOT_AUTHENTICATED' }, 401);
  const caller = await userRes.json();
  const callerId = String(caller.id ?? '');
  if (!callerId) return json({ error: 'NOT_AUTHENTICATED' }, 401);

  const membershipUrl = new URL(`${baseUrl}/rest/v1/membership`);
  membershipUrl.searchParams.set('select', 'space_id,role');
  membershipUrl.searchParams.set('user_id', `eq.${callerId}`);
  membershipUrl.searchParams.set('invite_status', 'eq.active');
  membershipUrl.searchParams.set('limit', '1');
  const membershipRes = await fetch(membershipUrl, { headers: adminHeaders });
  if (!membershipRes.ok) return json({ error: 'MEMBERSHIP_LOOKUP_FAILED' }, 502);
  const memberships = await membershipRes.json();
  const membership = Array.isArray(memberships) ? memberships[0] : null;
  const callerRole = String(membership?.role ?? '');
  const spaceId = String(membership?.space_id ?? '');
  if (!spaceId || !['owner', 'co_parent'].includes(callerRole)) {
    return json({ error: 'ADMIN_REQUIRED' }, 403);
  }

  // Admin creation does not touch the caller's mobile session. Email is
  // confirmed because the account is parent-provisioned; the password is
  // explicitly labelled temporary in the app and should be changed by the
  // member using Forgot password after their first sign-in.
  const createRes = await fetch(`${baseUrl}/auth/v1/admin/users`, {
    method: 'POST',
    headers: adminHeaders,
    body: JSON.stringify({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        name,
        provisioned_by: callerId,
        must_change_password: true,
      },
    }),
  });
  if (!createRes.ok) {
    const raw = (await createRes.text()).toLowerCase();
    const duplicate = raw.includes('already') || raw.includes('registered') ||
      raw.includes('exists');
    return json({ error: duplicate ? 'EMAIL_EXISTS' : 'ACCOUNT_CREATE_FAILED' },
      duplicate ? 409 : 502);
  }
  const created = await createRes.json();
  const newUserId = String(created.id ?? created.user?.id ?? '');
  if (!newUserId) return json({ error: 'ACCOUNT_CREATE_FAILED' }, 502);

  const cleanup = async () => {
    await fetch(`${baseUrl}/auth/v1/admin/users/${newUserId}`, {
      method: 'DELETE',
      headers: adminHeaders,
    });
  };

  const profileRes = await fetch(`${baseUrl}/rest/v1/user_profile`, {
    method: 'POST',
    headers: { ...adminHeaders, Prefer: 'resolution=merge-duplicates' },
    body: JSON.stringify({ id: newUserId, name, email }),
  });
  if (!profileRes.ok) {
    await cleanup();
    return json({ error: 'PROFILE_CREATE_FAILED' }, 502);
  }

  const memberRes = await fetch(`${baseUrl}/rest/v1/membership`, {
    method: 'POST',
    headers: adminHeaders,
    body: JSON.stringify({
      space_id: spaceId,
      user_id: newUserId,
      role,
      sharing_level: ['adult', 'co_parent'].includes(role)
        ? 'full'
        : 'shared_only',
      invite_status: 'active',
      joined_at: new Date().toISOString(),
    }),
  });
  if (!memberRes.ok) {
    await cleanup(); // auth cascade removes the profile too
    return json({ error: 'MEMBERSHIP_CREATE_FAILED' }, 502);
  }

  // Best-effort audit. Account creation remains successful if observability
  // storage is temporarily unavailable.
  await fetch(`${baseUrl}/rest/v1/activity_log`, {
    method: 'POST',
    headers: adminHeaders,
    body: JSON.stringify({
      space_id: spaceId,
      actor_id: callerId,
      action: 'member.provision',
      entity: 'user_profile',
      entity_id: newUserId,
      detail: { role, email, must_change_password: true },
      hash: `${newUserId}:member.provision:${Date.now()}`,
    }),
  });

  return json({ created: true, user_id: newUserId }, 201);
});
