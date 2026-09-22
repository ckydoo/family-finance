-- 004: RLS on live + human display names (2026-09-22)
-- Idempotent — safe to re-run. Run ONCE in the Supabase SQL editor.
--
-- Why: the app now pulls membership/user_profile (family roster, Sprint A)
-- and envelope_tx/rate_snapshot (Sprint B). Live DBs created from migration
-- 001 alone have NO row-level security on the synced tables — every pull
-- would return empty. This installs the same policy set as schema.sql,
-- guarded so re-running never duplicates.

-- ── helpers (idempotent: create or replace) ─────────────────────────────────
create or replace function space_role(s uuid) returns text
language sql security definer stable set search_path = public as $$
  select m.role from membership m
  where m.space_id = s
    and m.user_id = auth.uid()
    and m.invite_status = 'active'
  limit 1;
$$;

create or replace function is_adult(s uuid) returns boolean
language sql security definer stable set search_path = public as $$
  select coalesce(space_role(s) in ('owner','adult'), false);
$$;

do $$
declare t text;
begin
  foreach t in array array[
    'family_space','activity_log','user_profile','membership','account',
    'category','envelope','goal','goal_tx','mukando','mukando_member',
    'mukando_event','shopping_list','list_item','chore','chore_log',
    'transaction','envelope_tx','kid_request','earning','recurring_rule',
    'rate_snapshot'
  ] loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- ── policy installer: skips policies that already exist ────────────────────
-- Helper to add a policy only when missing.
create or replace function add_policy_if_missing(
  p_table text, p_name text, p_stmt text
) returns void language plpgsql as $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = p_table and policyname = p_name
  ) then
    execute p_stmt;
  end if;
end $$;

select add_policy_if_missing('family_space','space_read',
  'create policy space_read on public.family_space for select using (space_role(id) is not null)');
select add_policy_if_missing('user_profile','profile_read',
  'create policy profile_read on public.user_profile for select using (true)');
select add_policy_if_missing('user_profile','profile_self_write',
  'create policy profile_self_write on public.user_profile for update using (id = auth.uid())');
select add_policy_if_missing('membership','membership_read',
  'create policy membership_read on public.membership for select using (user_id = auth.uid() or space_role(space_id) is not null)');
select add_policy_if_missing('membership','membership_manage',
  'create policy membership_manage on public.membership for all using (space_role(space_id) = ''owner'') with check (space_role(space_id) = ''owner'')');

select add_policy_if_missing('account','account_read',
  'create policy account_read on public.account for select using (space_role(space_id) is not null)');
select add_policy_if_missing('category','category_read',
  'create policy category_read on public.category for select using (space_role(space_id) is not null)');
select add_policy_if_missing('envelope','envelope_read',
  'create policy envelope_read on public.envelope for select using (space_role(space_id) is not null)');
select add_policy_if_missing('envelope','envelope_write',
  'create policy envelope_write on public.envelope for all using (is_adult(space_id)) with check (is_adult(space_id))');
select add_policy_if_missing('goal','goal_read',
  'create policy goal_read on public.goal for select using (space_role(space_id) is not null)');
select add_policy_if_missing('goal','goal_write',
  'create policy goal_write on public.goal for all using (is_adult(space_id)) with check (is_adult(space_id))');
select add_policy_if_missing('mukando','mukando_read',
  'create policy mukando_read on public.mukando for select using (space_role(space_id) is not null)');
select add_policy_if_missing('mukando','mukando_write',
  'create policy mukando_write on public.mukando for all using (is_adult(space_id)) with check (is_adult(space_id))');
select add_policy_if_missing('list_item','item_read',
  'create policy item_read on public.list_item for select using (exists (select 1 from shopping_list l where l.id = list_item.list_id and space_role(l.space_id) is not null))');
select add_policy_if_missing('list_item','item_write',
  'create policy item_write on public.list_item for all using (exists (select 1 from shopping_list l where l.id = list_item.list_id and space_role(l.space_id) is not null)) with check (exists (select 1 from shopping_list l where l.id = list_item.list_id and space_role(l.space_id) is not null))');
select add_policy_if_missing('chore','chore_read',
  'create policy chore_read on public.chore for select using (space_role(space_id) is not null)');
select add_policy_if_missing('chore','chore_write',
  'create policy chore_write on public.chore for all using (is_adult(space_id)) with check (is_adult(space_id))');
select add_policy_if_missing('transaction','tx_read',
  'create policy tx_read on public.transaction for select using (is_adult(space_id) or (member_id = auth.uid() and space_role(space_id) is not null))');
