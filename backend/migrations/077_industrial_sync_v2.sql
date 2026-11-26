-- 077: Industrial Sync Engine v2
--
-- Introduces:
-- 1. Global monotonic change sequence (`public.sync_seq_seq`) and `sync_seq` +
--    `updated_at` across all 31 synced/member family tables with keyset indexes.
-- 2. Partial unique index on `mukando_payment (space_id, round_no, member_id)
--    WHERE deleted_at IS NULL`, single-envelope-per-tx index on `envelope_tx`,
--    idempotent retry UPDATE policies for append-only payment tables, and
--    historical-item-safe `guard_bulk_shopping_regression()`.
-- 3. Per-space Realtime signal table (`public.family_sync_signal`) +
--    idempotency ledger (`public.sync_applied_op`) + cascade-safe triggers
--    (`trg_zz_sync_metadata`, `trg_zz_sync_signal`, `trg_zz_envelope_tx_delete`).
-- 4. Canonical type-normalized field-level 3-way merge (`_compute_merged_sync_jsonb`),
--    upgraded `merge_sync_row`, natural-key-adopting `apply_sync_mutation`,
--    savepoint-isolated batch `push_sync_ops(jsonb)`, and FK-ordered keyset
--    paginated `pull_family_changes(uuid, jsonb, integer)`.

-- ── 1. Sequence & missing metadata/tombstone columns ────────────────────────
create sequence if not exists public.sync_seq_seq
  as bigint
  start with 1
  increment by 1
  cache 64;

grant usage, select on sequence public.sync_seq_seq to authenticated, service_role;

alter table public.envelope_tx
  add column if not exists updated_at timestamptz not null default now();

alter table public.commitment_payment
  add column if not exists updated_at timestamptz;
update public.commitment_payment
   set updated_at = coalesce(updated_at, created_at, now())
 where updated_at is null;
alter table public.commitment_payment
  alter column updated_at set default now(),
  alter column updated_at set not null;

alter table public.membership
  add column if not exists updated_at timestamptz;
update public.membership
   set updated_at = coalesce(updated_at, joined_at, now())
 where updated_at is null;
alter table public.membership
  alter column updated_at set default now(),
  alter column updated_at set not null;

alter table public.user_profile
  add column if not exists updated_at timestamptz;
update public.user_profile
   set updated_at = coalesce(updated_at, created_at, now())
 where updated_at is null;
alter table public.user_profile
  alter column updated_at set default now(),
  alter column updated_at set not null;

alter table public.mukando_payment
  add column if not exists deleted_at timestamptz;

alter table public.mukando_payment
  drop constraint if exists mukando_payment_space_id_round_no_member_id_key;
drop index if exists public.mukando_payment_space_id_round_no_member_id_key;

create unique index if not exists mukando_payment_active_round_member_uidx
  on public.mukando_payment (space_id, round_no, member_id)
  where deleted_at is null;

-- Deduplicate any hypothetical legacy multi-envelope links before enforcing 1:1
delete from public.envelope_tx a
 using public.envelope_tx b
 where a.transaction_id = b.transaction_id
   and a.ctid < b.ctid;

create unique index if not exists envelope_tx_transaction_id_uidx
  on public.envelope_tx (transaction_id);

-- Idempotent retry & own-payment unrecord RLS alignment
drop policy if exists contribution_payment_update on public.contribution_payment;
create policy contribution_payment_update on public.contribution_payment
  for update to public
  using (
    exists (
      select 1
        from public.contribution_campaign c
       where c.id = contribution_payment.campaign_id
         and (
           public.can_manage_finances(c.space_id)
           or (
             contribution_payment.member_id = (select auth.uid())
             and public.space_role(c.space_id) <> 'viewer'
           )
         )
    )
  )
  with check (
    exists (
      select 1
        from public.contribution_campaign c
       where c.id = contribution_payment.campaign_id
         and (
           public.can_manage_finances(c.space_id)
           or (
             contribution_payment.member_id = (select auth.uid())
             and public.space_role(c.space_id) <> 'viewer'
           )
         )
    )
  );

drop policy if exists debt_repayment_update on public.debt_repayment;
create policy debt_repayment_update on public.debt_repayment
  for update to public
  using (
    exists (
      select 1
        from public.family_debt d
       where d.id = debt_repayment.debt_id
         and public.is_adult(d.space_id)
    )
  )
  with check (
    exists (
      select 1
        from public.family_debt d
       where d.id = debt_repayment.debt_id
         and public.is_adult(d.space_id)
    )
  );

drop policy if exists mukando_payment_update on public.mukando_payment;
create policy mukando_payment_update on public.mukando_payment
  for update to public
  using (
    public.can_manage_finances(space_id)
    or (
      member_id = (select auth.uid())
      and recorded_by = (select auth.uid())
    )
  )
  with check (
    public.can_manage_finances(space_id)
    or (
      member_id = (select auth.uid())
      and recorded_by = (select auth.uid())
    )
  );

-- ── 2. Shopping regression guard (historical-item safe) & tx audit no-op ───
create or replace function public.guard_bulk_shopping_regression()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_regressions integer;
begin
  select count(*)
    into v_regressions
    from old_rows old_row
    join new_rows new_row using (id)
   where old_row.deleted_at is null
     and new_row.deleted_at is null
     and old_row.state = 'done'
     and new_row.state = 'tobuy'
     and not (
       new_row.checked_out = false
       and new_row.actual_price_minor is null
       and new_row.purchased_by is null
       and new_row.settled_tx_id is null
       and new_row.replanned_at is not null
       and (
         old_row.replanned_at is null
         or new_row.replanned_at > old_row.replanned_at
       )
     );

  if v_regressions > 0 then
    raise exception using
      errcode = '40001',
      message = 'STALE_SHOPPING_ITEM_REOPEN_REJECTED',
      detail = format(
        'Rejected %s completed shopping items regressing to to-buy without an explicit re-plan.',
        v_regressions
      ),
      hint = 'Use "Put on list for next time" or "Undo purchase" to re-open a completed item deliberately.';
  end if;
  return null;
end;
$$;
revoke all on function public.guard_bulk_shopping_regression()
  from public, anon, authenticated;

create or replace function public.audit_transaction_changes()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  action_name text;
  account_sharing text;
begin
  if tg_op = 'UPDATE'
     and (to_jsonb(new) - 'updated_at' - 'sync_seq')
         = (to_jsonb(old) - 'updated_at' - 'sync_seq') then
    return new;
  end if;

  if tg_op = 'UPDATE' and old.account_id is not null then
    select coalesce(a.sharing, 'shared') into account_sharing
      from public.account a where a.id = old.account_id;
    if account_sharing in ('private', 'personal') then
      return new;
    end if;
    account_sharing := null;
  end if;
  if new.account_id is not null then
    select coalesce(a.sharing, 'shared') into account_sharing
      from public.account a where a.id = new.account_id;
    if account_sharing in ('private', 'personal') then
      return new;
    end if;
  end if;

  if tg_op = 'INSERT' then
    action_name := 'tx.create';
  elsif new.deleted_at is not null and old.deleted_at is null then
    action_name := 'tx.delete';
  elsif new is distinct from old then
    action_name := 'tx.update';
  else
    return new;
  end if;

  insert into public.activity_log
    (space_id, actor_id, action, entity, entity_id, detail, hash)
  values (
    new.space_id,
    coalesce(auth.uid(), new.updated_by, new.created_by),
    action_name,
    'transaction',
    new.id,
    jsonb_build_object(
      'amount_minor', new.amount_minor,
      'currency', new.currency,
      'member_id', new.member_id
    ),
    md5(new.id::text || ':' || action_name || ':' || clock_timestamp())
  );
  return new;
end;
$$;
revoke all on function public.audit_transaction_changes()
  from public, anon, authenticated;

-- ── 3. Add sync_seq across all 31 synced/member tables & backfill ───────────
do $$
declare
  v_tbl text;
  v_tables text[] := array[
    'family_space',
    'membership',
    'user_profile',
    'account',
    'envelope',
    'envelope_tx',
    'budget_cycle_plan',
    'goal',
    'goal_tx',
    'shopping_list',
    'list_item',
    'transaction',
    'transaction_split',
    'kid_request',
    'earning',
    'recurring_rule',
    'chore',
    'mukando',
    'mukando_payment',
    'activity_log',
    'family_chat_message',
    'family_task',
    'family_reward',
    'financial_commitment',
    'commitment_occurrence',
    'commitment_payment',
    'contribution_campaign',
    'contribution_pledge',
    'contribution_payment',
    'family_debt',
    'debt_repayment'
  ];
