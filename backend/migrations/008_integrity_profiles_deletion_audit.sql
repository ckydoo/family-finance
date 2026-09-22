-- 008: integrity round (2026-09-22) — idempotent, run after 007.
--
-- 1. Profiles become FAMILY-SCOPED (were globally readable via profile_read
--    using (true)). Roster pulls still work: members of a shared space can
--    see each other's profile. ROLLBACK if a pull regresses (run this one
--    line): drop policy profile_read on public.user_profile; and re-create
--    the `using (true)` variant from migration 004.
-- 2. Account-deletion rules: owner-solo deletes the whole family; owner with
--    members must transfer ownership first; any other member's delete is a
--    clean LEAVE (membership removed, personal rows anonymized, avatar
--    purged, auth account deleted).
-- 3. leave_family RPC for members who want out without deleting the account.
-- 4. Audit rows (activity_log) are written by create_space / join_space /
--    leave_family so who-did-what is recorded server-side.
-- 5. Every new family starts with a default shopping list ('Groceries').

-- ── 1. family-scoped profile visibility ─────────────────────────────────────
drop policy if exists profile_read on public.user_profile;
create policy profile_read on public.user_profile
  for select
  using (
    id = auth.uid()
    or exists (
      select 1
      from public.membership me
      join public.membership other
        on other.space_id = me.space_id
       and other.user_id = user_profile.id
      where me.user_id = auth.uid()
    )
  );

-- ── 2+3. deletion rules & leaving ───────────────────────────────────────────
create or replace function public.leave_family()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_space uuid;
  v_role text;
begin
  if v_user is null then raise exception 'NOT_AUTHENTICATED'; end if;

  select space_id, role into v_space, v_role
  from membership
  where user_id = v_user and invite_status = 'active'
  limit 1;

  if v_space is null then raise exception 'NO_FAMILY'; end if;
  if v_role = 'owner' then
    raise exception 'OWNER_TRANSFER_REQUIRED';
  end if;

  -- Audit row (profile still exists, actor_id FK is satisfied).
  insert into activity_log (space_id, actor_id, action, entity, entity_id, detail, hash)
  values (v_space, v_user, 'member.leave', 'membership', v_user,
          jsonb_build_object('role', v_role),
          md5(v_user::text || ':leave:' || clock_timestamp()));

  delete from membership where space_id = v_space and user_id = v_user;

  -- Anonymize in place: financial rows FK to user_profile.id, so the row
  -- must survive as a tombstone rather than being re-pointed.
  update user_profile
    set name = 'Former member', email = null, avatar_url = null, avatar = '👤'
    where id = v_user;

  delete from storage.objects
    where bucket_id = 'avatars'
      and (storage.foldername(name))[1] = v_user::text;
end;
$$;

grant execute on function public.leave_family() to authenticated;

create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = public, storage
as $$
declare
  v_user uuid := auth.uid();
  v_space uuid;
  v_role text;
  v_members int;
begin
  if v_user is null then raise exception 'NOT_AUTHENTICATED'; end if;

  select space_id, role into v_space, v_role
  from membership
  where user_id = v_user and invite_status = 'active'
  limit 1;

  if v_space is not null and v_role = 'owner' then
    select count(*) into v_members
      from membership where space_id = v_space and invite_status = 'active';
    if v_members > 1 then
      -- Deliberate dead end: an owner cannot delete the account while other
      -- members exist — transfer ownership first (prevents orphaning a
      -- family with no admin and losing shared history silently).
      raise exception 'OWNERSHIP_TRANSFER_REQUIRED';
    end if;
    -- Sole owner: the family and all its data (cascades), then the identity
    -- itself — nothing outside the family references the profile by then.
    delete from family_space where id = v_space;
    delete from storage.objects
      where bucket_id = 'avatars'
        and (storage.foldername(name))[1] = v_user::text;
    delete from auth.users where id = v_user;
    return;
  elsif v_space is not null then
    -- A member deleting the account == leaving, then neutering the account.
    perform public.leave_family();
  end if;

  -- Purge avatar objects…
  delete from storage.objects
    where bucket_id = 'avatars'
      and (storage.foldername(name))[1] = v_user::text;

  -- …revoke every session/refresh token…
  begin
    delete from auth.sessions where user_id = v_user;
    delete from auth.refresh_tokens where user_id = v_user;
  exception when undefined_table then null; -- stub databases without GoTrue tables
  end;

  -- …and neuter the auth identity: password invalidated, email freed for a
  -- future signup, confirmation gate re-armed. The row itself must remain —
  -- retained financial history FKs to the profile that cascades from it.
  update auth.users
    set encrypted_password = '!',
        email = 'deleted+' || substr(v_user::text, 1, 8) || '@invalid.mhuri',
        email_confirmed_at = null
    where id = v_user;
