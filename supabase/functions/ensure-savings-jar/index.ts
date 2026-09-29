// Creates (or returns) the authenticated member's personal savings jar.
// Goal creation remains privileged; teens can contribute but cannot create
// arbitrary family goals through the normal goal RLS policy.

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

  const adminHeaders = {
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`,
    'Content-Type': 'application/json',
  };

  const userRes = await fetch(`${baseUrl}/auth/v1/user`, {
    headers: { apikey: serviceKey, Authorization: callerToken },
  });
  if (!userRes.ok) return json({ error: 'NOT_AUTHENTICATED' }, 401);
  const caller = await userRes.json();
  const callerId = String(caller.id ?? '');
  if (!callerId) return json({ error: 'NOT_AUTHENTICATED' }, 401);

  let input: Json = {};
  try {
    input = await req.json();
  } catch (_) {
    // An empty body means "my own jar".
  }
  const requestedMemberId = String(input.member_id ?? callerId);

  const membershipUrl = new URL(`${baseUrl}/rest/v1/membership`);
  membershipUrl.searchParams.set('select', 'space_id,role');
  membershipUrl.searchParams.set('user_id', `eq.${callerId}`);
  membershipUrl.searchParams.set('invite_status', 'eq.active');
  membershipUrl.searchParams.set('limit', '1');
  const membershipRes = await fetch(membershipUrl, { headers: adminHeaders });
  if (!membershipRes.ok) return json({ error: 'MEMBERSHIP_LOOKUP_FAILED' }, 502);
  const memberships = await membershipRes.json();
  const membership = Array.isArray(memberships) ? memberships[0] : null;
  const spaceId = String(membership?.space_id ?? '');
  const role = String(membership?.role ?? '');
  if (!spaceId || !['owner', 'adult', 'co_parent', 'teen', 'kid'].includes(role)) {
    return json({ error: 'MEMBER_REQUIRED' }, 403);
  }
  if (requestedMemberId !== callerId &&
      !['owner', 'adult', 'co_parent'].includes(role)) {
    return json({ error: 'PARENT_REQUIRED' }, 403);
  }

  const targetUrl = new URL(`${baseUrl}/rest/v1/membership`);
  targetUrl.searchParams.set('select', 'role');
  targetUrl.searchParams.set('space_id', `eq.${spaceId}`);
  targetUrl.searchParams.set('user_id', `eq.${requestedMemberId}`);
  targetUrl.searchParams.set('invite_status', 'eq.active');
  targetUrl.searchParams.set('limit', '1');
  const targetRes = await fetch(targetUrl, { headers: adminHeaders });
  if (!targetRes.ok) return json({ error: 'MEMBERSHIP_LOOKUP_FAILED' }, 502);
  const targets = await targetRes.json();
  const target = Array.isArray(targets) ? targets[0] : null;
  const targetRole = String(target?.role ?? '');
  if (!targetRole) return json({ error: 'TARGET_NOT_IN_FAMILY' }, 404);

  const existingUrl = new URL(`${baseUrl}/rest/v1/goal`);
  existingUrl.searchParams.set('select', '*');
  existingUrl.searchParams.set('space_id', `eq.${spaceId}`);
  existingUrl.searchParams.set('owner_member_id', `eq.${requestedMemberId}`);
  existingUrl.searchParams.set('status', 'eq.active');
  existingUrl.searchParams.set('limit', '1');
  const existingRes = await fetch(existingUrl, { headers: adminHeaders });
  if (!existingRes.ok) return json({ error: 'GOAL_LOOKUP_FAILED' }, 502);
  const existing = await existingRes.json();
  if (Array.isArray(existing) && existing.length > 0) {
    return json({ goal: existing[0] });
  }

  const createRes = await fetch(`${baseUrl}/rest/v1/goal?on_conflict=id`, {
    method: 'POST',
    headers: {
      ...adminHeaders,
      Prefer: 'resolution=merge-duplicates,return=representation',
    },
    body: JSON.stringify({
      // One deterministic personal jar per user also makes double taps safe.
      id: requestedMemberId,
      space_id: spaceId,
      name: 'My savings',
      icon: 'goal',
      target_minor: 10000,
      target_currency: 'USD',
      owner_member_id: requestedMemberId,
      is_kid_jar: targetRole === 'kid',
      status: 'active',
    }),
  });
  if (!createRes.ok) return json({ error: 'GOAL_CREATE_FAILED' }, 502);
  const created = await createRes.json();
  const goal = Array.isArray(created) ? created[0] : created;
  if (!goal) return json({ error: 'GOAL_CREATE_FAILED' }, 502);
  return json({ goal }, 201);
});