begin
  foreach v_tbl in array v_tables loop
    execute format(
      'alter table public.%I add column if not exists sync_seq bigint',
      v_tbl
    );
    execute format(
      'update public.%I set sync_seq = nextval(''public.sync_seq_seq'') where sync_seq is null',
      v_tbl
    );
    execute format(
      'alter table public.%I
         alter column sync_seq set default nextval(''public.sync_seq_seq''),
         alter column sync_seq set not null',
      v_tbl
    );
  end loop;
end;
$$;

-- Keyset pagination indexes
create index if not exists family_space_sync_seq_idx on public.family_space (id, sync_seq);
create index if not exists membership_space_sync_seq_idx on public.membership (space_id, sync_seq);
create index if not exists user_profile_sync_seq_idx on public.user_profile (id, sync_seq);
create index if not exists account_space_sync_seq_idx on public.account (space_id, sync_seq);
create index if not exists envelope_space_sync_seq_idx on public.envelope (space_id, sync_seq);
create index if not exists envelope_tx_env_sync_seq_idx on public.envelope_tx (envelope_id, sync_seq);
create index if not exists envelope_tx_tx_sync_seq_idx on public.envelope_tx (transaction_id, sync_seq);
create index if not exists budget_cycle_plan_space_sync_seq_idx on public.budget_cycle_plan (space_id, sync_seq);
create index if not exists goal_space_sync_seq_idx on public.goal (space_id, sync_seq);
create index if not exists goal_tx_goal_sync_seq_idx on public.goal_tx (goal_id, sync_seq);
create index if not exists shopping_list_space_sync_seq_idx on public.shopping_list (space_id, sync_seq);
create index if not exists list_item_list_sync_seq_idx on public.list_item (list_id, sync_seq);
create index if not exists transaction_space_sync_seq_idx on public.transaction (space_id, sync_seq);
create index if not exists transaction_split_space_sync_seq_idx on public.transaction_split (space_id, sync_seq);
create index if not exists kid_request_space_sync_seq_idx on public.kid_request (space_id, sync_seq);
create index if not exists earning_space_sync_seq_idx on public.earning (space_id, sync_seq);
create index if not exists recurring_rule_space_sync_seq_idx on public.recurring_rule (space_id, sync_seq);
create index if not exists chore_space_sync_seq_idx on public.chore (space_id, sync_seq);
create index if not exists mukando_space_sync_seq_idx on public.mukando (space_id, sync_seq);
create index if not exists mukando_payment_space_sync_seq_idx on public.mukando_payment (space_id, sync_seq);
create index if not exists activity_log_space_sync_seq_idx on public.activity_log (space_id, sync_seq);
create index if not exists family_chat_message_space_sync_seq_idx on public.family_chat_message (space_id, sync_seq);
create index if not exists family_task_space_sync_seq_idx on public.family_task (space_id, sync_seq);
create index if not exists family_reward_space_sync_seq_idx on public.family_reward (space_id, sync_seq);
create index if not exists financial_commitment_space_sync_seq_idx on public.financial_commitment (space_id, sync_seq);
create index if not exists commitment_occurrence_comm_sync_seq_idx on public.commitment_occurrence (commitment_id, sync_seq);
create index if not exists commitment_payment_occ_sync_seq_idx on public.commitment_payment (occurrence_id, sync_seq);
create index if not exists contribution_campaign_space_sync_seq_idx on public.contribution_campaign (space_id, sync_seq);
create index if not exists contribution_pledge_camp_sync_seq_idx on public.contribution_pledge (campaign_id, sync_seq);
create index if not exists contribution_payment_camp_sync_seq_idx on public.contribution_payment (campaign_id, sync_seq);
create index if not exists family_debt_space_sync_seq_idx on public.family_debt (space_id, sync_seq);
create index if not exists debt_repayment_debt_sync_seq_idx on public.debt_repayment (debt_id, sync_seq);

-- ── 4. Realtime signal table & idempotency ledger ───────────────────────────
create table if not exists public.family_sync_signal (
  space_id uuid primary key references public.family_space(id) on delete cascade,
  latest_seq bigint not null default 0,
  last_entity text not null default '',
  updated_at timestamptz not null default now()
);

alter table public.family_sync_signal enable row level security;
revoke all on public.family_sync_signal from public, anon, authenticated;
grant select on public.family_sync_signal to authenticated;
grant all on public.family_sync_signal to service_role;

drop policy if exists family_sync_signal_read on public.family_sync_signal;
create policy family_sync_signal_read on public.family_sync_signal
  for select to authenticated
  using (public.space_role(space_id) is not null);

-- Seed signal rows for all existing spaces
insert into public.family_sync_signal (space_id, latest_seq, last_entity, updated_at)
select s.id, s.sync_seq, 'family_space', now()
  from public.family_space s
on conflict (space_id) do nothing;

-- Publish family_sync_signal to Supabase Realtime when publication exists
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1
         from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = 'family_sync_signal'
     ) then
    execute 'alter publication supabase_realtime add table public.family_sync_signal';
  end if;
end;
$$;

create table if not exists public.sync_applied_op (
  op_id text primary key,
  space_id uuid not null references public.family_space(id) on delete cascade,
  actor_id uuid not null,
  entity text not null,
  row_id text not null,
  applied_seq bigint not null,
  outcome text not null,
  result_row jsonb,
  applied_at timestamptz not null default now()
);

create index if not exists sync_applied_op_space_applied_idx
  on public.sync_applied_op (space_id, applied_at desc);

alter table public.sync_applied_op enable row level security;
revoke all on public.sync_applied_op from public, anon, authenticated;
grant select, insert, delete on public.sync_applied_op to authenticated;
grant all on public.sync_applied_op to service_role;

drop policy if exists sync_applied_op_read on public.sync_applied_op;
create policy sync_applied_op_read on public.sync_applied_op
  for select to authenticated
  using (
    actor_id = (select auth.uid())
    and public.space_role(space_id) is not null
  );

drop policy if exists sync_applied_op_insert on public.sync_applied_op;
create policy sync_applied_op_insert on public.sync_applied_op
  for insert to authenticated
  with check (
    actor_id = (select auth.uid())
    and public.space_role(space_id) is not null
  );

drop policy if exists sync_applied_op_delete on public.sync_applied_op;
create policy sync_applied_op_delete on public.sync_applied_op
  for delete to authenticated
  using (actor_id = (select auth.uid()));

-- ── 5. Monotonic metadata & Realtime broadcast triggers ─────────────────────
create or replace function public.bump_sync_metadata()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'INSERT' then
    new.updated_at := clock_timestamp();
    new.sync_seq := nextval('public.sync_seq_seq');
    return new;
  end if;

  -- Explicit seq touch when a child junction (envelope_tx) was deleted so
  -- pull_family_changes re-emits the parent transaction with _envelope_id=null.
  if current_setting('mhuri.touch_seq_only', true) = '1' then
    new.updated_at := clock_timestamp();
    new.sync_seq := nextval('public.sync_seq_seq');
    return new;
  end if;

  if (to_jsonb(new) - 'updated_at' - 'sync_seq')
     is not distinct from (to_jsonb(old) - 'updated_at' - 'sync_seq') then
    new.updated_at := old.updated_at;
    new.sync_seq := old.sync_seq;
    return new;
  end if;

  new.updated_at := clock_timestamp();
  new.sync_seq := nextval('public.sync_seq_seq');
  return new;
end;
$$;
revoke all on function public.bump_sync_metadata() from public, anon, authenticated;

create or replace function public.emit_family_sync_signal()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row jsonb := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
  v_space_id uuid;
  v_seq bigint;
