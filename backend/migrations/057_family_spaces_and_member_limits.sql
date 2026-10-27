-- 057: Allow Plus subscribers to create separate family spaces and enforce
-- Free limits on created spaces and family membership on the server.
-- One Plus subscription follows spaces created by its owning family account.

create table if not exists public.family_plus_space_grant (
  space_id uuid primary key references public.family_space(id) on delete cascade,
  source_space_id uuid not null references public.family_space(id) on delete restrict,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  check (space_id <> source_space_id)
);

alter table public.family_plus_space_grant enable row level security;
revoke all on public.family_plus_space_grant from public, anon, authenticated;
grant all on public.family_plus_space_grant to service_role;

create or replace function public.guard_free_owned_family_limit()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_owned integer; v_plus boolean;
begin
  if new.role <> 'owner' or new.invite_status <> 'active' then return new; end if;
  perform pg_advisory_xact_lock(hashtextextended(new.user_id::text, 0));
  select count(*)::integer into v_owned from public.membership m
   where m.user_id = new.user_id and m.role = 'owner' and m.invite_status = 'active'
     and m.space_id <> new.space_id;
  if v_owned = 0 then return new; end if;
  select exists (
    select 1 from public.membership m
    join public.family_entitlement e on e.space_id = m.space_id
    where m.user_id = new.user_id and m.role in ('owner','co_parent','adult')
      and m.invite_status = 'active'
      and m.space_id <> new.space_id
      and e.status in ('active','gracePeriod','canceledActive')
      and (e.expires_at is null or e.expires_at > now())
  ) into v_plus;
  if not v_plus then raise exception 'FAMILY_LIMIT_REACHED'; end if;
  return new;
end;
$$;
revoke all on function public.guard_free_owned_family_limit() from public, anon, authenticated;
drop trigger if exists trg_guard_free_owned_family_limit on public.membership;
create trigger trg_guard_free_owned_family_limit
before insert on public.membership
for each row execute function public.guard_free_owned_family_limit();

create or replace function public.propagate_family_plus_entitlement()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.family_entitlement target
     set status = new.status,
         features = new.features,
         product_id = new.product_id,
         store = new.store,
         expires_at = new.expires_at,
         verified_at = new.verified_at,
         updated_at = new.updated_at
    from public.family_plus_space_grant grant_row
   where grant_row.source_space_id = new.space_id
     and target.space_id = grant_row.space_id;
  return new;
end;
$$;

drop trigger if exists trg_propagate_family_plus_entitlement
  on public.family_entitlement;
create trigger trg_propagate_family_plus_entitlement
after insert or update on public.family_entitlement
for each row execute function public.propagate_family_plus_entitlement();

-- Contributor is a supported membership role in the app and migration 029,
-- so family invitations must accept it too.
alter table public.family_invite
  drop constraint if exists family_invite_role_check;
alter table public.family_invite
  add constraint family_invite_role_check
  check (role in ('adult','co_parent','contributor','teen','kid','viewer'));

create or replace function public.family_creation_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_owned integer;
  v_plus boolean;
begin
  if v_user is null then raise exception 'NOT_AUTHENTICATED'; end if;
  select count(*)::integer into v_owned
    from public.membership m
   where m.user_id = v_user and m.role = 'owner' and m.invite_status = 'active';
  select exists (
    select 1
      from public.membership m
      join public.family_entitlement e on e.space_id = m.space_id
    where m.user_id = v_user and m.role in ('owner','co_parent','adult')
      and m.invite_status = 'active'
       and e.status in ('active', 'gracePeriod', 'canceledActive')
       and (e.expires_at is null or e.expires_at > now())
  ) into v_plus;
  return jsonb_build_object(
    'owned_spaces', v_owned,
    'has_plus', v_plus,
    'can_create', v_plus or v_owned = 0
  );
end;
$$;
revoke all on function public.family_creation_status() from public, anon;
grant execute on function public.family_creation_status() to authenticated;

