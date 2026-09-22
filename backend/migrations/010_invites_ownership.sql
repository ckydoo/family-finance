-- 010: REAL INVITATIONS + OWNERSHIP TRANSFER (Phase 2).
--
-- Invitations become unique, role-bound, expiring, revocable records instead
-- of the one static family code (that code keeps working — join_space is
-- untouched — so nothing breaks; the new flow adds control on top).
--
-- Anti-enumeration: join_invite answers INVALID_CODE for not-found, expired,
-- revoked, already-used AND email-mismatch — a guessed or dead code is
-- indistinguishable. Codes are 6 chars (~16.7M space) and never reused.
-- No uncontrolled reuse: an invite is SINGLE-USE (accepted_* set) and each
-- space can hold at most 5 unredeemed invites.
-- Ownership transfer moves the family code (membership.invite_code) to the
-- new owner so join_space keeps working, swaps roles, and writes an audit
-- row. It is also the gate that lets an owner delete their account (008).

-- ── 1. family_invite ────────────────────────────────────────────────────────
create table if not exists public.family_invite (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.family_space(id) on delete cascade,
  code text not null unique,
  role text not null
    check (role in ('adult','co_parent','teen','kid','viewer')),
  email text,
  created_by uuid not null references public.user_profile(id),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  revoked_at timestamptz,
  accepted_by uuid references public.user_profile(id),
  accepted_at timestamptz
);

create index if not exists family_invite_space_idx
  on public.family_invite (space_id, created_at desc);

alter table public.family_invite enable row level security;

drop policy if exists invite_owner_read on public.family_invite;
create policy invite_owner_read on public.family_invite
  for select
  using (public.space_role(space_id) = 'owner');

drop policy if exists invite_owner_write on public.family_invite;
create policy invite_owner_write on public.family_invite
  for all
  using (public.space_role(space_id) = 'owner')
  with check (public.space_role(space_id) = 'owner');

