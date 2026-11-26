-- 076: Reconcile live database drift with repository migrations and fix
-- role/sync policy gaps so clean CI and live Supabase share an identical
-- catalog baseline.

-- ── 1. Private-account sync privacy policies (idempotent reconciliation) ───
drop policy if exists account_personal_privacy on public.account;
create policy account_personal_privacy on public.account
  as restrictive
  for select to public
  using (
    coalesce(sharing, 'shared') not in ('personal', 'private')
    or owner_member_id = (select auth.uid())
  );

drop policy if exists account_personal_write_privacy on public.account;
create policy account_personal_write_privacy on public.account
  as restrictive
  for all to public
  using (
    coalesce(sharing, 'shared') not in ('personal', 'private')
    or owner_member_id = (select auth.uid())
  )
  with check (
    coalesce(sharing, 'shared') not in ('personal', 'private')
    or owner_member_id = (select auth.uid())
  );

drop policy if exists tx_personal_account_privacy on public.transaction;
create policy tx_personal_account_privacy on public.transaction
  as restrictive
  for all to public
  using (
    account_id is null
    or exists (
      select 1
        from public.account a
       where a.id = transaction.account_id
         and a.space_id = transaction.space_id
         and (
           coalesce(a.sharing, 'shared') not in ('personal', 'private')
           or a.owner_member_id = (select auth.uid())
         )
    )
  )
  with check (
    account_id is null
    or exists (
      select 1
        from public.account a
       where a.id = transaction.account_id
         and a.space_id = transaction.space_id
         and (
           coalesce(a.sharing, 'shared') not in ('personal', 'private')
           or a.owner_member_id = (select auth.uid())
         )
    )
  );

-- ── 2. Supported 10-currency alignment across all financial tables ──────────
alter table public.account
  drop constraint if exists account_currency_check,
  add constraint account_currency_check
  check (currency in ('USD','ZWG','EUR','GBP','ZAR','CAD','AUD','KES','NGN','INR'));

alter table public.earning
  drop constraint if exists earning_currency_check,
  add constraint earning_currency_check
  check (currency in ('USD','ZWG','EUR','GBP','ZAR','CAD','AUD','KES','NGN','INR'));

alter table public.envelope_tx
  drop constraint if exists envelope_tx_currency_check,
  add constraint envelope_tx_currency_check
  check (currency in ('USD','ZWG','EUR','GBP','ZAR','CAD','AUD','KES','NGN','INR'));

alter table public.goal
  drop constraint if exists goal_target_currency_check,
  add constraint goal_target_currency_check
  check (target_currency in ('USD','ZWG','EUR','GBP','ZAR','CAD','AUD','KES','NGN','INR'));

alter table public.goal_tx
  drop constraint if exists goal_tx_currency_check,
  add constraint goal_tx_currency_check
  check (currency in ('USD','ZWG','EUR','GBP','ZAR','CAD','AUD','KES','NGN','INR'));

alter table public.kid_request
  drop constraint if exists kid_request_currency_check,
  add constraint kid_request_currency_check
  check (currency in ('USD','ZWG','EUR','GBP','ZAR','CAD','AUD','KES','NGN','INR'));

alter table public.list_item
  drop constraint if exists list_item_currency_check,
  add constraint list_item_currency_check
  check (currency in ('USD','ZWG','EUR','GBP','ZAR','CAD','AUD','KES','NGN','INR'));

alter table public.mukando
  drop constraint if exists mukando_currency_check,
  add constraint mukando_currency_check
  check (currency in ('USD','ZWG','EUR','GBP','ZAR','CAD','AUD','KES','NGN','INR'));

alter table public.mukando_payment
  drop constraint if exists mukando_payment_currency_check,
  add constraint mukando_payment_currency_check
  check (currency in ('USD','ZWG','EUR','GBP','ZAR','CAD','AUD','KES','NGN','INR'));

alter table public.recurring_rule
  drop constraint if exists recurring_rule_currency_check,
  add constraint recurring_rule_currency_check
  check (currency in ('USD','ZWG','EUR','GBP','ZAR','CAD','AUD','KES','NGN','INR'));

alter table public.transaction
  drop constraint if exists transaction_currency_check,
  add constraint transaction_currency_check
  check (currency in ('USD','ZWG','EUR','GBP','ZAR','CAD','AUD','KES','NGN','INR'));