begin
  if tg_op = 'UPDATE' and new.sync_seq is not distinct from old.sync_seq then
    return new;
  end if;

  v_seq := case
    when tg_op = 'DELETE' then nextval('public.sync_seq_seq')
    else new.sync_seq
  end;

  if tg_table_name = 'family_space' then
    if tg_op = 'DELETE' then
      return old;
    end if;
    v_space_id := new.id;
  elsif tg_table_name = 'user_profile' then
    insert into public.family_sync_signal (space_id, latest_seq, last_entity, updated_at)
    select m.space_id, v_seq, 'user_profile', clock_timestamp()
      from public.membership m
      join public.family_space s on s.id = m.space_id
     where m.user_id = (v_row->>'id')::uuid
       and m.invite_status = 'active'
    on conflict (space_id) do update
      set latest_seq = greatest(public.family_sync_signal.latest_seq, excluded.latest_seq),
          last_entity = excluded.last_entity,
          updated_at = excluded.updated_at;
    if tg_op = 'DELETE' then return old; else return new; end if;
  elsif v_row ? 'space_id' then
    v_space_id := nullif(v_row->>'space_id', '')::uuid;
  elsif tg_table_name = 'envelope_tx' then
    select e.space_id into v_space_id
      from public.envelope e
     where e.id = nullif(v_row->>'envelope_id', '')::uuid;
  elsif tg_table_name = 'goal_tx' then
    select g.space_id into v_space_id
      from public.goal g
     where g.id = nullif(v_row->>'goal_id', '')::uuid;
  elsif tg_table_name = 'list_item' then
    select l.space_id into v_space_id
      from public.shopping_list l
     where l.id = nullif(v_row->>'list_id', '')::uuid;
  elsif tg_table_name = 'commitment_occurrence' then
    select c.space_id into v_space_id
      from public.financial_commitment c
     where c.id = nullif(v_row->>'commitment_id', '')::uuid;
  elsif tg_table_name = 'commitment_payment' then
    select c.space_id into v_space_id
      from public.commitment_occurrence o
      join public.financial_commitment c on c.id = o.commitment_id
     where o.id = nullif(v_row->>'occurrence_id', '')::uuid;
  elsif tg_table_name in ('contribution_pledge', 'contribution_payment') then
    select c.space_id into v_space_id
      from public.contribution_campaign c
     where c.id = nullif(v_row->>'campaign_id', '')::uuid;
  elsif tg_table_name = 'debt_repayment' then
    select d.space_id into v_space_id
      from public.family_debt d
     where d.id = nullif(v_row->>'debt_id', '')::uuid;
  end if;

  if v_space_id is null
     or not exists (select 1 from public.family_space where id = v_space_id) then
    if tg_op = 'DELETE' then return old; else return new; end if;
  end if;

  insert into public.family_sync_signal (space_id, latest_seq, last_entity, updated_at)
  values (v_space_id, v_seq, tg_table_name, clock_timestamp())
  on conflict (space_id) do update
    set latest_seq = greatest(public.family_sync_signal.latest_seq, excluded.latest_seq),
        last_entity = excluded.last_entity,
        updated_at = excluded.updated_at;

  if tg_op = 'DELETE' then return old; else return new; end if;
end;
$$;
revoke all on function public.emit_family_sync_signal() from public, anon, authenticated;

create or replace function public.touch_tx_on_envelope_tx_delete()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_prev text := current_setting('mhuri.touch_seq_only', true);
begin
  if exists (select 1 from public.transaction where id = old.transaction_id) then
    perform set_config('mhuri.touch_seq_only', '1', true);
    update public.transaction
       set updated_at = clock_timestamp()
     where id = old.transaction_id;
    perform set_config('mhuri.touch_seq_only', coalesce(v_prev, ''), true);
  end if;
  return old;
end;
$$;
revoke all on function public.touch_tx_on_envelope_tx_delete()
  from public, anon, authenticated;

drop trigger if exists trg_zz_envelope_tx_delete on public.envelope_tx;
create trigger trg_zz_envelope_tx_delete
after delete on public.envelope_tx
for each row execute function public.touch_tx_on_envelope_tx_delete();

do $$
declare
  v_tbl text;
  v_tables text[] := array[
    'family_space',
    'membership',
    'user_profile',
    'account',
    'envelope',
    'envelope_tx',
    'budget_cycle_plan',
    'goal',
    'goal_tx',
    'shopping_list',
    'list_item',
    'transaction',
    'transaction_split',
    'kid_request',
    'earning',
    'recurring_rule',
    'chore',
    'mukando',
    'mukando_payment',
    'activity_log',
    'family_chat_message',
    'family_task',
    'family_reward',
    'financial_commitment',
    'commitment_occurrence',
    'commitment_payment',
    'contribution_campaign',
    'contribution_pledge',
    'contribution_payment',
    'family_debt',
    'debt_repayment'
  ];
begin
  foreach v_tbl in array v_tables loop
    execute format('drop trigger if exists trg_zz_sync_metadata on public.%I', v_tbl);
    execute format(
      'create trigger trg_zz_sync_metadata
         before insert or update on public.%I
         for each row execute function public.bump_sync_metadata()',
      v_tbl
    );
    execute format('drop trigger if exists trg_zz_sync_signal on public.%I', v_tbl);
    execute format(
      'create trigger trg_zz_sync_signal
         after insert or update or delete on public.%I
         for each row execute function public.emit_family_sync_signal()',
      v_tbl
    );
  end loop;
end;
$$;

-- ── 6. Type-normalized 3-way merge & domain convergence helper ──────────────
create or replace function public._compute_merged_sync_jsonb(
  p_table   text,
  p_current jsonb,
  p_base    jsonb,
  p_new     jsonb
) returns jsonb
language plpgsql
stable
security invoker
set search_path = public, pg_temp
as $$
declare
  v_norm_base   jsonb;
  v_norm_new    jsonb;
  v_merged      jsonb;
  v_base_alloc  jsonb;
  v_cur_alloc   jsonb;
  v_new_alloc   jsonb;
  v_replan_ok   boolean;
