-- 013: CRUD lifecycle, family administration and provenance hardening.
-- Additive/idempotent. Financial records are archived or soft-deleted;
-- existing identifiers and relationships remain unchanged.

-- Do not allow this migration to leave a deceptively half-configured backend
-- when migrations are pasted manually into the SQL editor. family_invite and
-- its secure join/revoke RPCs are introduced by migration 010.
do $$
begin
  if to_regclass('public.family_invite') is null then
    raise exception using
      errcode = '42P01',
      message = 'PREREQUISITE_MISSING: run 010_invites_ownership.sql before 013_crud_ownership_permissions.sql';
  end if;
end;
$$;

-- Multiple family admins use the already-supported `co_parent` role.
create or replace function public.is_family_admin(s uuid) returns boolean
language sql security definer stable set search_path = public as $$
  select coalesce(public.space_role(s) in ('owner', 'co_parent'), false);
$$;
revoke all on function public.is_family_admin(uuid) from public, anon;
grant execute on function public.is_family_admin(uuid) to authenticated;

create or replace function public.is_adult(s uuid) returns boolean
language sql security definer stable set search_path = public as $$
  select coalesce(public.space_role(s) in ('owner','co_parent','adult'), false);
$$;

-- Audit/provenance and lifecycle columns. Defaults preserve existing rows.
alter table public.family_space add column if not exists updated_at timestamptz not null default now();
alter table public.envelope add column if not exists created_by uuid references public.user_profile(id);
alter table public.envelope add column if not exists archived_at timestamptz;
alter table public.envelope add column if not exists archived_by uuid references public.user_profile(id);
alter table public.transaction add column if not exists updated_by uuid references public.user_profile(id);
alter table public.goal add column if not exists created_by uuid references public.user_profile(id);
alter table public.goal add column if not exists archived_at timestamptz;
alter table public.goal add column if not exists archived_by uuid references public.user_profile(id);
alter table public.goal_tx add column if not exists updated_by uuid references public.user_profile(id);
alter table public.goal_tx add column if not exists deleted_at timestamptz;
alter table public.recurring_rule add column if not exists created_by uuid references public.user_profile(id);
alter table public.recurring_rule add column if not exists archived_at timestamptz;
alter table public.recurring_rule add column if not exists archived_by uuid references public.user_profile(id);
alter table public.chore add column if not exists is_archived boolean not null default false;
alter table public.chore add column if not exists archived_at timestamptz;
alter table public.chore add column if not exists archived_by uuid references public.user_profile(id);

drop trigger if exists trg_family_space_updated on public.family_space;
create trigger trg_family_space_updated before update on public.family_space
for each row execute function public.set_updated_at();

-- Family administration is online-only and atomic.
create or replace function public.update_family_name(p_name text) returns text
language plpgsql security definer set search_path = public as $$
declare v_space uuid; v_name text := btrim(coalesce(p_name, ''));
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  select space_id into v_space from public.membership
   where user_id = auth.uid() and invite_status = 'active'
     and role in ('owner', 'co_parent') limit 1;
  if v_space is null then raise exception 'ADMIN_REQUIRED'; end if;
  if length(v_name) < 2 or length(v_name) > 80 then raise exception 'INVALID_FAMILY_NAME'; end if;
  update public.family_space set name = v_name where id = v_space;
  insert into public.activity_log(space_id, actor_id, action, entity, entity_id, detail, hash)
  values(v_space, auth.uid(), 'family.rename', 'family_space', v_space,
    jsonb_build_object('name', v_name), md5(v_space::text || ':rename:' || clock_timestamp()));
  return v_name;
end; $$;
revoke all on function public.update_family_name(text) from public, anon;
grant execute on function public.update_family_name(text) to authenticated;