create or replace function public.create_additional_space(
  p_name text,
  p_household text,
  p_base_currency text,
  p_preferred_name text
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_space uuid;
  v_code text;
  v_list uuid;
  v_display_name text;
  v_owned integer;
  v_source_space uuid;
  v_source public.family_entitlement%rowtype;
  v_name text := btrim(coalesce(p_name, ''));
begin
  if v_user is null then raise exception 'NOT_AUTHENTICATED'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_user::text, 0));
  if length(v_name) not between 2 and 80 then
    raise exception 'INVALID_FAMILY_NAME';
  end if;
  if p_base_currency not in ('USD','EUR','GBP','ZAR','CAD','AUD','KES','NGN','INR','ZWG') then
    raise exception 'UNSUPPORTED_CURRENCY';
  end if;
  select count(*)::integer into v_owned
    from public.membership m
   where m.user_id = v_user and m.role = 'owner' and m.invite_status = 'active';
  select coalesce(grant_row.source_space_id, e.space_id) into v_source_space
    from public.membership m
    join public.family_entitlement e on e.space_id = m.space_id
    left join public.family_plus_space_grant grant_row on grant_row.space_id = e.space_id
   where m.user_id = v_user and m.role in ('owner','co_parent','adult')
     and m.invite_status = 'active'
     and e.status in ('active', 'gracePeriod', 'canceledActive')
     and (e.expires_at is null or e.expires_at > now())
   order by e.updated_at desc nulls last
   limit 1;
  if v_owned > 0 and v_source_space is null then
    raise exception 'FAMILY_LIMIT_REACHED';
  end if;
  if public.family_name_taken(v_name) then
    raise exception 'FAMILY_NAME_TAKEN';
  end if;

  v_display_name := coalesce(
    nullif(btrim(p_preferred_name), ''),
    nullif(split_part(coalesce((select email from auth.users where id = v_user), ''), '@', 1), ''),
    'Member'
  );
  insert into public.user_profile(id, name, email)
  values (v_user, v_display_name,
          coalesce((select email from auth.users where id = v_user), ''))
  on conflict (id) do update
    set name = coalesce(nullif(btrim(p_preferred_name), ''), public.user_profile.name);

  v_code := 'MHRI-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 4));
  insert into public.family_space(name, household_type, base_currency, settings)
  values (v_name, p_household, p_base_currency,
          jsonb_build_object('onboarding_stage', 'currencies'))
  returning id into v_space;
  insert into public.membership(space_id, user_id, role, sharing_level,
                               invite_status, invite_code, joined_at)
  values (v_space, v_user, 'owner', 'full', 'active', v_code, now());
  insert into public.shopping_list(space_id, name)
  values (v_space, 'Shopping') returning id into v_list;

  if v_source_space is not null then
    select * into v_source from public.family_entitlement
     where space_id = v_source_space;
    insert into public.family_plus_space_grant(space_id, source_space_id, created_by)
    values (v_space, v_source_space, v_user);
    insert into public.family_entitlement(
      space_id, status, features, product_id, store, expires_at, verified_at, updated_at
    ) values (
      v_space, v_source.status, v_source.features, v_source.product_id,
      v_source.store, v_source.expires_at, v_source.verified_at, now()
    );
  else
    insert into public.family_entitlement(space_id, status, features, updated_at)
    values (v_space, 'free', '[]'::jsonb, now());
  end if;

  insert into public.activity_log(space_id, actor_id, action, entity, entity_id, detail, hash)
  values (v_space, v_user, 'family.create', 'family_space', v_space,
          jsonb_build_object('name', v_name, 'base_currency', p_base_currency,
                             'additional_space', true),
          md5(v_space::text || ':create:' || clock_timestamp()));
  return jsonb_build_object('id', v_space, 'invite_code', v_code,
                            'default_list_id', v_list, 'existing', false);
end;
$$;
revoke all on function public.create_additional_space(text, text, text, text)
  from public, anon;
grant execute on function public.create_additional_space(text, text, text, text)
  to authenticated;