-- ── 3. Family chat sender/author identity protection (sync_seq-aware) ──────
create or replace function public.enforce_family_chat_identity()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if auth.uid() is null or new.sender_id is distinct from auth.uid() then
      raise exception 'CHAT_SENDER_MISMATCH' using errcode = '42501';
    end if;
  else
    if new.sender_id is distinct from old.sender_id
       or new.space_id is distinct from old.space_id
       or new.id is distinct from old.id
       or new.is_system is distinct from old.is_system then
      raise exception 'CHAT_IDENTITY_IMMUTABLE' using errcode = '42501';
    end if;
    if auth.uid() is distinct from old.sender_id
       and (to_jsonb(new) - 'deleted' - 'updated_at' - 'sync_seq')
           is distinct from (to_jsonb(old) - 'deleted' - 'updated_at' - 'sync_seq') then
      raise exception 'CHAT_AUTHOR_REQUIRED' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_00_family_chat_identity on public.family_chat_message;
create trigger trg_00_family_chat_identity
before insert or update on public.family_chat_message
for each row execute function public.enforce_family_chat_identity();

create or replace function public.guard_family_chat_message()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  has_enhanced_chat boolean;
begin
  if tg_op = 'INSERT' then
    if auth.uid() is null then
      raise exception 'Authentication required';
    end if;
    new.sender_id := auth.uid();
  end if;

  select exists (
    select 1
      from public.family_entitlement e
     where e.space_id = new.space_id
       and e.status in ('active', 'gracePeriod', 'canceledActive')
       and (e.expires_at is null or e.expires_at > now())
       and e.features ? 'enhanced_family_chat'
  ) into has_enhanced_chat;

  if tg_op = 'INSERT' then
    if not has_enhanced_chat and (
      new.media_url is not null or new.media_type is not null or
      new.sticker is not null or new.reference_type is not null or
      new.reference_id is not null or new.reference_title is not null or
      new.reference_meta is not null
    ) then
      raise exception 'PLUS_FEATURE_REQUIRED';
    end if;
  elsif not has_enhanced_chat then
    if new.deleted is distinct from old.deleted then
      if old.deleted
         or not new.deleted
         or new.sender_id is distinct from auth.uid()
         or new.is_system
         or (to_jsonb(new) - 'deleted' - 'updated_at' - 'sync_seq')
            <> (to_jsonb(old) - 'deleted' - 'updated_at' - 'sync_seq') then
        raise exception 'NOT_AUTHORIZED';
      end if;
    elsif (
      new.text is distinct from old.text or
      new.edited_at is distinct from old.edited_at or
      new.media_url is distinct from old.media_url or
      new.media_type is distinct from old.media_type or
      new.sticker is distinct from old.sticker or
      new.reference_type is distinct from old.reference_type or
      new.reference_id is distinct from old.reference_id or
      new.reference_title is distinct from old.reference_title or
      new.reference_meta is distinct from old.reference_meta
    ) then
      raise exception 'PLUS_FEATURE_REQUIRED';
    end if;
  end if;

  new.updated_at := now();
  return new;
end;
$$;

-- ── 4. Multi-space & member capacity RPCs (057 parity on live DB) ──────────
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

drop trigger if exists trg_propagate_family_plus_entitlement on public.family_entitlement;
create trigger trg_propagate_family_plus_entitlement
after insert or update on public.family_entitlement
for each row execute function public.propagate_family_plus_entitlement();

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
  if v_admin_spaces <> 1 then
    if v_admin_spaces = 0 then raise exception 'ADMIN_REQUIRED'; end if;
    raise exception 'FAMILY_SCOPE_REQUIRED';
  end if;
  select space_id into v_space from public.membership
   where user_id = auth.uid() and invite_status = 'active'
     and role in ('owner','co_parent') limit 1;
  return public.create_invite(p_role, p_email, v_space);
end;
$$;
revoke all on function public.create_invite(text, text) from public, anon;
grant execute on function public.create_invite(text, text) to authenticated;

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
  if coalesce(nullif(current_setting('request.jwt.claim.role', true), ''), current_user) <> 'service_role' then
    raise exception 'SERVICE_ROLE_REQUIRED';
  end if;
  if p_role not in ('adult','co_parent','contributor','teen','kid','viewer') then
    raise exception 'BAD_ROLE';
  end if;
  if not exists (select 1 from public.membership
    where space_id = p_space_id and user_id = p_actor_id and invite_status = 'active'
      and role in ('owner','co_parent')) then
    raise exception 'ADMIN_REQUIRED';
  end if;
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
          coalesce(nullif(split_part(v_email, '@', 1), ''), 'Member'),
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