begin
  -- Normalize p_base and p_new through the table's exact PostgreSQL row type so
  -- timestamptz ('...000Z' vs '...+00:00'), uuid, date, numeric, and jsonb
  -- representations compare identically to to_jsonb(t.*).
  execute format(
    'select to_jsonb(jsonb_populate_record(null::public.%I, $1)),
            to_jsonb(jsonb_populate_record(null::public.%I, $2))',
    p_table, p_table
  )
  using (p_current || coalesce(p_base, '{}'::jsonb)),
        (p_current || coalesce(p_new, '{}'::jsonb))
  into v_norm_base, v_norm_new;

  if p_base is null then
    -- No base snapshot supplied (e.g. natural-key adoption): overlay keys
    -- explicitly provided by p_new onto p_current.
    v_merged := p_current || coalesce((
      select jsonb_object_agg(k, v_norm_new->k)
        from jsonb_object_keys(coalesce(p_new, '{}'::jsonb)) as k
       where v_norm_new ? k
    ), '{}'::jsonb);
  else
    -- Canonical 3-way field merge: apply client field k whenever the server's
    -- field k still matches the client's base (meaning server did not change k),
    -- AND only for keys actually present in p_new.
    v_merged := p_current || coalesce((
      select jsonb_object_agg(k, v_norm_new->k)
        from jsonb_object_keys(coalesce(p_new, '{}'::jsonb)) as k
       where v_norm_new ? k
         and (v_norm_base->k) is not distinct from (p_current->k)
    ), '{}'::jsonb);
  end if;

  -- Domain Rule A: budget_cycle_plan.allocations merges per envelope_id key!
  if p_table = 'budget_cycle_plan' then
    v_cur_alloc := coalesce(p_current->'allocations', '{}'::jsonb);
    v_new_alloc := coalesce(v_norm_new->'allocations', '{}'::jsonb);
    if p_base is null then
      v_merged := jsonb_set(v_merged, '{allocations}', v_cur_alloc || v_new_alloc);
    else
      v_base_alloc := coalesce(v_norm_base->'allocations', '{}'::jsonb);
      v_merged := jsonb_set(
        v_merged,
        '{allocations}',
        (
          select coalesce(jsonb_object_agg(key_name, val), '{}'::jsonb)
            from (
              select k as key_name,
                     case
                       when (v_base_alloc->k) is not distinct from (v_cur_alloc->k)
                         then v_new_alloc->k
                       else v_cur_alloc->k
                     end as val
                from (
                  select jsonb_object_keys(v_cur_alloc) as k
                  union
                  select jsonb_object_keys(v_new_alloc) as k
                ) keys
            ) merged_pairs
           where val is not null and val <> 'null'::jsonb
        )
      );
    end if;
  end if;

  -- Domain Rule B: Tombstones win monotonically across devices
  if (p_current ? 'deleted_at')
     and p_current->>'deleted_at' is not null
     and v_merged->>'deleted_at' is null then
    v_merged := jsonb_set(v_merged, '{deleted_at}', p_current->'deleted_at');
  end if;
  if p_table = 'family_chat_message'
     and coalesce((p_current->>'deleted')::boolean, false) then
    v_merged := jsonb_set(v_merged, '{deleted}', 'true'::jsonb);
  end if;

  -- Domain Rule C: Shopping item completion never regresses to tobuy without
  -- a deliberate new replanned_at, and keeps settlement fields coherent.
  if p_table = 'list_item' then
    if p_current->>'state' = 'done' and v_merged->>'state' = 'tobuy' then
      v_replan_ok := coalesce((v_norm_new->>'checked_out')::boolean, true) = false
        and v_norm_new->>'actual_price_minor' is null
        and v_norm_new->>'purchased_by' is null
        and v_norm_new->>'settled_tx_id' is null
        and v_norm_new->>'replanned_at' is not null
        and (
          p_current->>'replanned_at' is null
          or (v_norm_new->>'replanned_at')::timestamptz
             > (p_current->>'replanned_at')::timestamptz
        );
      if v_replan_ok then
        v_merged := v_merged || jsonb_build_object(
          'state', 'tobuy',
          'checked_out', false,
          'actual_price_minor', null,
          'actual_currency', null,
          'purchased_by', null,
          'settled_tx_id', null,
          'replanned_at', v_norm_new->'replanned_at'
        );
      else
        v_merged := v_merged || jsonb_build_object(
          'state', p_current->'state',
          'checked_out', p_current->'checked_out',
          'actual_price_minor', p_current->'actual_price_minor',
          'actual_currency', p_current->'actual_currency',
          'purchased_by', p_current->'purchased_by',
          'settled_tx_id', p_current->'settled_tx_id',
          'replanned_at', p_current->'replanned_at'
        );
      end if;
    elsif p_current->>'state' = 'done' and v_merged->>'state' = 'incart'
          and coalesce((p_current->>'checked_out')::boolean, false) then
      -- Already checked-out purchase cannot regress back to incart
      v_merged := v_merged || jsonb_build_object(
        'state', 'done',
        'checked_out', p_current->'checked_out',
        'actual_price_minor', p_current->'actual_price_minor',
        'actual_currency', p_current->'actual_currency',
        'purchased_by', p_current->'purchased_by',
        'settled_tx_id', p_current->'settled_tx_id'
      );
    end if;
  end if;

  -- Domain Rule D: Mukando round progress never regresses
  if p_table = 'mukando' then
    v_merged := jsonb_set(
      v_merged,
      '{current_round}',
      to_jsonb(greatest(
        coalesce((p_current->>'current_round')::integer, 1),
        coalesce((v_merged->>'current_round')::integer, 1)
      ))
    );
  end if;

  -- Domain Rule E: Kid request / teen proposal decision is final once decided
  if p_table = 'kid_request'
     and p_current->>'state' in ('approved', 'declined')
     and v_merged->>'state' = 'pending' then
    v_merged := v_merged || jsonb_build_object(
      'state', p_current->'state',
      'decided_by', p_current->'decided_by',
      'decided_at', p_current->'decided_at',
      'decision_note', p_current->'decision_note'
    );
  end if;

  -- Domain Rule F: Family task completion/approval tuple stays coherent as an
  -- atomic 5-field unit so status and approval columns never mix across sides.
  if p_table = 'family_task' then
    if p_base is not null
       and jsonb_build_array(
         v_norm_base->'status',
         v_norm_base->'completed_by_member_id',
         v_norm_base->'completed_at',
         v_norm_base->'approved_by_member_id',
         v_norm_base->'approved_at'
       ) = jsonb_build_array(
         p_current->'status',
         p_current->'completed_by_member_id',
         p_current->'completed_at',
         p_current->'approved_by_member_id',
         p_current->'approved_at'
       ) then
      v_merged := v_merged || jsonb_build_object(
        'status', v_norm_new->'status',
        'completed_by_member_id', v_norm_new->'completed_by_member_id',
        'completed_at', v_norm_new->'completed_at',
        'approved_by_member_id', v_norm_new->'approved_by_member_id',
        'approved_at', v_norm_new->'approved_at'
      );
    elsif p_base is not null then
      v_merged := v_merged || jsonb_build_object(
        'status', p_current->'status',
        'completed_by_member_id', p_current->'completed_by_member_id',
        'completed_at', p_current->'completed_at',
        'approved_by_member_id', p_current->'approved_by_member_id',
        'approved_at', p_current->'approved_at'
      );
    end if;
  end if;

  return v_merged;
end;
$$;
revoke all on function public._compute_merged_sync_jsonb(text, jsonb, jsonb, jsonb)
  from public, anon;
grant execute on function public._compute_merged_sync_jsonb(text, jsonb, jsonb, jsonb)
  to authenticated, service_role;

-- ── 7. Core single-row sync mutation engine (natural-key + merge + env link) ─
create or replace function public.apply_sync_mutation(
  p_table           text,
  p_id              uuid,
  p_new             jsonb,
  p_base_updated_at timestamptz default null,
  p_base            jsonb default null,
  p_op_id           text default null,
  p_space_id        uuid default null,
  p_force           boolean default false
) returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_target_id        uuid := p_id;
  v_adopted_id       uuid;
  v_current          jsonb;
  v_target_payload   jsonb;
  v_norm_target      jsonb;
  v_result_row       jsonb;
  v_outcome          text;
  v_cols             text;
  v_select_cols      text;
  v_set_clause       text;
  v_sql              text;
  v_prev_outcome     text;
  v_prev_row         jsonb;
  v_prev_seq         bigint;
  v_cur_env_id       uuid;
  v_effective_env_id uuid;
  v_has_env_directive boolean := coalesce((p_new->>'_has_envelope_link')::boolean, false);