create or replace function public.change_member_role(p_member uuid, p_role text) returns void
language plpgsql security definer set search_path = public as $$
declare v_space uuid; v_old text; v_admins int;
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  select space_id into v_space from public.membership
   where user_id = auth.uid() and invite_status = 'active'
     and role in ('owner', 'co_parent') limit 1;
  if v_space is null then raise exception 'ADMIN_REQUIRED'; end if;
  if p_member = auth.uid() then raise exception 'CANNOT_CHANGE_OWN_ROLE'; end if;
  if p_role not in ('co_parent','adult','teen','kid','viewer') then raise exception 'BAD_ROLE'; end if;
  select role into v_old from public.membership
   where space_id = v_space and user_id = p_member and invite_status = 'active' for update;
  if v_old is null then raise exception 'MEMBER_NOT_FOUND'; end if;
  -- Admin promotion is intentionally adult-only.
  if p_role = 'co_parent' and v_old <> 'adult' then raise exception 'ADULT_REQUIRED'; end if;
  if v_old in ('owner','co_parent') and p_role not in ('owner','co_parent') then
    select count(*) into v_admins from public.membership
     where space_id = v_space and invite_status = 'active' and role in ('owner','co_parent');
    if v_admins <= 1 then raise exception 'LAST_ADMIN'; end if;
  end if;
  -- The founding owner remains owner unless ownership is explicitly transferred.
  if v_old = 'owner' then raise exception 'USE_OWNERSHIP_TRANSFER'; end if;
  update public.membership set role = p_role where space_id = v_space and user_id = p_member;
  insert into public.activity_log(space_id, actor_id, action, entity, entity_id, detail, hash)
  values(v_space, auth.uid(), 'member.role_change', 'membership', p_member,
    jsonb_build_object('from', v_old, 'to', p_role), md5(p_member::text || ':role:' || clock_timestamp()));
end; $$;
revoke all on function public.change_member_role(uuid,text) from public, anon;
grant execute on function public.change_member_role(uuid,text) to authenticated;