-- ── 2. create_invite (owner-only, max 5 unredeemed per family) ─────────────
create or replace function public.create_invite(p_role text, p_email text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_space uuid;
  v_code text;
  v_id uuid;
  v_open int;
  v_email text := lower(btrim(coalesce(p_email, '')));
begin
  if v_user is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if p_role not in ('adult','co_parent','teen','kid','viewer') then
    raise exception 'BAD_ROLE';
  end if;

  select space_id into v_space from membership
   where user_id = v_user and role = 'owner' and invite_status = 'active'
   limit 1;
  if v_space is null then raise exception 'OWNER_REQUIRED'; end if;

  select count(*) into v_open from family_invite
   where space_id = v_space
     and revoked_at is null and accepted_at is null
     and expires_at > now();
  if v_open >= 5 then raise exception 'TOO_MANY_INVITES'; end if;

  if v_email <> '' and v_email !~* '^\S+@\S+\.\S+$' then
    raise exception 'BAD_EMAIL';
  end if;

  loop
    v_code := 'MHRI-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
    exit when not exists (select 1 from family_invite where code = v_code);
  end loop;

  insert into family_invite (space_id, code, role, email, created_by)
  values (v_space, v_code, p_role, nullif(v_email, ''), v_user)
  returning id into v_id;

  insert into activity_log (space_id, actor_id, action, entity, entity_id, detail, hash)
  values (v_space, v_user, 'invite.create', 'family_invite', v_id,
          jsonb_build_object('role', p_role, 'email_bound', v_email <> ''),
          md5(v_id::text || ':invite:' || clock_timestamp()));

  return jsonb_build_object('id', v_id, 'code', v_code, 'role', p_role);
end;
$$;

revoke all on function public.create_invite(text, text) from public, anon;
grant execute on function public.create_invite(text, text) to authenticated;

-- ── 3. revoke_invite (owner-only) ───────────────────────────────────────────
create or replace function public.revoke_invite(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_space uuid;
begin
  if v_user is null then raise exception 'NOT_AUTHENTICATED'; end if;

  select space_id into v_space from family_invite
   where id = p_id and revoked_at is null and accepted_at is null
   for update;
  if v_space is null then raise exception 'INVALID_INVITE'; end if;
  if public.space_role(v_space) <> 'owner' then
    raise exception 'OWNER_REQUIRED';
  end if;

  update family_invite set revoked_at = now() where id = p_id;

  insert into activity_log (space_id, actor_id, action, entity, entity_id, detail, hash)
  values (v_space, v_user, 'invite.revoke', 'family_invite', p_id,
          '{}'::jsonb, md5(p_id::text || ':revoke:' || clock_timestamp()));
end;
$$;

revoke all on function public.revoke_invite(uuid) from public, anon;
grant execute on function public.revoke_invite(uuid) to authenticated;

-- ── 4. join_invite (single-use, expiry + revocation + optional email bind) ──
create or replace function public.join_invite(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_rec public.family_invite%rowtype;
  v_email text;
  v_space uuid;
begin
  if v_user is null then raise exception 'NOT_AUTHENTICATED'; end if;

  -- Already in a family? Joining again would orphan shared data — refuse.
  if exists (select 1 from membership
              where user_id = v_user and invite_status = 'active') then
    raise exception 'ALREADY_IN_FAMILY';
  end if;

  v_email := lower(coalesce((select email from auth.users where id = v_user), ''));

  select * into v_rec from family_invite
   where upper(trim(p_code)) = code for update;
  -- One error for every dead-code reason: a guessed code can't be probed.
  if not found then raise exception 'INVALID_CODE'; end if;
  if v_rec.revoked_at is not null then raise exception 'INVALID_CODE'; end if;
  if v_rec.accepted_at is not null then raise exception 'INVALID_CODE'; end if;
  if v_rec.expires_at <= now() then raise exception 'INVALID_CODE'; end if;
  if v_rec.email is not null and v_rec.email <> v_email then
    raise exception 'INVALID_CODE';
  end if;

  -- Ensure the profile exists (first login on a new device).
  insert into public.user_profile (id, name, email)
  values (v_user,
          coalesce(nullif(split_part(coalesce(
            (select email from auth.users where id = v_user), ''), '@', 1), ''),
            'Member'),
          v_email)
  on conflict (id) do update
    set name = coalesce(public.user_profile.name, excluded.name);

  v_space := v_rec.space_id;
  insert into membership
    (space_id, user_id, role, sharing_level, invite_status, joined_at)
  values (
    v_space, v_user, v_rec.role,
    case when v_rec.role in ('adult','co_parent') then 'full' else 'shared_only' end,
    'active', now()
  )
  on conflict (space_id, user_id) do update
    set invite_status = 'active', joined_at = now(), role = excluded.role;

  update family_invite
    set accepted_by = v_user, accepted_at = now()
    where id = v_rec.id;

  insert into activity_log (space_id, actor_id, action, entity, entity_id, detail, hash)
  values (v_space, v_user, 'member.join_invite', 'family_invite', v_rec.id,
          jsonb_build_object('role', v_rec.role),
          md5(v_user::text || ':join_invite:' || clock_timestamp()));

  return v_space;
end;
$$;

revoke all on function public.join_invite(text) from public, anon;
grant execute on function public.join_invite(text) to authenticated;

-- ── 5. transfer_ownership (moves the family code with the role) ─────────────
create or replace function public.transfer_ownership(p_new_owner uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_space uuid;
  v_code text;
begin
  if v_user is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if v_user = p_new_owner then raise exception 'SELF_TRANSFER'; end if;

  select space_id into v_space from membership
   where user_id = v_user and role = 'owner' and invite_status = 'active'
   limit 1;
  if v_space is null then raise exception 'OWNER_REQUIRED'; end if;

  if not exists (select 1 from membership
                  where space_id = v_space and user_id = p_new_owner
                    and invite_status = 'active') then
    raise exception 'NEW_OWNER_NOT_MEMBER';
  end if;

  -- The family's static code lives on the owner's membership row; it moves
  -- with the crown so join_space (old clients, printed papers) keeps working.
  -- (Clear it on the way out — the unique index allows it on one row only.)
  select invite_code into v_code from membership
   where space_id = v_space and user_id = v_user;

  update membership set role = 'adult', invite_code = null
    where space_id = v_space and user_id = v_user;

  update membership
    set role = 'owner',
        invite_code = coalesce(v_code, invite_code)
    where space_id = v_space and user_id = p_new_owner;

  insert into activity_log (space_id, actor_id, action, entity, entity_id, detail, hash)
  values (v_space, v_user, 'role.transfer', 'membership', p_new_owner,
          jsonb_build_object('from', v_user, 'to', p_new_owner),
          md5(v_user::text || ':transfer:' || clock_timestamp()));
end;
$$;

revoke all on function public.transfer_ownership(uuid) from public, anon;
grant execute on function public.transfer_ownership(uuid) to authenticated;

-- ── self-test ───────────────────────────────────────────────────────────────
do $$
declare n int;
begin
  select count(*) into n from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
   where ns.nspname = 'public'
     and p.proname in ('create_invite','revoke_invite','join_invite','transfer_ownership');
  if n <> 4 then raise exception '010 SELF-TEST FAILED: RPCs missing'; end if;
  if not exists (select 1 from information_schema.tables
                  where table_schema='public' and table_name='family_invite') then
    raise exception '010 SELF-TEST FAILED: family_invite missing';
  end if;
end $$;