begin
  if p_table not in (
    'account',
    'envelope',
    'budget_cycle_plan',
    'goal',
    'goal_tx',
    'shopping_list',
    'list_item',
    'transaction',
    'transaction_split',
    'kid_request',
    'earning',
    'recurring_rule',
    'chore',
    'mukando',
    'mukando_payment',
    'family_chat_message',
    'family_task',
    'family_reward',
    'financial_commitment',
    'commitment_occurrence',
    'commitment_payment',
    'contribution_campaign',
    'contribution_pledge',
    'contribution_payment',
    'family_debt',
    'debt_repayment'
  ) then
    raise exception using errcode = '42P01', message = 'UNKNOWN_SYNC_TABLE';
  end if;

  -- Idempotency ledger check: exact op replay returns prior canonical result.
  if p_op_id is not null and auth.uid() is not null then
    select o.outcome, o.result_row, o.applied_seq
      into v_prev_outcome, v_prev_row, v_prev_seq
      from public.sync_applied_op o
     where o.op_id = p_op_id
       and o.actor_id = auth.uid();
    if found then
      return jsonb_build_object(
        'status', 'applied',
        'outcome', 'already_applied',
        'merged', (v_prev_outcome = 'merged'),
        'sync_seq', v_prev_seq,
        'row', v_prev_row
      );
    end if;
  end if;

  -- Lock target row by primary key (subject to caller RLS).
  execute format(
    'select to_jsonb(t.*) from public.%I as t where t.id = $1 for update',
    p_table
  ) using v_target_id into v_current;

  -- Natural unique-key collision adoption when PK is absent on server.
  if v_current is null then
    if p_table = 'envelope' and (p_new ? 'space_id') then
      if nullif(p_new->>'template_key', '') is not null then
        select e.id, to_jsonb(e.*)
          into v_adopted_id, v_current
          from public.envelope e
         where e.space_id = (p_new->>'space_id')::uuid
           and e.template_key = p_new->>'template_key'
         for update;
      end if;
      if v_current is null
         and coalesce((p_new->>'is_archived')::boolean, false) = false
         and coalesce(p_new->>'sharing', 'shared') = 'shared'
         and nullif(btrim(coalesce(p_new->>'name', '')), '') is not null then
        select e.id, to_jsonb(e.*)
          into v_adopted_id, v_current
          from public.envelope e
         where e.space_id = (p_new->>'space_id')::uuid
           and e.is_archived = false
           and coalesce(e.sharing, 'shared') = 'shared'
           and lower(btrim(e.name)) = lower(btrim(p_new->>'name'))
         for update;
      end if;
    elsif p_table = 'budget_cycle_plan'
          and (p_new ? 'space_id') and (p_new ? 'cycle_start') then
      select b.id, to_jsonb(b.*)
        into v_adopted_id, v_current
        from public.budget_cycle_plan b
       where b.space_id = (p_new->>'space_id')::uuid
         and b.cycle_start = (p_new->>'cycle_start')::date
       for update;
    elsif p_table = 'commitment_occurrence'
          and (p_new ? 'commitment_id') and (p_new ? 'occurrence_key') then
      select o.id, to_jsonb(o.*)
        into v_adopted_id, v_current
        from public.commitment_occurrence o
       where o.commitment_id = (p_new->>'commitment_id')::uuid
         and o.occurrence_key = p_new->>'occurrence_key'
       for update;
    elsif p_table = 'contribution_pledge'
          and (p_new ? 'campaign_id') and (p_new ? 'member_id') then
      select cp.id, to_jsonb(cp.*)
        into v_adopted_id, v_current
        from public.contribution_pledge cp
       where cp.campaign_id = (p_new->>'campaign_id')::uuid
         and cp.member_id = (p_new->>'member_id')::uuid
       for update;
    elsif p_table = 'mukando_payment'
          and (p_new ? 'space_id') and (p_new ? 'round_no') and (p_new ? 'member_id')
          and (p_new->>'deleted_at') is null then
      select mp.id, to_jsonb(mp.*)
        into v_adopted_id, v_current
        from public.mukando_payment mp
       where mp.space_id = (p_new->>'space_id')::uuid
         and mp.round_no = (p_new->>'round_no')::integer
         and mp.member_id = (p_new->>'member_id')::uuid
         and mp.deleted_at is null
       for update;
    elsif p_table = 'transaction_split'
          and (p_new ? 'transaction_id') and (p_new ? 'envelope_id') then
      select ts.id, to_jsonb(ts.*)
        into v_adopted_id, v_current
        from public.transaction_split ts
       where ts.transaction_id = (p_new->>'transaction_id')::uuid
         and ts.envelope_id = (p_new->>'envelope_id')::uuid
       for update;
    end if;

    if v_adopted_id is not null then
      v_target_id := v_adopted_id;
    end if;
  end if;

  -- INSERT path: row does not exist under PK or natural key.
  if v_current is null then
    select
      coalesce(string_agg(format('%I', c.column_name), ', '), ''),
      coalesce(string_agg(format('i.%I', c.column_name), ', '), '')
    into v_cols, v_select_cols
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = p_table
      and c.column_name not in ('id', 'updated_at', 'sync_seq')
      and p_new ? c.column_name;

    if v_cols = '' then
      v_sql := format(
        'insert into public.%I as t (id) values ($1) returning to_jsonb(t.*)',
        p_table
      );
      execute v_sql using v_target_id into v_result_row;
    else
      v_sql := format(
        'insert into public.%I as t (id, %s)
         select $1, %s
           from jsonb_populate_record(null::public.%I, $2) as i
         returning to_jsonb(t.*)',
        p_table, v_cols, v_select_cols, p_table
      );
      execute v_sql using v_target_id, p_new into v_result_row;
    end if;
    v_outcome := 'inserted';
  else
    -- UPDATE / MERGE path: row already exists on server.
    if v_adopted_id is not null then
      v_target_payload := public._compute_merged_sync_jsonb(
        p_table,
        v_current,
        null,
        jsonb_set(p_new, '{id}', to_jsonb(v_target_id))
      );
      v_outcome := 'adopted_existing';
    elsif p_force
          or (
            p_base_updated_at is not null
            and (v_current->>'updated_at')::timestamptz = p_base_updated_at
          ) then
      execute format(
        'select to_jsonb(jsonb_populate_record(null::public.%I, $1))',
        p_table
      ) using (v_current || p_new) into v_target_payload;
      v_outcome := 'updated';
    else
      v_target_payload := public._compute_merged_sync_jsonb(
        p_table,
        v_current,
        p_base,
        p_new
      );
      v_outcome := 'merged';
    end if;

    -- Preserve immutable identity/authorship columns from v_current on UPDATE.
    execute format(
      'select to_jsonb(jsonb_populate_record(null::public.%I, $1))',
      p_table
    )
    using (
      v_target_payload || coalesce((
        select jsonb_object_agg(k, v_current->k)
          from unnest(array[
            'id','space_id','created_at','updated_at','sync_seq',
            'created_by','sender_id','is_system','added_by','requester_id','kind'
          ]) as k
         where v_current ? k
      ), '{}'::jsonb)
    )
    into v_norm_target;

    if (v_norm_target - 'updated_at' - 'sync_seq')
       is not distinct from (v_current - 'updated_at' - 'sync_seq') then
      v_result_row := v_current;
      if v_adopted_id is null then
        v_outcome := 'noop';
      end if;
    else
      select coalesce(string_agg(
        format('%I = i.%I', c.column_name, c.column_name), ', '), '')
      into v_set_clause
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = p_table
        and c.column_name not in (
          'id','space_id','created_at','updated_at','sync_seq',
          'created_by','sender_id','is_system','added_by','requester_id','kind'
        )
        and v_norm_target ? c.column_name;

      if v_set_clause = '' then
        v_result_row := v_current;
        if v_adopted_id is null then
          v_outcome := 'noop';
        end if;
      else
        v_sql := format(
          'with incoming as (
             select * from jsonb_populate_record(null::public.%I, $2)
           )
           update public.%I as t
              set %s
             from incoming as i
            where t.id = $1
           returning to_jsonb(t.*)',
          p_table, p_table, v_set_clause
        );
        execute v_sql using v_target_id, v_norm_target into v_result_row;
      end if;
    end if;
  end if;

  -- Atomic budget-envelope junction sync for transactions in Sync v2
  if p_table = 'transaction' and v_has_env_directive then
    select etx.envelope_id
      into v_cur_env_id
      from public.envelope_tx etx
     where etx.transaction_id = v_target_id
     limit 1;

    if (v_result_row->>'account_id') is not null then
      v_effective_env_id := null;
    elsif v_outcome in ('inserted', 'updated') or p_force or p_base is null
          or not coalesce((p_base->>'_has_envelope_link')::boolean, false) then
      v_effective_env_id := nullif(p_new->>'_envelope_id', '')::uuid;
    else
      -- 3-way merge on _envelope_id
      if nullif(p_base->>'_envelope_id', '')::uuid is not distinct from v_cur_env_id then
        v_effective_env_id := nullif(p_new->>'_envelope_id', '')::uuid;
      else
        v_effective_env_id := v_cur_env_id;
      end if;
    end if;

    if v_effective_env_id is null then
      if v_cur_env_id is not null then
        delete from public.envelope_tx where transaction_id = v_target_id;
        -- Re-read updated sync_seq after trg_zz_envelope_tx_delete touched transaction
        select to_jsonb(t.*) into v_result_row
          from public.transaction t
         where t.id = v_target_id;
        if v_outcome = 'noop' then v_outcome := 'updated'; end if;
      end if;
    else
      delete from public.envelope_tx
       where transaction_id = v_target_id
         and envelope_id <> v_effective_env_id;

      insert into public.envelope_tx (envelope_id, transaction_id, allocated_minor, currency)
      values (
        v_effective_env_id,
        v_target_id,
        (v_result_row->>'amount_minor')::bigint,
        v_result_row->>'currency'
      )
      on conflict (transaction_id) do update
        set envelope_id = excluded.envelope_id,
            allocated_minor = excluded.allocated_minor,
            currency = excluded.currency
      where public.envelope_tx.envelope_id is distinct from excluded.envelope_id
         or public.envelope_tx.allocated_minor is distinct from excluded.allocated_minor
         or public.envelope_tx.currency is distinct from excluded.currency;

      if v_cur_env_id is distinct from v_effective_env_id and v_outcome = 'noop' then
        v_outcome := 'updated';
      end if;
    end if;

    v_result_row := v_result_row || jsonb_build_object(
      '_has_envelope_link', true,
      '_envelope_id', v_effective_env_id
    );
  end if;

  if p_op_id is not null
     and auth.uid() is not null
     and coalesce(p_space_id, nullif(v_result_row->>'space_id', '')::uuid) is not null then
    insert into public.sync_applied_op (
      op_id, space_id, actor_id, entity, row_id, applied_seq, outcome, result_row
    ) values (
      p_op_id,
      coalesce(p_space_id, (v_result_row->>'space_id')::uuid),
      auth.uid(),
      p_table,
      v_target_id::text,
      coalesce((v_result_row->>'sync_seq')::bigint, 0),
      v_outcome,
      v_result_row
    )
    on conflict (op_id) do nothing;
  end if;

  return jsonb_build_object(
    'status', 'applied',
    'outcome', v_outcome,
    'merged', (v_outcome in ('merged', 'adopted_existing')),
    'replaced_id', case when v_adopted_id is not null then p_id else null end,
    'sync_seq', (v_result_row->>'sync_seq')::bigint,
    'row', v_result_row
  );