drop policy if exists membership_manage on public.membership;
drop policy if exists membership_owner_update on public.membership;
drop policy if exists membership_owner_delete on public.membership;
revoke insert, update, delete on public.membership from anon, authenticated;
drop policy if exists invite_owner_write on public.family_invite;
revoke insert, update, delete on public.family_invite from anon, authenticated;

-- ── 5. Fix kid_request insert RLS (Kids + Teen proposals + parent preview) ──
drop policy if exists req_insert on public.kid_request;
create policy req_insert on public.kid_request
  for insert to public
  with check (
    (
      requester_id = auth.uid()
      and public.space_role(space_id) = 'kid'
      and kind = 'money'
    )
    or (
      requester_id = auth.uid()
      and public.space_role(space_id) = 'teen'
      and kind = 'expense_proposal'
    )
    or (
      public.can_manage_finances(space_id)
      and state = 'pending'
      and kind = 'money'
      and exists (
        select 1
          from public.membership m
         where m.space_id = kid_request.space_id
           and m.user_id = kid_request.requester_id
           and m.role = 'kid'
           and m.invite_status = 'active'
      )
    )
  );

-- ── 6. Fix family_task RLS & kid submission guard (064 parity + sync_seq) ───
create or replace function public.guard_kid_task_submission()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.space_role(old.space_id) = 'kid' then
    if old.assignee_member_id is distinct from auth.uid()
       or new.assignee_member_id is distinct from auth.uid()
       or new.completed_by_member_id is distinct from auth.uid()
       or (old.requires_approval and new.status <> 'awaitingApproval')
       or (not old.requires_approval and new.status <> 'done')
       or (old.requires_approval and
           (new.approved_by_member_id is not null or new.approved_at is not null))
       or (not old.requires_approval and
           (new.approved_by_member_id is distinct from auth.uid()
            or new.approved_at is null))
       or old.status not in ('open', 'inProgress')
       or (to_jsonb(new) - 'status' - 'completed_at' - 'completed_by_member_id'
           - 'approved_by_member_id' - 'approved_at' - 'updated_at' - 'sync_seq')
          <> (to_jsonb(old) - 'status' - 'completed_at' - 'completed_by_member_id'
              - 'approved_by_member_id' - 'approved_at' - 'updated_at' - 'sync_seq') then
      raise exception 'Kids may only submit their assigned family tasks';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.guard_kid_task_submission() from public, anon, authenticated;

drop policy if exists family_task_read on public.family_task;
create policy family_task_read on public.family_task
  for select to public
  using (
    public.space_role(space_id) is not null
    and (
      public.space_role(space_id) <> 'kid'
      or assignee_member_id = auth.uid()
    )
  );

drop policy if exists family_task_update on public.family_task;
create policy family_task_update on public.family_task
  for update to public
  using (
    public.space_role(space_id) in ('owner', 'co_parent', 'adult', 'contributor', 'teen')
    or (public.space_role(space_id) = 'kid' and assignee_member_id = auth.uid())
  )
  with check (
    public.space_role(space_id) in ('owner', 'co_parent', 'adult', 'contributor', 'teen')
    or (
      public.space_role(space_id) = 'kid'
      and assignee_member_id = auth.uid()
      and completed_by_member_id = auth.uid()
      and (
        (requires_approval and status = 'awaitingApproval'
         and approved_by_member_id is null and approved_at is null)
        or (not requires_approval and status = 'done'
            and approved_by_member_id = auth.uid() and approved_at is not null)
      )
    )
  );

-- ── 7. Audit no-op guards & state-transition detail (072 + sync_seq) ────────
create or replace function public.audit_shopping_item()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_space uuid;
  v_actor uuid;
  v_detail jsonb;
