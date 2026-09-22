-- 011: ROLE ENFORCEMENT (RLS becomes the boundary) + AUDIT COMPLETION.
--
-- The onboarding permission switches (stored in family_space.settings ->
-- 'role_permissions' by set_role_permissions) are now REAL: RLS consults
-- them at query time through role_perm(). Before this migration, the
-- switches were cosmetic — tx_write allowed teens always and kids never,
-- no matter what the owner chose.
--
-- Defaults mirror the onboarding map exactly:
--   child_transactions: FALSE   teen_transactions: TRUE
--   child_budget:       TRUE    teen_budget:       TRUE
--   child_wallet:       TRUE    teen_wallet:       TRUE
-- (an absent key behaves exactly like the switch's default position, so
-- existing families see no change until the owner flips a switch).
--
-- AUDIT COMPLETION (#9): trigger-written activity_log rows for money moves
-- and request decisions — 'tx.create', 'goal.contribute', 'request.approve',
-- 'request.decline'. Rows are APPENDED; the hash columns stay placeholders
-- (no tamper-evidence claim until real chaining ships).

-- ── 1. the permission helper ────────────────────────────────────────────────
create or replace function public.role_perm(
  p_space uuid,
  p_key text,
  p_default boolean
) returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    nullif(
      family_space.settings -> 'role_permissions' ->> p_key, ''),
    p_default::text)::boolean
  from family_space
  where id = p_space
  limit 1;
$$;

revoke all on function public.role_perm(uuid, text, boolean) from public, anon;
grant execute on function public.role_perm(uuid, text, boolean) to authenticated;

-- ── 2. transaction writes honour the switches ───────────────────────────────
drop policy if exists tx_write on public.transaction;
create policy tx_write on public.transaction
  for insert
  with check (
    is_adult(space_id)
    or (
      member_id = auth.uid()
      and space_role(space_id) in ('owner', 'adult')
    )
    or (
      member_id = auth.uid()
      and space_role(space_id) = 'teen'
      and role_perm(space_id, 'teen_transactions', true)
    )
    or (
      member_id = auth.uid()
      and space_role(space_id) = 'kid'
      and role_perm(space_id, 'child_transactions', false)
    )
  );

drop policy if exists tx_update on public.transaction;
create policy tx_update on public.transaction
  for update
  using (
    is_adult(space_id)
    or (
      created_by = auth.uid()
      and (
        space_role(space_id) in ('owner', 'adult')
        or (
          space_role(space_id) = 'teen'
          and role_perm(space_id, 'teen_transactions', true)
        )
        or (
          space_role(space_id) = 'kid'
          and role_perm(space_id, 'child_transactions', false)
        )
      )
    )
  )
  with check (
    is_adult(space_id)
    or (
      created_by = auth.uid()
      and (
        space_role(space_id) in ('owner', 'adult')
        or (
          space_role(space_id) = 'teen'
          and role_perm(space_id, 'teen_transactions', true)
        )
        or (
          space_role(space_id) = 'kid'
          and role_perm(space_id, 'child_transactions', false)
        )
      )
    )
  );

-- ── 3. budget/wallet visibility honour the switches ─────────────────────────
drop policy if exists envelope_read on public.envelope;
create policy envelope_read on public.envelope
  for select
  using (
    is_adult(space_id)
    or (
      space_role(space_id) is not null
      and (
        space_role(space_id) not in ('kid', 'teen')
        or (space_role(space_id) = 'kid'
            and role_perm(space_id, 'child_budget', true))
        or (space_role(space_id) = 'teen'
            and role_perm(space_id, 'teen_budget', true))
      )
    )
  );

drop policy if exists account_read on public.account;
create policy account_read on public.account
  for select
  using (
    is_adult(space_id)
    or (
      space_role(space_id) is not null
      and (
        space_role(space_id) not in ('kid', 'teen')
        or (space_role(space_id) = 'kid'
            and role_perm(space_id, 'child_wallet', true))
        or (space_role(space_id) = 'teen'
            and role_perm(space_id, 'teen_wallet', true))
      )
    )
  );

-- ── 4. audit triggers ───────────────────────────────────────────────────────
create or replace function public.audit_tx_create()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into activity_log (space_id, actor_id, action, entity, entity_id, detail, hash)
  values (
    new.space_id,
    coalesce(new.created_by, auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid),
    'tx.create', 'transaction', new.id,
    jsonb_build_object('amount_minor', new.amount_minor,
                       'currency', new.currency,
                       'member_id', new.member_id),
    md5(new.id::text || ':tx:' || clock_timestamp())
  );
  return new;
end;
$$;

drop trigger if exists trg_audit_tx on public.transaction;
create trigger trg_audit_tx
  after insert on public.transaction
  for each row execute function public.audit_tx_create();

create or replace function public.audit_goal_contribute()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare v_space uuid;
begin
  select space_id into v_space from goal where id = new.goal_id;
  if v_space is null then return new; end if;
  insert into activity_log (space_id, actor_id, action, entity, entity_id, detail, hash)
  values (
    v_space,
    coalesce(new.member_id, auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid),
    'goal.contribute', 'goal_tx', new.id,
    jsonb_build_object('amount_minor', new.amount_minor,
                       'currency', new.currency,
                       'goal_id', new.goal_id),
    md5(new.id::text || ':goal_tx:' || clock_timestamp())
  );
  return new;
end;
$$;

drop trigger if exists trg_audit_goal_tx on public.goal_tx;
create trigger trg_audit_goal_tx
  after insert on public.goal_tx
  for each row execute function public.audit_goal_contribute();

create or replace function public.audit_request_decision()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.state = old.state or new.state not in ('approved', 'declined') then
    return new;
  end if;
  insert into activity_log (space_id, actor_id, action, entity, entity_id, detail, hash)
  values (
    new.space_id,
    coalesce(new.decided_by, auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid),
    'request.' || case new.state when 'approved' then 'approve' else 'decline' end,
    'kid_request', new.id,
    jsonb_build_object('amount_minor', new.amount_minor,
                       'currency', new.currency,
                       'requester_id', new.requester_id,
                       'kind', new.kind),
    md5(new.id::text || ':' || new.state || ':' || clock_timestamp())
  );
  return new;
end;
$$;

drop trigger if exists trg_audit_request on public.kid_request;
create trigger trg_audit_request
  after update on public.kid_request
  for each row execute function public.audit_request_decision();

-- ── self-test ───────────────────────────────────────────────────────────────
do $$
declare n int;
begin
  select count(*) into n from pg_proc p
    join pg_namespace ns on ns.oid = p.pronamespace
   where ns.nspname = 'public' and p.proname = 'role_perm';
  if n <> 1 then raise exception '011 SELF-TEST FAILED: role_perm missing'; end if;
  select count(*) into n from pg_trigger
   where tgrelid in ('public.transaction'::regclass,
                     'public.goal_tx'::regclass,
                     'public.kid_request'::regclass)
     and tgisinternal = false
     and tgname like 'trg_audit%';
  if n <> 3 then raise exception '011 SELF-TEST FAILED: audit triggers missing'; end if;
end $$;