end;
$$;

revoke all on function public.apply_sync_mutation(
  text, uuid, jsonb, timestamptz, jsonb, text, uuid, boolean
) from public, anon;
grant execute on function public.apply_sync_mutation(
  text, uuid, jsonb, timestamptz, jsonb, text, uuid, boolean
) to authenticated;

-- ── 8. Upgraded merge_sync_row (v1 fallback compatibility + all mutable tbls) ─
create or replace function public.merge_sync_row(
  p_table           text,
  p_id              uuid,
  p_base_updated_at timestamptz,
  p_base            jsonb,
  p_new             jsonb
) returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_res jsonb;
begin
  if p_table not in (
    'account',
    'transaction',
    'envelope',
    'goal',
    'recurring_rule',
    'list_item',
    'shopping_list',
    'budget_cycle_plan',
    'family_debt',
    'contribution_campaign',
    'contribution_pledge',
    'family_task',
    'family_reward',
    'financial_commitment',
    'commitment_occurrence',
    'kid_request',
    'chore',
    'mukando',
    'mukando_payment',
    'family_chat_message'
  ) then
    raise exception using errcode = '42P01', message = 'UNKNOWN_MERGE_TABLE';
  end if;

  v_res := public.apply_sync_mutation(
    p_table           => p_table,
    p_id              => p_id,
    p_new             => p_new,
    p_base_updated_at => p_base_updated_at,
    p_base            => p_base
  );

  return jsonb_build_object(
    'row', v_res->'row',
    'merged', coalesce((v_res->>'merged')::boolean, false),
    'outcome', v_res->>'outcome',
    'replaced_id', v_res->'replaced_id'
  );
end;
$$;

revoke all on function public.merge_sync_row(text, uuid, timestamptz, jsonb, jsonb)
  from public, anon, authenticated;
grant execute on function public.merge_sync_row(text, uuid, timestamptz, jsonb, jsonb)
  to authenticated;