end;
$$;

revoke all on function public.delete_own_account() from public, anon;
grant execute on function public.delete_own_account() to authenticated;

-- ── 4. audit rows on family create/join ─────────────────────────────────────
-- create_space (006 signature) gains an audit insert.
create or replace function public.create_space(
  p_name text,
  p_household text,
  p_base_currency text,
  p_preferred_name text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_space uuid;
  v_user uuid := auth.uid();
  v_code text;
  v_display_name text;
  v_list uuid;
begin
  if v_user is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if btrim(p_name) = '' then raise exception 'FAMILY_NAME_REQUIRED'; end if;
  if p_base_currency not in ('USD', 'ZWG') then
    raise exception 'UNSUPPORTED_CURRENCY';
  end if;
  if public.family_name_taken(p_name) then
    raise exception 'FAMILY_NAME_TAKEN';
  end if;

  v_display_name := coalesce(
    nullif(btrim(p_preferred_name), ''),
    nullif(split_part(coalesce(
      (select email from auth.users where id = v_user), ''), '@', 1), ''),
    'Member'
  );

  insert into public.user_profile (id, name, email)
  values (v_user, v_display_name,
          coalesce((select email from auth.users where id = v_user), ''))
  on conflict (id) do update
    set name = coalesce(nullif(btrim(p_preferred_name), ''), public.user_profile.name);

  v_code := 'MHRI-' || upper(substr(md5(random()::text), 1, 4));

  insert into public.family_space (name, household_type, base_currency)
  values (btrim(p_name), p_household, p_base_currency)
  returning id into v_space;

  insert into public.membership
    (space_id, user_id, role, sharing_level, invite_status, invite_code, joined_at)
  values (v_space, v_user, 'owner', 'full', 'active', v_code, now());

  -- Default shopping list so Lists works from minute one (id is pulled to
  -- every device by the list sync).
  insert into public.shopping_list (space_id, name)
  values (v_space, 'Groceries')
  returning id into v_list;

  insert into public.activity_log
    (space_id, actor_id, action, entity, entity_id, detail, hash)
  values (v_space, v_user, 'family.create', 'family_space', v_space,
          jsonb_build_object('name', btrim(p_name),
                             'base_currency', p_base_currency),
          md5(v_space::text || ':create:' || clock_timestamp()));

  return jsonb_build_object('id', v_space, 'invite_code', v_code);
end;
$$;

grant execute on function public.create_space(text,text,text,text)
  to authenticated;

-- join_space (004 signature) gains an audit insert.
create or replace function public.join_space(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_space uuid;
  v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'NOT_AUTHENTICATED'; end if;

  insert into public.user_profile (id, name, email)
  values (v_user,
          coalesce(nullif(split_part(coalesce(
            (select email from auth.users where id = v_user), ''), '@', 1), ''),
            'Member'),
          coalesce((select email from auth.users where id = v_user), ''))
  on conflict (id) do update
    set name = coalesce(public.user_profile.name, excluded.name);

  select space_id into v_space
  from membership
  where invite_code = upper(trim(p_code))
    and invite_status = 'active'
  limit 1;

  if v_space is null then raise exception 'INVALID_CODE'; end if;

  insert into membership (space_id, user_id, role, sharing_level, invite_status, joined_at)
  values (v_space, v_user, 'adult', 'shared_only', 'active', now())
  on conflict (space_id, user_id) do update
    set invite_status = 'active', joined_at = now();

  insert into activity_log
    (space_id, actor_id, action, entity, entity_id, detail, hash)
  values (v_space, v_user, 'member.join', 'membership', v_user,
          jsonb_build_object('code', 'MHRI-' || right(upper(trim(p_code)), 4)),
          md5(v_user::text || ':join:' || clock_timestamp()));

  return v_space;
end;
$$;

-- ── 5. self-test: the critical policies exist after this file ───────────────
do $$
declare n int;
begin
  select count(*) into n from pg_policies
   where schemaname='public' and tablename='user_profile'
     and policyname='profile_read';
  if n <> 1 then raise exception '008 SELF-TEST FAILED: profile_read missing'; end if;
end $$;