create or replace function public.create_invite(
  p_role text,
  p_email text,
  p_space_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_code text;
  v_id uuid;
  v_open integer;
  v_members integer;
  v_email text := lower(btrim(coalesce(p_email, '')));
begin
  if not public.is_family_admin(p_space_id) then raise exception 'ADMIN_REQUIRED'; end if;
  perform 1 from public.family_space where id = p_space_id for update;
  if p_role not in ('adult','co_parent','contributor','teen','kid','viewer') then
    raise exception 'BAD_ROLE';
  end if;
  if v_email <> '' and v_email !~* '^\S+@\S+\.\S+$' then raise exception 'BAD_EMAIL'; end if;
  select count(*)::integer into v_open from public.family_invite
   where space_id = p_space_id and revoked_at is null
     and accepted_at is null and expires_at > now();
  if v_open >= 5 then raise exception 'TOO_MANY_INVITES'; end if;
  if not exists (
    select 1 from public.family_entitlement e
     where e.space_id = p_space_id
       and e.status in ('active','gracePeriod','canceledActive')
       and (e.expires_at is null or e.expires_at > now())
  ) then
    select count(*)::integer into v_members from public.membership
     where space_id = p_space_id and invite_status = 'active';
    if v_members + v_open >= 5 then raise exception 'FAMILY_MEMBER_LIMIT_REACHED'; end if;
  end if;
  loop
    v_code := 'MHRI-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
    exit when not exists (select 1 from public.family_invite where code = v_code);
  end loop;
  insert into public.family_invite(space_id, code, role, email, created_by)
  values (p_space_id, v_code, p_role, nullif(v_email, ''), auth.uid())
  returning id into v_id;
  insert into public.activity_log(space_id, actor_id, action, entity, entity_id, detail, hash)
  values (p_space_id, auth.uid(), 'invite.create', 'family_invite', v_id,
          jsonb_build_object('role', p_role, 'email_bound', v_email <> ''),
          md5(v_id::text || ':invite:' || clock_timestamp()));
  return jsonb_build_object('id', v_id, 'code', v_code, 'role', p_role);
end;
$$;
revoke all on function public.create_invite(text, text, uuid) from public, anon;
grant execute on function public.create_invite(text, text, uuid) to authenticated;

-- Older clients call the family-unscoped overload. Keep it only when the
-- account has exactly one administrated family; never guess across spaces.
create or replace function public.create_invite(p_role text, p_email text default null)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_space uuid; v_admin_spaces integer;
begin
  select count(*)::integer into v_admin_spaces from public.membership
   where user_id = auth.uid() and invite_status = 'active'
     and role in ('owner','co_parent');
  if v_admin_spaces <> 1 then raise exception 'FAMILY_SCOPE_REQUIRED'; end if;
  select space_id into v_space from public.membership
   where user_id = auth.uid() and invite_status = 'active'
     and role in ('owner','co_parent') limit 1;
  return public.create_invite(p_role, p_email, v_space);
end;
$$;
revoke all on function public.create_invite(text, text) from public, anon;
grant execute on function public.create_invite(text, text) to authenticated;

create or replace function public.join_invite(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_rec public.family_invite%rowtype;
  v_email text;
  v_space uuid;
  v_active boolean;
  v_members integer;
begin
  if v_user is null then raise exception 'NOT_AUTHENTICATED'; end if;
  v_email := lower(coalesce((select email from auth.users where id = v_user), ''));
  select * into v_rec from public.family_invite
   where upper(trim(p_code)) = code for update;
  if not found or v_rec.revoked_at is not null or v_rec.accepted_at is not null
     or v_rec.expires_at <= now() then raise exception 'INVALID_CODE'; end if;
  if v_rec.email is not null and v_rec.email <> v_email then raise exception 'INVALID_CODE'; end if;
  v_space := v_rec.space_id;
  perform 1 from public.family_space where id = v_space for update;
  select exists (select 1 from public.membership
    where space_id = v_space and user_id = v_user and invite_status = 'active')
    into v_active;
  if not v_active and not exists (
    select 1 from public.family_entitlement e where e.space_id = v_space
      and e.status in ('active','gracePeriod','canceledActive')
      and (e.expires_at is null or e.expires_at > now())
  ) then
    select count(*)::integer into v_members from public.membership
     where space_id = v_space and invite_status = 'active';
    if v_members >= 5 then raise exception 'FAMILY_MEMBER_LIMIT_REACHED'; end if;
  end if;
  insert into public.user_profile(id, name, email)
  values (v_user,
          coalesce(nullif(split_part(coalesce((select email from auth.users where id = v_user), ''), '@', 1), ''), 'Member'),
          v_email)
  on conflict (id) do update set name = coalesce(public.user_profile.name, excluded.name);
  insert into public.membership(space_id, user_id, role, sharing_level, invite_status, joined_at)
  values (v_space, v_user, v_rec.role,
          case when v_rec.role in ('adult','co_parent') then 'full' else 'shared_only' end,
          'active', now())
  on conflict (space_id, user_id) do update
    set invite_status = 'active', joined_at = now(), role = excluded.role;
  update public.family_invite set accepted_by = v_user, accepted_at = now()
   where id = v_rec.id;
  insert into public.activity_log(space_id, actor_id, action, entity, entity_id, detail, hash)
  values (v_space, v_user, 'member.join_invite', 'family_invite', v_rec.id,
          jsonb_build_object('role', v_rec.role),
          md5(v_user::text || ':join_invite:' || clock_timestamp()));
  return v_space;
end;
$$;
revoke all on function public.join_invite(text) from public, anon;
grant execute on function public.join_invite(text) to authenticated;

create or replace function public.join_space(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_space uuid;
  v_members integer;
  v_active boolean;
  v_email text;
begin
  if v_user is null then raise exception 'NOT_AUTHENTICATED'; end if;
  select space_id into v_space from public.membership
   where invite_code = upper(trim(p_code)) and invite_status = 'active' limit 1;
  if v_space is null then raise exception 'INVALID_CODE'; end if;
  perform 1 from public.family_space where id = v_space for update;
  select exists (select 1 from public.membership
    where space_id = v_space and user_id = v_user and invite_status = 'active')
    into v_active;
  if not v_active and not exists (
    select 1 from public.family_entitlement e where e.space_id = v_space
      and e.status in ('active','gracePeriod','canceledActive')
      and (e.expires_at is null or e.expires_at > now())
  ) then
    select count(*)::integer into v_members from public.membership
     where space_id = v_space and invite_status = 'active';
    if v_members >= 5 then raise exception 'FAMILY_MEMBER_LIMIT_REACHED'; end if;
  end if;
  v_email := lower(coalesce((select email from auth.users where id = v_user), ''));
  insert into public.user_profile(id, name, email)
  values (v_user,
          coalesce(nullif(split_part(v_email, '@', 1), ''), 'Member'), v_email)
  on conflict (id) do update set name = coalesce(public.user_profile.name, excluded.name);
  insert into public.membership(space_id, user_id, role, sharing_level, invite_status, joined_at)
  values (v_space, v_user, 'adult', 'shared_only', 'active', now())
  on conflict (space_id, user_id) do update set invite_status = 'active', joined_at = now();
  insert into public.activity_log(space_id, actor_id, action, entity, entity_id, detail, hash)
  values (v_space, v_user, 'member.join', 'membership', v_user,
          jsonb_build_object('code', 'MHRI-' || right(upper(trim(p_code)), 4)),
          md5(v_user::text || ':join:' || clock_timestamp()));
  return v_space;
end;
$$;
revoke all on function public.join_space(text) from public, anon;
grant execute on function public.join_space(text) to authenticated;

create or replace function public.provision_family_member(
  p_space_id uuid,
  p_user_id uuid,
  p_actor_id uuid,
  p_role text
) returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_members integer; v_open integer;
begin
  if auth.role() <> 'service_role' then raise exception 'SERVICE_ROLE_REQUIRED'; end if;
  if p_role not in ('adult','co_parent','teen','kid','viewer') then raise exception 'BAD_ROLE'; end if;
  if not exists (select 1 from public.membership
    where space_id = p_space_id and user_id = p_actor_id and invite_status = 'active'
      and role in ('owner','co_parent')) then raise exception 'ADMIN_REQUIRED'; end if;
  perform 1 from public.family_space where id = p_space_id for update;
  if not exists (
    select 1 from public.family_entitlement e where e.space_id = p_space_id
      and e.status in ('active','gracePeriod','canceledActive')
      and (e.expires_at is null or e.expires_at > now())
  ) then
    select count(*)::integer into v_members from public.membership
     where space_id = p_space_id and invite_status = 'active';
    select count(*)::integer into v_open from public.family_invite
     where space_id = p_space_id and revoked_at is null
       and accepted_at is null and expires_at > now();
    if v_members + v_open >= 5 then raise exception 'FAMILY_MEMBER_LIMIT_REACHED'; end if;
  end if;
  insert into public.membership(space_id, user_id, role, sharing_level, invite_status, joined_at)
  values (p_space_id, p_user_id, p_role,
          case when p_role in ('adult','co_parent') then 'full' else 'shared_only' end,
          'active', now());
end;
$$;
revoke all on function public.provision_family_member(uuid, uuid, uuid, text)
  from public, anon, authenticated;
grant execute on function public.provision_family_member(uuid, uuid, uuid, text)
  to service_role;

-- Membership and invitation mutations must go through the capacity-checked
-- security-definer RPCs above.
drop policy if exists membership_manage on public.membership;
drop policy if exists membership_owner_update on public.membership;
drop policy if exists membership_owner_delete on public.membership;
revoke insert, update, delete on public.membership from anon, authenticated;
drop policy if exists invite_owner_write on public.family_invite;
revoke insert, update, delete on public.family_invite from anon, authenticated;

do $$
begin
  if to_regprocedure('public.create_additional_space(text,text,text,text)') is null
     or to_regprocedure('public.family_creation_status()') is null
     or to_regprocedure('public.provision_family_member(uuid,uuid,uuid,text)') is null then
    raise exception '057 SELF-TEST FAILED: family limit RPC missing';
  end if;
  if exists (select 1 from pg_policies where schemaname = 'public'
      and tablename = 'membership' and policyname = 'membership_manage') then
    raise exception '057 SELF-TEST FAILED: broad membership mutation policy remains';
  end if;
end;
$$;