-- ── 9. Batch push_sync_ops(jsonb) with group_id subtransaction savepoints ───
create or replace function public.push_sync_ops(p_ops jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_total       integer;
  v_idx         integer := 0;
  v_end         integer;
  v_k           integer;
  v_group_id    text;
  v_op          jsonb;
  v_table       text;
  v_id          uuid;
  v_space_id    uuid;
  v_res         jsonb;
  v_group_res   jsonb[];
  v_results     jsonb[] := array[]::jsonb[];
  v_server_row  jsonb;
  v_permanent   boolean;
  v_err_state   text;
  v_err_msg     text;
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED' using errcode = '28000';
  end if;

  if p_ops is null or jsonb_typeof(p_ops) <> 'array' then
    return jsonb_build_object('results', '[]'::jsonb);
  end if;

  v_total := jsonb_array_length(p_ops);
  if v_total = 0 then
    return jsonb_build_object('results', '[]'::jsonb);
  end if;
  if v_total > 500 then
    raise exception 'SYNC_BATCH_TOO_LARGE' using errcode = '22023';
  end if;

  -- Opportunistic 1% GC of >30-day idempotency entries for this actor
  if random() < 0.01 then
    delete from public.sync_applied_op
     where actor_id = auth.uid()
       and applied_at < now() - interval '30 days';
  end if;

  while v_idx < v_total loop
    v_op := p_ops->v_idx;
    v_group_id := nullif(v_op->>'group_id', '');
    v_end := v_idx;

    if v_group_id is not null then
      while (v_end + 1) < v_total
        and nullif((p_ops->(v_end + 1))->>'group_id', '') = v_group_id loop
        v_end := v_end + 1;
      end loop;
    end if;

    -- Execute single op or atomic group_id span inside an isolated savepoint
    v_group_res := array[]::jsonb[];
    begin
      for v_k in v_idx .. v_end loop
        v_op := p_ops->v_k;
        v_table := v_op->>'table';
        v_id := (v_op->>'id')::uuid;
        v_space_id := nullif(v_op->>'space_id', '')::uuid;

        v_res := public.apply_sync_mutation(
          p_table           => v_table,
          p_id              => v_id,
          p_new             => coalesce(v_op->'payload', '{}'::jsonb),
          p_base_updated_at => nullif(v_op->>'base_updated_at', '')::timestamptz,
          p_base            => case
                                 when v_op ? 'base' and jsonb_typeof(v_op->'base') = 'object'
                                   then v_op->'base'
                                 else null
                               end,
          p_op_id           => nullif(v_op->>'op_id', ''),
          p_space_id        => v_space_id,
          p_force           => coalesce((v_op->>'force')::boolean, false)
        );

        v_group_res := array_append(
          v_group_res,
          v_res || jsonb_build_object(
            'op_id', v_op->'op_id',
            'table', v_table,
            'id', v_id
          )
        );
      end loop;

      v_results := v_results || v_group_res;
    exception when others then
      get stacked diagnostics
        v_err_state = returned_sqlstate,
        v_err_msg   = message_text;

      if v_err_state in ('28000', '28P01') then
        raise;
      end if;

      v_permanent := v_err_state in ('42501', '23514', '22P02', '22007', '22008', '42P01')
        or v_err_msg like '%PLUS_FEATURE_REQUIRED%'
        or v_err_msg like '%NOT_AUTHORIZED%'
        or v_err_msg like '%CHAT_%'
        or v_err_msg like '%FAMILY_LIMIT%'
        or v_err_msg like '%STALE_SHOPPING%';

      for v_k in v_idx .. v_end loop
        v_op := p_ops->v_k;
        v_table := v_op->>'table';
        v_server_row := null;
        begin
          if v_table in (
            'account','envelope','budget_cycle_plan','goal','goal_tx',
            'shopping_list','list_item','transaction','transaction_split',
            'kid_request','earning','recurring_rule','chore','mukando',
            'mukando_payment','family_chat_message','family_task',
            'family_reward','financial_commitment','commitment_occurrence',
            'commitment_payment','contribution_campaign','contribution_pledge',
            'contribution_payment','family_debt','debt_repayment'
          ) and nullif(v_op->>'id', '') is not null then
            execute format(
              'select to_jsonb(t.*) from public.%I as t where t.id = $1',
              v_table
            ) using (v_op->>'id')::uuid into v_server_row;
          end if;
        exception when others then
          v_server_row := null;
        end;

        v_results := array_append(
          v_results,
          jsonb_build_object(
            'op_id', v_op->'op_id',
            'table', v_table,
            'id', v_op->'id',
            'status', case when v_permanent then 'rejected' else 'retryable' end,
            'permanent', v_permanent,
            'sqlstate', v_err_state,
            'error', v_err_msg,
            'server_row', v_server_row
          )
        );
      end loop;
    end;

    v_idx := v_end + 1;
  end loop;

  return jsonb_build_object(
    'results', to_jsonb(v_results)
  );
end;
$$;

revoke all on function public.push_sync_ops(jsonb) from public, anon;
grant execute on function public.push_sync_ops(jsonb) to authenticated;

-- ── 10. Single-RPC keyset delta pull (`pull_family_changes`) ────────────────
create or replace function public.pull_family_changes(
  p_space_id   uuid,
  p_cursors    jsonb default '{}'::jsonb,
  p_page_limit integer default 500
) returns jsonb
language plpgsql
stable
security invoker
set search_path = public, pg_temp
as $$
declare
  v_limit          integer := least(greatest(coalesce(p_page_limit, 500), 50), 2000);
  v_has_more       boolean := false;
  v_changes        jsonb := '{}'::jsonb;
  v_next_cursors   jsonb := coalesce(p_cursors, '{}'::jsonb);
  v_cur            bigint;
  v_rows           jsonb;
  v_next_seq       bigint;
  v_more           boolean;
  v_roster_cur     bigint := coalesce(nullif(p_cursors->>'_roster', '')::bigint, 0);
  v_max_roster_seq bigint := 0;
  v_memberships    jsonb := '[]'::jsonb;
  v_profiles       jsonb := '[]'::jsonb;
  v_space_rows     jsonb := '[]'::jsonb;
  v_space_cur      bigint := coalesce(nullif(p_cursors->>'family_space', '')::bigint, 0);
  v_rate_rows      jsonb := '[]'::jsonb;
  v_signal_seq     bigint := 0;
  v_spec           record;
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED' using errcode = '28000';
  end if;
  if public.space_role(p_space_id) is null then
    raise exception 'NOT_IN_SPACE' using errcode = '42501';
  end if;

  select coalesce(s.latest_seq, 0)
    into v_signal_seq
    from public.family_sync_signal s
   where s.space_id = p_space_id;

  -- Space settings delta
  select coalesce(jsonb_agg(to_jsonb(s.*)), '[]'::jsonb),
         coalesce(max(s.sync_seq), v_space_cur)
    into v_space_rows, v_space_cur
    from public.family_space s
   where s.id = p_space_id
     and s.sync_seq > v_space_cur;
  v_next_cursors := jsonb_set(v_next_cursors, '{family_space}', to_jsonb(v_space_cur));

  -- Roster (active memberships + profiles returned together when any changed)
  select coalesce(max(greatest(m.sync_seq, coalesce(p.sync_seq, 0))), 0)
    into v_max_roster_seq
    from public.membership m
    left join public.user_profile p on p.id = m.user_id
   where m.space_id = p_space_id
     and m.invite_status = 'active';

  if v_roster_cur = 0 or v_max_roster_seq > v_roster_cur then
    select coalesce(jsonb_agg(to_jsonb(m.*) order by m.user_id), '[]'::jsonb)
      into v_memberships
      from public.membership m
     where m.space_id = p_space_id
       and m.invite_status = 'active';

    select coalesce(jsonb_agg(to_jsonb(p.*) order by p.id), '[]'::jsonb)
      into v_profiles
      from public.user_profile p
     where exists (
       select 1
         from public.membership m
        where m.space_id = p_space_id
          and m.invite_status = 'active'
          and m.user_id = p.id
     );
    v_next_cursors := jsonb_set(
      v_next_cursors,
      '{_roster}',
      to_jsonb(greatest(v_max_roster_seq, v_roster_cur))
    );
  end if;

  -- Latest FX rate snapshot (single row)
  select coalesce(jsonb_agg(to_jsonb(r.*)), '[]'::jsonb)
    into v_rate_rows
    from (
      select *
        from public.rate_snapshot
       order by captured_at desc
       limit 1
    ) r;

  -- Keyset-paginated entity streams in strict FK parent-before-child order,
  -- using exact client kPullOrder entity keys.
  for v_spec in
    select *
      from (values
        (1,  'account',               'select to_jsonb(t.*) as r, t.sync_seq as seq from public.account t where t.space_id = $1 and t.sync_seq > $2 order by t.sync_seq asc limit $3'),
        (2,  'envelope',              'select to_jsonb(t.*) as r, t.sync_seq as seq from public.envelope t where t.space_id = $1 and t.sync_seq > $2 order by t.sync_seq asc limit $3'),
        (3,  'budget_cycle_plan',     'select to_jsonb(t.*) as r, t.sync_seq as seq from public.budget_cycle_plan t where t.space_id = $1 and t.sync_seq > $2 order by t.sync_seq asc limit $3'),
        (4,  'goal',                  'select to_jsonb(t.*) as r, t.sync_seq as seq from public.goal t where t.space_id = $1 and t.sync_seq > $2 order by t.sync_seq asc limit $3'),
        (5,  'shopping_list',         'select to_jsonb(t.*) as r, t.sync_seq as seq from public.shopping_list t where t.space_id = $1 and t.sync_seq > $2 order by t.sync_seq asc limit $3'),
        (6,  'recurring',             'select to_jsonb(t.*) as r, t.sync_seq as seq from public.recurring_rule t where t.space_id = $1 and t.sync_seq > $2 order by t.sync_seq asc limit $3'),
        (7,  'tx',                    'select (to_jsonb(t.*) || jsonb_build_object(''_has_envelope_link'', true, ''_envelope_id'', etx.envelope_id)) as r, greatest(t.sync_seq, coalesce(etx.sync_seq, 0)) as seq from public.transaction t left join public.envelope_tx etx on etx.transaction_id = t.id where t.space_id = $1 and greatest(t.sync_seq, coalesce(etx.sync_seq, 0)) > $2 order by greatest(t.sync_seq, coalesce(etx.sync_seq, 0)) asc, t.sync_seq asc limit $3'),
        (8,  'goal_tx',               'select to_jsonb(t.*) as r, t.sync_seq as seq from public.goal_tx t where exists (select 1 from public.goal g where g.id = t.goal_id and g.space_id = $1) and t.sync_seq > $2 order by t.sync_seq asc limit $3'),
        (9,  'list_item',             'select to_jsonb(t.*) as r, t.sync_seq as seq from public.list_item t where exists (select 1 from public.shopping_list l where l.id = t.list_id and l.space_id = $1) and t.sync_seq > $2 order by t.sync_seq asc limit $3'),
        (10, 'kid_request',           'select to_jsonb(t.*) as r, t.sync_seq as seq from public.kid_request t where t.space_id = $1 and t.sync_seq > $2 order by t.sync_seq asc limit $3'),
        (11, 'earning',               'select to_jsonb(t.*) as r, t.sync_seq as seq from public.earning t where t.space_id = $1 and t.sync_seq > $2 order by t.sync_seq asc limit $3'),
        (12, 'chore',                 'select to_jsonb(t.*) as r, t.sync_seq as seq from public.chore t where t.space_id = $1 and t.sync_seq > $2 order by t.sync_seq asc limit $3'),
        (13, 'mukando',               'select to_jsonb(t.*) as r, t.sync_seq as seq from public.mukando t where t.space_id = $1 and t.sync_seq > $2 order by t.sync_seq asc limit $3'),
        (14, 'mukando_payment',       'select to_jsonb(t.*) as r, t.sync_seq as seq from public.mukando_payment t where t.space_id = $1 and t.sync_seq > $2 order by t.sync_seq asc limit $3'),
        (15, 'family_activity',       'select to_jsonb(t.*) as r, t.sync_seq as seq from public.activity_log t where t.space_id = $1 and t.sync_seq > $2 order by t.sync_seq asc limit $3'),
        (16, 'family_chat_message',   'select to_jsonb(t.*) as r, t.sync_seq as seq from public.family_chat_message t where t.space_id = $1 and t.sync_seq > $2 order by t.sync_seq asc limit $3'),
        (17, 'family_task',           'select to_jsonb(t.*) as r, t.sync_seq as seq from public.family_task t where t.space_id = $1 and t.sync_seq > $2 order by t.sync_seq asc limit $3'),
        (18, 'family_reward',         'select to_jsonb(t.*) as r, t.sync_seq as seq from public.family_reward t where t.space_id = $1 and t.sync_seq > $2 order by t.sync_seq asc limit $3'),
        (19, 'financial_commitment',  'select to_jsonb(t.*) as r, t.sync_seq as seq from public.financial_commitment t where t.space_id = $1 and t.sync_seq > $2 order by t.sync_seq asc limit $3'),
        (20, 'commitment_occurrence', 'select to_jsonb(t.*) as r, t.sync_seq as seq from public.commitment_occurrence t where exists (select 1 from public.financial_commitment c where c.id = t.commitment_id and c.space_id = $1) and t.sync_seq > $2 order by t.sync_seq asc limit $3'),
        (21, 'commitment_payment',    'select to_jsonb(t.*) as r, t.sync_seq as seq from public.commitment_payment t where exists (select 1 from public.commitment_occurrence o join public.financial_commitment c on c.id = o.commitment_id where o.id = t.occurrence_id and c.space_id = $1) and t.sync_seq > $2 order by t.sync_seq asc limit $3'),
        (22, 'contribution_campaign', 'select to_jsonb(t.*) as r, t.sync_seq as seq from public.contribution_campaign t where t.space_id = $1 and t.sync_seq > $2 order by t.sync_seq asc limit $3'),
        (23, 'contribution_pledge',   'select to_jsonb(t.*) as r, t.sync_seq as seq from public.contribution_pledge t where exists (select 1 from public.contribution_campaign c where c.id = t.campaign_id and c.space_id = $1) and t.sync_seq > $2 order by t.sync_seq asc limit $3'),
        (24, 'contribution_payment',  'select to_jsonb(t.*) as r, t.sync_seq as seq from public.contribution_payment t where exists (select 1 from public.contribution_campaign c where c.id = t.campaign_id and c.space_id = $1) and t.sync_seq > $2 order by t.sync_seq asc limit $3'),
        (25, 'family_debt',           'select to_jsonb(t.*) as r, t.sync_seq as seq from public.family_debt t where t.space_id = $1 and t.sync_seq > $2 order by t.sync_seq asc limit $3'),
        (26, 'debt_repayment',        'select to_jsonb(t.*) as r, t.sync_seq as seq from public.debt_repayment t where exists (select 1 from public.family_debt d where d.id = t.debt_id and d.space_id = $1) and t.sync_seq > $2 order by t.sync_seq asc limit $3'),
        (27, 'tx_allocation',         'select to_jsonb(t.*) as r, t.sync_seq as seq from public.transaction_split t where t.space_id = $1 and t.sync_seq > $2 order by t.sync_seq asc limit $3')
      ) as specs(ord, entity_key, sql_text)
    order by ord asc
  loop
    v_cur := coalesce(nullif(p_cursors->>v_spec.entity_key, '')::bigint, 0);

    execute format(
      'with fetched as (%s),
            numbered as (
              select r, seq, row_number() over () as rn
                from fetched
            )
       select coalesce(jsonb_agg(r order by rn) filter (where rn <= $4), ''[]''::jsonb),
              coalesce(max(seq) filter (where rn <= $4), $2),
              count(*) > $4
         from numbered',
      v_spec.sql_text
    )
    using p_space_id, v_cur, (v_limit + 1), v_limit
    into v_rows, v_next_seq, v_more;

    if jsonb_array_length(v_rows) > 0 then
      v_changes := jsonb_set(v_changes, array[v_spec.entity_key], v_rows);
    end if;
    v_next_cursors := jsonb_set(v_next_cursors, array[v_spec.entity_key], to_jsonb(v_next_seq));
    if v_more then
      v_has_more := true;
    end if;
  end loop;

  return jsonb_build_object(
    'protocol', 2,
    'signal_seq', v_signal_seq,
    'has_more', v_has_more,
    'cursors', v_next_cursors,
    'family_space', v_space_rows,
    'roster', jsonb_build_object(
      'changed', (v_roster_cur = 0 or v_max_roster_seq > v_roster_cur),
      'membership', v_memberships,
      'user_profile', v_profiles
    ),
    'rate_snapshot', v_rate_rows,
    'changes', v_changes
  );
end;
$$;

revoke all on function public.pull_family_changes(uuid, jsonb, integer)
  from public, anon;
grant execute on function public.pull_family_changes(uuid, jsonb, integer)
  to authenticated;

-- ── 11. Advertise sync_protocol = 2 on space bootstrap RPCs ─────────────────
create or replace function public.restore_my_space()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'space_id', m.space_id,
    'name', s.name,
    'invite_code', m.invite_code,
    'role', m.role,
    'sync_protocol', 2
  )
  from public.membership m
  join public.family_space s on s.id = m.space_id
  where m.user_id = auth.uid() and m.invite_status = 'active'
  order by m.joined_at desc nulls last
  limit 1;