begin
  if tg_op = 'UPDATE'
     and (to_jsonb(new) - 'updated_at' - 'sync_seq')
         = (to_jsonb(old) - 'updated_at' - 'sync_seq') then
    return new;
  end if;

  select space_id into v_space
    from public.shopping_list
   where id = new.list_id;
  v_actor := coalesce(auth.uid(), new.added_by);
  if v_space is null or v_actor is null then return new; end if;

  v_detail := jsonb_build_object(
    'name', new.name,
    'qty', new.qty,
    'old_state', case when tg_op = 'UPDATE' then old.state end,
    'new_state', new.state,
    'old_checked_out', case when tg_op = 'UPDATE' then old.checked_out end,
    'new_checked_out', new.checked_out
  );
  insert into public.activity_log(
    space_id, actor_id, action, entity, entity_id, detail, hash)
  values (
    v_space,
    v_actor,
    case when tg_op = 'INSERT' then 'shopping.item_add'
         when new.state = 'done' and old.state <> 'done' then 'shopping.item_done'
         else 'shopping.item_update' end,
    'list_item', new.id, v_detail,
    md5(new.id::text || ':shopping:' || clock_timestamp())
  );
  return new;
end;
$$;
revoke all on function public.audit_shopping_item() from public, anon, authenticated;

create or replace function public.audit_shared_family_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  row_data jsonb := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
  old_data jsonb := case when tg_op = 'UPDATE' then to_jsonb(old) else '{}'::jsonb end;
  v_space uuid;
  v_actor uuid;
  v_id uuid;
  v_action text;
  v_detail jsonb;
begin
  if tg_op = 'UPDATE'
     and (row_data - 'updated_at' - 'sync_seq')
         = (old_data - 'updated_at' - 'sync_seq') then
    return new;
  end if;

  v_space := nullif(row_data->>'space_id', '')::uuid;
  v_actor := coalesce(
    auth.uid(),
    nullif(row_data->>'created_by', '')::uuid,
    nullif(row_data->>'sender_id', '')::uuid,
    nullif(row_data->>'member_id', '')::uuid,
    nullif(row_data->>'added_by', '')::uuid
  );
  v_id := nullif(row_data->>'id', '')::uuid;
  if v_space is null or v_actor is null or v_id is null
     or not exists (select 1 from public.family_space where id = v_space) then
    if tg_op = 'DELETE' then return old; else return new; end if;
  end if;

  v_action := case
    when tg_table_name = 'family_chat_message' and tg_op = 'INSERT' then 'chat.send'
    when tg_table_name = 'family_chat_message'
      and coalesce((row_data->>'deleted')::boolean, false)
      and not coalesce((old_data->>'deleted')::boolean, false) then 'chat.delete'
    when tg_table_name = 'family_chat_message' then 'chat.update'
    when tg_table_name = 'family_task' and tg_op = 'INSERT' then 'task.create'
    when tg_table_name = 'family_task'
      and coalesce((row_data->>'is_archived')::boolean, false)
      and not coalesce((old_data->>'is_archived')::boolean, false) then 'task.archive'
    when tg_table_name = 'family_task'
      and row_data->>'status' = 'done'
      and old_data->>'status' is distinct from 'done' then 'task.complete'
    when tg_table_name = 'family_task' then 'task.update'
    when tg_table_name = 'shopping_list' and tg_op = 'INSERT' then 'shopping.list_create'
    when tg_table_name = 'shopping_list' and row_data->>'deleted_at' is not null
      and old_data->>'deleted_at' is null then 'shopping.list_delete'
    when tg_table_name = 'shopping_list' then 'shopping.list_update'
    when tg_op = 'INSERT' then tg_table_name || '.create'
    when tg_op = 'DELETE' then tg_table_name || '.delete'
    else tg_table_name || '.update'
  end;

  v_detail := jsonb_strip_nulls(jsonb_build_object(
    'name', row_data->>'name',
    'title', row_data->>'title',
    'status', row_data->>'status',
    'state', row_data->>'state',
    'member_id', row_data->>'member_id',
    'assignee_member_id', row_data->>'assignee_member_id'
  ));
  insert into public.activity_log
    (space_id, actor_id, action, entity, entity_id, detail, hash)
  values
    (v_space, v_actor, v_action, tg_table_name, v_id, v_detail,
     md5(v_id::text || ':' || v_action || ':' || clock_timestamp()));
  if tg_op = 'DELETE' then return old; else return new; end if;
end;
$$;
revoke all on function public.audit_shared_family_change() from public, anon, authenticated;

-- ── 8. Retire legacy single-list hotfix & duplicate webhook trigger ─────────
drop trigger if exists trg_chikangaiso_completed_items on public.list_item;
drop function if exists public.guard_chikangaiso_completed_items();

drop trigger if exists "important-family-push" on public.activity_log;