select add_policy_if_missing('transaction','tx_write',
  'create policy tx_write on public.transaction for insert with check (is_adult(space_id) or (member_id = auth.uid() and space_role(space_id) in (''owner'',''adult'',''teen'')))');
select add_policy_if_missing('transaction','tx_update',
  'create policy tx_update on public.transaction for update using (is_adult(space_id) or created_by = auth.uid()) with check (is_adult(space_id) or created_by = auth.uid())');
select add_policy_if_missing('envelope_tx','etx_read',
  'create policy etx_read on public.envelope_tx for select using (space_role((select space_id from public.transaction t where t.id = envelope_tx.transaction_id)) is not null)');
select add_policy_if_missing('envelope_tx','etx_write',
  'create policy etx_write on public.envelope_tx for all using (is_adult((select space_id from public.transaction t where t.id = envelope_tx.transaction_id))) with check (is_adult((select space_id from public.transaction t where t.id = envelope_tx.transaction_id)))');
select add_policy_if_missing('goal_tx','gtx_read',
  'create policy gtx_read on public.goal_tx for select using (space_role((select space_id from public.goal g where g.id = goal_tx.goal_id)) is not null)');
select add_policy_if_missing('goal_tx','gtx_write',
  'create policy gtx_write on public.goal_tx for all using (space_role((select space_id from public.goal g where g.id = goal_tx.goal_id)) is not null) with check (member_id = auth.uid() or is_adult((select space_id from public.goal g where g.id = goal_tx.goal_id)))');
select add_policy_if_missing('kid_request','req_read',
  'create policy req_read on public.kid_request for select using (is_adult(space_id) or requester_id = auth.uid())');
select add_policy_if_missing('kid_request','req_insert',
  'create policy req_insert on public.kid_request for insert with check (requester_id = auth.uid() or is_adult(space_id))');
select add_policy_if_missing('kid_request','req_decide',
  'create policy req_decide on public.kid_request for update using (is_adult(space_id)) with check (is_adult(space_id))');
select add_policy_if_missing('earning','earning_read',
  'create policy earning_read on public.earning for select using (space_role(space_id) is not null)');
select add_policy_if_missing('earning','earning_write',
  'create policy earning_write on public.earning for all using (space_role(space_id) is not null) with check (member_id = auth.uid() or space_role(space_id) is not null)');
select add_policy_if_missing('recurring_rule','recurring_read',
  'create policy recurring_read on public.recurring_rule for select using (space_role(space_id) is not null)');
select add_policy_if_missing('recurring_rule','recurring_write',
  'create policy recurring_write on public.recurring_rule for all using (is_adult(space_id)) with check (is_adult(space_id))');
select add_policy_if_missing('rate_snapshot','rate_read',
  'create policy rate_read on public.rate_snapshot for select using (true)');

drop function if exists add_policy_if_missing(text,text,text);

-- ── human display names: email users were landing as 'Member' ──────────────
create or replace function create_space(p_name text, p_household text default 'couple_kids')
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_space uuid;
  v_user uuid := auth.uid();
  v_code text;
begin
  if v_user is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  insert into user_profile (id, name)
  values (v_user, coalesce(
    nullif(split_part(coalesce((select email from auth.users where id = v_user), ''),'@',1), ''),
    'Member'))
  on conflict (id) do nothing;

  v_code := 'MHRI-' || upper(substr(md5(random()::text), 1, 4));

  insert into family_space (name, household_type)
  values (p_name, p_household)
  returning id into v_space;

  insert into membership (space_id, user_id, role, sharing_level, invite_status, invite_code, joined_at)
  values (v_space, v_user, 'owner', 'full', 'active', v_code, now());

  return jsonb_build_object('id', v_space, 'invite_code', v_code);
end;
$$;

create or replace function join_space(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_space uuid;
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  insert into user_profile (id, name)
  values (v_user, coalesce(
    nullif(split_part(coalesce((select email from auth.users where id = v_user), ''),'@',1), ''),
    'Member'))
  on conflict (id) do nothing;

  select space_id into v_space
  from membership
  where invite_code = upper(trim(p_code))
    and invite_status = 'active'
  limit 1;

  if v_space is null then
    raise exception 'INVALID_CODE';
  end if;

  insert into membership (space_id, user_id, role, sharing_level, invite_status, joined_at)
  values (v_space, v_user, 'adult', 'shared_only', 'active', now())
  on conflict (space_id, user_id) do update
    set invite_status = 'active', joined_at = now();

  return v_space;
end;
$$;