$$;

create or replace function public.list_my_spaces()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'space_id', m.space_id,
    'name', s.name,
    'role', m.role,
    'invite_code', m.invite_code,
    'sync_protocol', 2
  ) order by m.joined_at desc nulls last), '[]'::jsonb)
  from public.membership m
  join public.family_space s on s.id = m.space_id
  where m.user_id = auth.uid() and m.invite_status = 'active';
$$;

create or replace function public.create_space(
  p_name text,
  p_household text,
  p_base_currency text,
  p_preferred_name text
) returns jsonb
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
  select m.space_id, m.invite_code into v_space, v_code
    from public.membership m
   where m.user_id = v_user and m.invite_status = 'active'
   limit 1;
  if v_space is not null then
    select id into v_list
      from public.shopping_list
     where space_id = v_space and deleted_at is null
     order by created_at
     limit 1;
    return jsonb_build_object(
      'id', v_space,
      'invite_code', v_code,
      'default_list_id', v_list,
      'existing', true,
      'sync_protocol', 2
    );
  end if;
  if length(btrim(coalesce(p_name, ''))) not between 2 and 80 then
    raise exception 'INVALID_FAMILY_NAME';
  end if;
  if p_base_currency not in ('USD','EUR','GBP','ZAR','CAD','AUD','KES','NGN','INR','ZWG') then
    raise exception 'UNSUPPORTED_CURRENCY';
  end if;
  if public.family_name_taken(p_name) then
    raise exception 'FAMILY_NAME_TAKEN';
  end if;
  v_display_name := coalesce(
    nullif(btrim(p_preferred_name), ''),
    nullif(split_part(coalesce((select email from auth.users where id = v_user), ''), '@', 1), ''),
    'Member'
  );
  insert into public.user_profile(id, name, email)
  values (
    v_user,
    v_display_name,
    coalesce((select email from auth.users where id = v_user), '')
  )
  on conflict (id) do update
    set name = coalesce(nullif(btrim(p_preferred_name), ''), public.user_profile.name);
  v_code := 'MHRI-' || upper(substr(md5(random()::text), 1, 4));
  insert into public.family_space(name, household_type, base_currency, settings)
  values (
    btrim(p_name),
    p_household,
    p_base_currency,
    jsonb_build_object('onboarding_stage', 'currencies')
  )
  returning id into v_space;
  insert into public.membership(space_id, user_id, role, sharing_level, invite_status, invite_code, joined_at)
  values (v_space, v_user, 'owner', 'full', 'active', v_code, now());
  insert into public.shopping_list(space_id, name)
  values (v_space, 'Shopping')
  returning id into v_list;
  insert into public.activity_log(space_id, actor_id, action, entity, entity_id, detail, hash)
  values (
    v_space,
    v_user,
    'family.create',
    'family_space',
    v_space,
    jsonb_build_object('name', btrim(p_name), 'base_currency', p_base_currency),
    md5(v_space::text || ':create:' || clock_timestamp())
  );
  return jsonb_build_object(
    'id', v_space,
    'invite_code', v_code,
    'default_list_id', v_list,
    'existing', false,
    'sync_protocol', 2
  );
end;
$$;

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
  values (
    v_user,
    v_display_name,
    coalesce((select email from auth.users where id = v_user), '')
  )
  on conflict (id) do update
    set name = coalesce(nullif(btrim(p_preferred_name), ''), public.user_profile.name);

  v_code := 'MHRI-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 4));
  insert into public.family_space(name, household_type, base_currency, settings)
  values (
    v_name,
    p_household,
    p_base_currency,
    jsonb_build_object('onboarding_stage', 'currencies')
  )
  returning id into v_space;
  insert into public.membership(space_id, user_id, role, sharing_level,
                               invite_status, invite_code, joined_at)
  values (v_space, v_user, 'owner', 'full', 'active', v_code, now());
  insert into public.shopping_list(space_id, name)
  values (v_space, 'Shopping')
  returning id into v_list;

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
  values (
    v_space,
    v_user,
    'family.create',
    'family_space',
    v_space,
    jsonb_build_object('name', v_name, 'base_currency', p_base_currency, 'additional_space', true),
    md5(v_space::text || ':create:' || clock_timestamp())
  );
  return jsonb_build_object(
    'id', v_space,
    'invite_code', v_code,
    'default_list_id', v_list,
    'existing', false,
    'sync_protocol', 2
  );
end;
$$;
revoke all on function public.create_additional_space(text, text, text, text)
  from public, anon;
grant execute on function public.create_additional_space(text, text, text, text)
  to authenticated;