create or replace function public.remove_family_member(p_member uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_space uuid; v_role text; v_admins int;
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  select space_id into v_space from public.membership
   where user_id = auth.uid() and invite_status = 'active'
     and role in ('owner', 'co_parent') limit 1;
  if v_space is null then raise exception 'ADMIN_REQUIRED'; end if;
  if p_member = auth.uid() then raise exception 'CANNOT_REMOVE_SELF'; end if;
  select role into v_role from public.membership
   where space_id = v_space and user_id = p_member and invite_status = 'active' for update;
  if v_role is null then raise exception 'MEMBER_NOT_FOUND'; end if;
  if v_role in ('owner','co_parent') then
    select count(*) into v_admins from public.membership
     where space_id = v_space and invite_status = 'active' and role in ('owner','co_parent');
    if v_admins <= 1 then raise exception 'LAST_ADMIN'; end if;
  end if;
  update public.membership set invite_status = 'left' where space_id = v_space and user_id = p_member;
  insert into public.activity_log(space_id, actor_id, action, entity, entity_id, detail, hash)
  values(v_space, auth.uid(), 'member.remove', 'membership', p_member,
    jsonb_build_object('role', v_role), md5(p_member::text || ':remove:' || clock_timestamp()));
end; $$;
revoke all on function public.remove_family_member(uuid) from public, anon;
grant execute on function public.remove_family_member(uuid) to authenticated;

-- Replace broad membership mutation with read-only RLS; mutations use RPCs.
drop policy if exists membership_manage on public.membership;

-- Family rows: members read; admins alone may update. No client delete policy.
drop policy if exists space_update on public.family_space;
create policy space_update on public.family_space for update
  using (public.is_family_admin(id)) with check (public.is_family_admin(id));

-- Family admins share household-management responsibilities. Invitations
-- remain single-use and bounded by the safeguards in migration 010.
drop policy if exists invite_owner_read on public.family_invite;
create policy invite_owner_read on public.family_invite for select
  using (public.is_family_admin(space_id));
drop policy if exists invite_owner_write on public.family_invite;
create policy invite_owner_write on public.family_invite for all
  using (public.is_family_admin(space_id))
  with check (public.is_family_admin(space_id));

create or replace function public.create_invite(p_role text, p_email text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_user uuid := auth.uid(); v_space uuid; v_code text; v_id uuid; v_open int;
  v_email text := lower(btrim(coalesce(p_email, '')));
begin
  if v_user is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if p_role not in ('adult','co_parent','teen','kid','viewer') then raise exception 'BAD_ROLE'; end if;
  select space_id into v_space from public.membership
   where user_id = v_user and role in ('owner','co_parent') and invite_status = 'active' limit 1;
  if v_space is null then raise exception 'ADMIN_REQUIRED'; end if;
  select count(*) into v_open from public.family_invite
   where space_id = v_space and revoked_at is null and accepted_at is null and expires_at > now();
  if v_open >= 5 then raise exception 'TOO_MANY_INVITES'; end if;
  if v_email <> '' and v_email !~* '^\S+@\S+\.\S+$' then raise exception 'BAD_EMAIL'; end if;
  loop
    v_code := 'MHRI-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
    exit when not exists (select 1 from public.family_invite where code = v_code);
  end loop;
  insert into public.family_invite(space_id, code, role, email, created_by)
  values(v_space, v_code, p_role, nullif(v_email, ''), v_user) returning id into v_id;
  insert into public.activity_log(space_id, actor_id, action, entity, entity_id, detail, hash)
  values(v_space, v_user, 'invite.create', 'family_invite', v_id,
    jsonb_build_object('role', p_role, 'email_bound', v_email <> ''),
    md5(v_id::text || ':invite:' || clock_timestamp()));
  return jsonb_build_object('id', v_id, 'code', v_code, 'role', p_role);
end; $$;
revoke all on function public.create_invite(text,text) from public, anon;
grant execute on function public.create_invite(text,text) to authenticated;

create or replace function public.revoke_invite(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_space uuid;
begin
  if v_user is null then raise exception 'NOT_AUTHENTICATED'; end if;
  select space_id into v_space from public.family_invite
   where id = p_id and revoked_at is null and accepted_at is null for update;
  if v_space is null then raise exception 'INVALID_INVITE'; end if;
  if not public.is_family_admin(v_space) then raise exception 'ADMIN_REQUIRED'; end if;
  update public.family_invite set revoked_at = now() where id = p_id;
  insert into public.activity_log(space_id, actor_id, action, entity, entity_id, detail, hash)
  values(v_space, v_user, 'invite.revoke', 'family_invite', p_id, '{}'::jsonb,
    md5(p_id::text || ':revoke:' || clock_timestamp()));
end; $$;
revoke all on function public.revoke_invite(uuid) from public, anon;
grant execute on function public.revoke_invite(uuid) to authenticated;

create or replace function public.set_role_permissions(p_permissions jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare v_space uuid;
begin
  select space_id into v_space from public.membership
   where user_id = auth.uid() and role in ('owner','co_parent') and invite_status = 'active' limit 1;
  if v_space is null then raise exception 'ADMIN_REQUIRED'; end if;
  update public.family_space set settings = jsonb_set(
    coalesce(settings, '{}'::jsonb), '{role_permissions}', coalesce(p_permissions, '{}'::jsonb), true)
   where id = v_space;
end; $$;
revoke all on function public.set_role_permissions(jsonb) from public, anon;
grant execute on function public.set_role_permissions(jsonb) to authenticated;

-- A removed member must not retain roster/profile visibility through their
-- historical membership row. Historical rows stay for attribution only.
drop policy if exists profile_read on public.user_profile;
create policy profile_read on public.user_profile for select using (
  id = auth.uid() or exists (
    select 1 from public.membership me
    join public.membership other on other.space_id = me.space_id
      and other.user_id = user_profile.id and other.invite_status = 'active'
    where me.user_id = auth.uid() and me.invite_status = 'active'
  )
);

-- Provenance is server-authored and immutable. Admins may correct any family
-- transaction; other adults may correct only records they created.
create or replace function public.guard_transaction_provenance() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    new.created_by := auth.uid();
    new.updated_by := auth.uid();
  else
    new.space_id := old.space_id;
    new.created_by := old.created_by;
    new.updated_by := auth.uid();
  end if;
  return new;
end; $$;
drop trigger if exists trg_transaction_provenance on public.transaction;
create trigger trg_transaction_provenance before insert or update on public.transaction
for each row execute function public.guard_transaction_provenance();

create or replace function public.guard_shared_record_provenance() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then new.created_by := auth.uid();
  else new.created_by := old.created_by; end if;
  return new;
end; $$;
drop trigger if exists trg_envelope_provenance on public.envelope;
create trigger trg_envelope_provenance before insert or update on public.envelope
for each row execute function public.guard_shared_record_provenance();
drop trigger if exists trg_goal_provenance on public.goal;
create trigger trg_goal_provenance before insert or update on public.goal
for each row execute function public.guard_shared_record_provenance();
drop trigger if exists trg_recurring_provenance on public.recurring_rule;
create trigger trg_recurring_provenance before insert or update on public.recurring_rule
for each row execute function public.guard_shared_record_provenance();

drop policy if exists tx_write on public.transaction;
create policy tx_write on public.transaction for insert with check (
  public.is_adult(space_id)
  or (member_id = auth.uid() and public.space_role(space_id) = 'teen'
      and public.role_perm(space_id, 'teen_transactions', true))
  or (member_id = auth.uid() and public.space_role(space_id) = 'kid'
      and public.role_perm(space_id, 'child_transactions', false))
);
drop policy if exists tx_update on public.transaction;
create policy tx_update on public.transaction for update
  using (public.is_family_admin(space_id) or created_by = auth.uid())
  with check (public.is_family_admin(space_id) or created_by = auth.uid());

-- Shopping remains collaborative for adults, but children cannot mutate the
-- shared list through a forged REST request.
drop policy if exists list_write on public.shopping_list;
create policy list_write on public.shopping_list for all
  using (public.is_adult(space_id)) with check (public.is_adult(space_id));
drop policy if exists item_write on public.list_item;
create policy item_write on public.list_item for all
  using (exists(select 1 from public.shopping_list l where l.id = list_item.list_id and public.is_adult(l.space_id)))
  with check (exists(select 1 from public.shopping_list l where l.id = list_item.list_id and public.is_adult(l.space_id)));

-- Contributions are attributed by the server. Members can update/soft-delete
-- their own contribution; family admins may correct one while preserving its owner.
create or replace function public.guard_goal_tx_provenance() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then new.member_id := auth.uid();
  else new.member_id := old.member_id; new.goal_id := old.goal_id; new.updated_by := auth.uid(); end if;
  return new;
end; $$;
drop trigger if exists trg_goal_tx_provenance on public.goal_tx;
create trigger trg_goal_tx_provenance before insert or update on public.goal_tx
for each row execute function public.guard_goal_tx_provenance();
drop policy if exists gtx_write on public.goal_tx;
drop policy if exists gtx_insert on public.goal_tx;
drop policy if exists gtx_update on public.goal_tx;
create policy gtx_insert on public.goal_tx for insert with check (
  public.space_role((select g.space_id from public.goal g where g.id = goal_id)) is not null
  and member_id = auth.uid());
create policy gtx_update on public.goal_tx for update using (
  member_id = auth.uid() or public.is_family_admin((select g.space_id from public.goal g where g.id = goal_id)))
  with check (member_id = auth.uid() or public.is_family_admin((select g.space_id from public.goal g where g.id = goal_id)));

-- Prevent direct hard-deletion of financial lifecycle objects. Existing
-- UPDATE policies continue to support offline upserts and archive fields.
drop policy if exists envelope_write on public.envelope;
drop policy if exists envelope_insert on public.envelope;
drop policy if exists envelope_update on public.envelope;
create policy envelope_insert on public.envelope for insert with check (public.is_adult(space_id));
create policy envelope_update on public.envelope for update using (public.is_adult(space_id)) with check (public.is_adult(space_id));
drop policy if exists goal_write on public.goal;
drop policy if exists goal_insert on public.goal;
drop policy if exists goal_update on public.goal;
create policy goal_insert on public.goal for insert with check (public.is_adult(space_id));
create policy goal_update on public.goal for update using (public.is_adult(space_id)) with check (public.is_adult(space_id));
drop policy if exists recurring_write on public.recurring_rule;
drop policy if exists recurring_insert on public.recurring_rule;
drop policy if exists recurring_update on public.recurring_rule;
create policy recurring_insert on public.recurring_rule for insert with check (public.is_adult(space_id));
create policy recurring_update on public.recurring_rule for update using (public.is_adult(space_id)) with check (public.is_adult(space_id));

-- Admin-only archive transition for shared financial containers.
create or replace function public.guard_financial_archive() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null then
    if tg_table_name = 'envelope' and coalesce(old.is_archived,false) = false and coalesce(new.is_archived,false) = true
       and not public.is_family_admin(new.space_id) then raise exception 'ADMIN_REQUIRED'; end if;
    if tg_table_name = 'goal' and old.status <> 'archived' and new.status = 'archived'
       and not public.is_family_admin(new.space_id) then raise exception 'ADMIN_REQUIRED'; end if;
    if tg_table_name = 'recurring_rule' and old.archived_at is null and new.archived_at is not null
       and not public.is_family_admin(new.space_id) then raise exception 'ADMIN_REQUIRED'; end if;
  end if;
  return new;
end; $$;
drop trigger if exists trg_envelope_archive_guard on public.envelope;
create trigger trg_envelope_archive_guard before update on public.envelope for each row execute function public.guard_financial_archive();
drop trigger if exists trg_goal_archive_guard on public.goal;
create trigger trg_goal_archive_guard before update on public.goal for each row execute function public.guard_financial_archive();
drop trigger if exists trg_recurring_archive_guard on public.recurring_rule;
create trigger trg_recurring_archive_guard before update on public.recurring_rule for each row execute function public.guard_financial_archive();

-- Cross-family access remains governed by space_role/is_family_admin in every
-- policy above. No authenticated-global policy is introduced.
