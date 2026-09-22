-- ============================================================================
-- 000_baseline.sql — TABLE BASELINE as a migration (the missing "from zero").
-- Extracted verbatim from schema.sql (Phase 1 DDL): tables, indexes, base RLS.
-- Outdated pieces it still contains (global profile_read, old
-- delete_own_account) are deliberately left and are REPLACED by the end of
-- the chain (002 replaces the function; 008 replaces the policy + function),
-- so the end state after 000→008 is the hardened one. CI proves this on
-- every push by applying 000→N to a clean Postgres.
-- ============================================================================
-- Mhuri Money — Supabase / PostgreSQL schema (Phase 1)
-- Mhuri Money — Supabase / PostgreSQL schema (Phase 1)
-- Maps to PRODUCT_SPEC.md §8 (Data Model) and §10 (Security, Privacy).
--
-- Money rule: amounts are ALWAYS bigint minor units + currency.
-- No floats. Conversion happens in the app using rate_snapshots — never
-- re-value stored amounts.
--
-- Run in the Supabase SQL editor (or `supabase db push`) on a fresh project.
-- ============================================================================

create extension if not exists pgcrypto;

-- ── Core: spaces, users, membership ─────────────────────────────────────────

create table family_space (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  household_type text not null default 'couple_kids'
    check (household_type in ('couple_kids','single_parent','extended','blended','partners','solo','other')),
  month_start_day int not null default 1 check (month_start_day between 1 and 28),
  base_currency text not null default 'USD' check (base_currency in ('USD','ZWG')),
  rate_profile text not null default 'rbz' check (rate_profile in ('rbz','market')),
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table user_profile (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique, -- auth.users email (2026-09: email+password auth replaced phone OTP)
  name text not null,
  avatar text not null default '🙂',
  language text not null default 'en' check (language in ('en','sn','nd')),
  ui_size text not null default 'normal' check (ui_size in ('normal','large')),
  created_at timestamptz not null default now()
);

create table membership (
  space_id uuid not null references family_space(id) on delete cascade,
  user_id uuid not null references user_profile(id) on delete cascade,
  role text not null
    check (role in ('owner','adult','teen','kid','viewer','co_parent')),
  sharing_level text not null default 'shared_only'
    check (sharing_level in ('full','shared_only')),
  private_pocket_enabled boolean not null default false,
  invite_status text not null default 'invited'
    check (invite_status in ('invited','active','left')),
  invite_code text,
  joined_at timestamptz,
  primary key (space_id, user_id)
);

create index on membership (user_id);

-- ── Accounts & transactions ─────────────────────────────────────────────────

create table account (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references family_space(id) on delete cascade,
  name text not null,
  kind text not null default 'cash'
    check (kind in ('cash','ecocash','bank_card','bank_transfer','zipit','innbucks','other')),
  owner_member_id uuid references user_profile(id) on delete set null,
  currency text not null check (currency in ('USD','ZWG')),
  sharing text not null default 'shared' check (sharing in ('shared','private')),
  opening_balance_minor bigint not null default 0 check (opening_balance_minor >= 0),
  is_archived boolean not null default false,
  created_at timestamptz not null default now()
);

create table category (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references family_space(id) on delete cascade,
  name text not null,
  icon text not null default '🧾',
  kind text not null default 'expense' check (kind in ('expense','income')),
  is_personal boolean not null default false
);

create table transaction (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references family_space(id) on delete cascade,
  account_id uuid references account(id) on delete set null,
  type text not null check (type in ('expense','income','transfer')),
  amount_minor bigint not null check (amount_minor > 0),
  currency text not null check (currency in ('USD','ZWG')),
  category_id uuid references category(id) on delete set null,
  member_id uuid not null references user_profile(id),
  method text not null default 'cash'
    check (method in ('cash','ecocash','bank_card','bank_transfer','zipit','innbucks','other')),
  occurred_at timestamptz not null default now(),
  note text not null default '',
  voice_note_uri text,
  receipt_uri text,
  recurring_rule_id uuid,
  split_group_id uuid,
  created_by uuid not null references user_profile(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz                      -- soft delete = 7-day trash (§3.4)
);

create index on transaction (space_id, occurred_at desc);
create index on transaction (member_id);

-- ── Envelopes (budgets, Module D) ───────────────────────────────────────────

create table envelope (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references family_space(id) on delete cascade,
  name text not null,
  icon text not null default '🧾',
  limit_minor bigint not null check (limit_minor > 0),
  limit_currency text not null check (limit_currency in ('USD','ZWG')),
  period text not null default 'monthly'
    check (period in ('monthly','term','custom')),
  rollover text not null default 'reset'
    check (rollover in ('reset','rollover','accumulate')),
  sharing text not null default 'shared' check (sharing in ('shared','personal')),
  linked_goal_id uuid,
  sort_order int not null default 0,
  is_archived boolean not null default false,
  created_at timestamptz not null default now()
);

create table envelope_tx (
  envelope_id uuid not null references envelope(id) on delete cascade,
  transaction_id uuid not null references transaction(id) on delete cascade,
  allocated_minor bigint not null check (allocated_minor > 0),
  currency text not null check (currency in ('USD','ZWG')),
  primary key (envelope_id, transaction_id)
);

-- ── Goals & community savings (Module E) ────────────────────────────────────

create table goal (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references family_space(id) on delete cascade,
  name text not null,
  icon text not null default '🎯',
  target_minor bigint not null check (target_minor > 0),
  target_currency text not null check (target_currency in ('USD','ZWG')),
  deadline date,
  owner_member_id uuid references user_profile(id) on delete set null,
  auto_save_rule jsonb,          -- e.g. {"amount_minor":2500,"currency":"USD","freq":"weekly","day":"friday"}
  is_kid_jar boolean not null default false,
  status text not null default 'active' check (status in ('active','done','archived')),
  created_at timestamptz not null default now()
);

create table goal_tx (
  id uuid primary key default gen_random_uuid(),
  goal_id uuid not null references goal(id) on delete cascade,
  member_id uuid not null references user_profile(id),
  amount_minor bigint not null check (amount_minor > 0),
  currency text not null check (currency in ('USD','ZWG')),
  note text not null default '',
  at timestamptz not null default now()
);

create table mukando (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references family_space(id) on delete cascade,
  name text not null,
  contribution_minor bigint not null check (contribution_minor > 0),
  currency text not null check (currency in ('USD','ZWG')),
  frequency text not null default 'monthly'
    check (frequency in ('weekly','fortnightly','monthly')),
  total_rounds int not null check (total_rounds > 0),
  current_round int not null default 1 check (current_round >= 1),
  started_on date not null default current_date,
  status text not null default 'active' check (status in ('active','done','archived')),
  created_at timestamptz not null default now()
);

create table mukando_member (
  mukando_id uuid not null references mukando(id) on delete cascade,
  user_id uuid not null references user_profile(id),
  round_order int not null check (round_order >= 1),
  collected_minor bigint not null default 0,
  collected_on timestamptz,
  primary key (mukando_id, user_id)
);

create table mukando_event (
  id uuid primary key default gen_random_uuid(),
  mukando_id uuid not null references mukando(id) on delete cascade,
  round_no int not null check (round_no >= 1),
  kind text not null check (kind in ('paid','collected')),
  member_id uuid not null references user_profile(id),
  proof_uri text,                              -- storage: payment proof photo
  at timestamptz not null default now()
);

-- ── Shopping lists (Module F) ───────────────────────────────────────────────

create table shopping_list (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references family_space(id) on delete cascade,
  name text not null,
  linked_envelope_id uuid references envelope(id) on delete set null,
  status text not null default 'active' check (status in ('active','done')),
  template_of uuid references shopping_list(id) on delete set null,
  created_at timestamptz not null default now()
);

create table list_item (
  id uuid primary key default gen_random_uuid(),
  list_id uuid not null references shopping_list(id) on delete cascade,
  name text not null,
  qty int not null default 1 check (qty > 0),
  est_price_minor bigint not null default 0,
  currency text not null default 'USD' check (currency in ('USD','ZWG')),
  added_by uuid not null references user_profile(id),
  assigned_to uuid references user_profile(id) on delete set null,
  state text not null default 'tobuy' check (state in ('tobuy','incart','done')),
  checked_out boolean not null default false,
  created_at timestamptz not null default now()
);

-- ── Kids & teens (Modules G/H) ──────────────────────────────────────────────

create table chore (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references family_space(id) on delete cascade,
  name text not null,
  star_value int not null default 1 check (star_value between 1 and 10),
  assignee_member_id uuid not null references user_profile(id),
  recurrence text not null default 'daily'
    check (recurrence in ('once','daily','weekly','custom')),
  is_active boolean not null default true
);

create table chore_log (
  id uuid primary key default gen_random_uuid(),
  chore_id uuid not null references chore(id) on delete cascade,
  done_on date not null default current_date,
  state text not null check (state in ('claimed','confirmed')),
  claimed_by uuid not null references user_profile(id),
  confirmed_by uuid references user_profile(id),
  unique (chore_id, done_on)
);

create table kid_request (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references family_space(id) on delete cascade,
  requester_id uuid not null references user_profile(id),
  amount_minor bigint not null check (amount_minor > 0),
  currency text not null check (currency in ('USD','ZWG')),
  reason text not null default '',
  kind text not null default 'money' check (kind in ('money','expense_proposal')),
  envelope_id uuid references envelope(id) on delete set null,  -- for teen proposals
  state text not null default 'pending'
    check (state in ('pending','approved','declined')),
  decided_by uuid references user_profile(id),
  decision_note text,
  decided_at timestamptz,
  created_at timestamptz not null default now()
);

create table earning (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references family_space(id) on delete cascade,
  member_id uuid not null references user_profile(id),
  note text not null,
  amount_minor bigint not null check (amount_minor > 0),
  currency text not null check (currency in ('USD','ZWG')),
  occurred_at timestamptz not null default now()
);

-- ── FX rates & audit ────────────────────────────────────────────────────────

create table rate_snapshot (
  day date not null,
  source text not null check (source in ('rbz','market')),
  usd_zwg numeric(12,4) not null check (usd_zwg > 0),
  captured_at timestamptz not null default now(),
  primary key (day, source)
);

-- Hash-chained, tamper-evident activity log (§3.4, §7 A7).
-- prev_hash chain is verified by the app on read (and by a scheduled job).
create table activity_log (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references family_space(id) on delete cascade,
  actor_id uuid not null references user_profile(id),
  action text not null,                        -- 'tx.create','envelope.move','request.approve'…
  entity text not null,
  entity_id uuid,
  detail jsonb not null default '{}'::jsonb,
  at timestamptz not null default now(),
  prev_hash text,
  hash text not null
);

create index on activity_log (space_id, at desc);

-- ── updated_at trigger ──────────────────────────────────────────────────────

create or replace function set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_transaction_updated
  before update on transaction
  for each row execute function set_updated_at();

-- ── Row-Level Security ──────────────────────────────────────────────────────
-- Pattern: helper SECURITY DEFINER function avoids recursive policy scans.
-- `space_role(space)` returns the caller's role or NULL if not an active
-- member. Kids/teens get targeted own-row policies; adults/owners get
-- space-wide write access; private pockets are enforced by view definitions
-- in the app layer (private rows are never returned to non-owners).

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

alter table family_space  enable row level security;
alter table user_profile  enable row level security;
alter table membership    enable row level security;
alter table account       enable row level security;
alter table category      enable row level security;
alter table transaction   enable row level security;
alter table envelope      enable row level security;
alter table envelope_tx   enable row level security;
alter table goal          enable row level security;
alter table goal_tx       enable row level security;
alter table mukando       enable row level security;
alter table mukando_member enable row level security;
alter table mukando_event enable row level security;
alter table shopping_list enable row level security;
alter table list_item     enable row level security;
alter table chore         enable row level security;
alter table chore_log     enable row level security;
alter table kid_request   enable row level security;
alter table earning       enable row level security;
alter table rate_snapshot enable row level security;
alter table activity_log  enable row level security;

-- family_space: visible to members; create = any authenticated user (becomes owner)
create policy space_read on family_space
  for select using (space_role(id) is not null);

-- user_profile: members of shared spaces see each other (basic demo policy;
-- tighten to a membership join view before launch)
create policy profile_read on user_profile
  for select using (true);
create policy profile_self_write on user_profile
  for update using (id = auth.uid());

-- membership: see co-members of your spaces; owners manage roles
create policy membership_read on membership
  for select using (
    user_id = auth.uid()
    or space_role(space_id) is not null
  );
create policy membership_manage on membership
  for all using (space_role(space_id) = 'owner')
  with check (space_role(space_id) = 'owner');

-- Generic member-read / adult-write policies for space-scoped tables
create policy account_read  on account      for select using (space_role(space_id) is not null);
create policy account_write on account      for all    using (is_adult(space_id)) with check (is_adult(space_id));
create policy category_read on category      for select using (space_role(space_id) is not null);
create policy category_write on category     for all    using (is_adult(space_id)) with check (is_adult(space_id));
create policy envelope_read on envelope      for select using (space_role(space_id) is not null);
create policy envelope_write on envelope     for all    using (is_adult(space_id)) with check (is_adult(space_id));
create policy goal_read    on goal          for select using (space_role(space_id) is not null);
create policy goal_write   on goal          for all    using (is_adult(space_id)) with check (is_adult(space_id));
create policy mukando_read on mukando       for select using (space_role(space_id) is not null);
create policy mukando_write on mukando      for all    using (is_adult(space_id)) with check (is_adult(space_id));
create policy list_read    on shopping_list for select using (space_role(space_id) is not null);
create policy list_write   on shopping_list for all    using (space_role(space_id) is not null) with check (space_role(space_id) is not null);
create policy item_read    on list_item     for select using (
  exists (select 1 from shopping_list l where l.id = list_item.list_id and space_role(l.space_id) is not null)
);
create policy item_write   on list_item     for all using (
  exists (select 1 from shopping_list l where l.id = list_item.list_id and space_role(l.space_id) is not null)
) with check (
  exists (select 1 from shopping_list l where l.id = list_item.list_id and space_role(l.space_id) is not null)
);
create policy chore_read   on chore         for select using (space_role(space_id) is not null);
create policy chore_write  on chore         for all    using (is_adult(space_id)) with check (is_adult(space_id));

-- transactions: adults read all; teens/kids only see their own rows
create policy tx_read on transaction for select using (
  is_adult(space_id) or (member_id = auth.uid() and space_role(space_id) is not null)
);
create policy tx_write on transaction for insert with check (
  is_adult(space_id)
  or (member_id = auth.uid() and space_role(space_id) in ('owner','adult','teen'))
);
create policy tx_update on transaction for update using (
  is_adult(space_id) or created_by = auth.uid()
) with check (
  is_adult(space_id) or created_by = auth.uid()
);

create policy etx_read  on envelope_tx for select using (space_role(
  (select space_id from transaction t where t.id = envelope_tx.transaction_id)
) is not null);
create policy etx_write on envelope_tx for all using (is_adult(
  (select space_id from transaction t where t.id = envelope_tx.transaction_id)
)) with check (is_adult(
  (select space_id from transaction t where t.id = envelope_tx.transaction_id)
));

create policy gtx_read   on goal_tx for select using (space_role(
  (select space_id from goal g where g.id = goal_tx.goal_id)
) is not null);
create policy gtx_write  on goal_tx for all using (space_role(
  (select space_id from goal g where g.id = goal_tx.goal_id)
) is not null) with check (
  member_id = auth.uid() or is_adult(
    (select space_id from goal g where g.id = goal_tx.goal_id)
  )
);

create policy mm_read   on mukando_member for select using (space_role(
  (select space_id from mukando m where m.id = mukando_member.mukando_id)
) is not null);
create policy mm_write  on mukando_member for all using (is_adult(
  (select space_id from mukando m where m.id = mukando_member.mukando_id)
)) with check (is_adult(
  (select space_id from mukando m where m.id = mukando_member.mukando_id)
));

create policy me_read   on mukando_event for select using (space_role(
  (select space_id from mukando m where m.id = mukando_event.mukando_id)
) is not null);
create policy me_write  on mukando_event for all using (space_role(
  (select space_id from mukando m where m.id = mukando_event.mukando_id)
) is not null) with check (space_role(
  (select space_id from mukando m where m.id = mukando_event.mukando_id)
) is not null);

create policy clog_read   on chore_log for select using (space_role(
  (select space_id from chore c where c.id = chore_log.chore_id)
) is not null);
create policy clog_write  on chore_log for all using (space_role(
  (select space_id from chore c where c.id = chore_log.chore_id)
) is not null) with check (space_role(
  (select space_id from chore c where c.id = chore_log.chore_id)
) is not null);

-- kid_request: requester sees own; adults see all and decide
create policy req_read on kid_request for select using (
  is_adult(space_id) or requester_id = auth.uid()
);
create policy req_insert on kid_request for insert with check (
  requester_id = auth.uid() or is_adult(space_id)
);
create policy req_decide on kid_request for update using (
  is_adult(space_id)
) with check (is_adult(space_id));

create policy earn_read   on earning for select using (
  is_adult(space_id) or member_id = auth.uid()
);
create policy earn_write  on earning for all using (
  member_id = auth.uid()
) with check (member_id = auth.uid());

-- rate_snapshot: public read (bundled offline too), server-cron writes
create policy rate_read  on rate_snapshot for select using (true);

-- activity_log: members read; writes go through server RPCs only
create policy log_read  on activity_log for select using (space_role(space_id) is not null);

-- ── Storage buckets (run once) ──────────────────────────────────────────────
-- insert into storage.buckets (id, name, public) values
--   ('receipts', 'receipts', false),
--   ('voice-notes', 'voice-notes', false),
--   ('mukando-proofs', 'mukando-proofs', false);
-- Access via signed URLs; policies mirror the RLS pattern above.

-- ── Notes ───────────────────────────────────────────────────────────────────
-- * Soft-deleted transactions (deleted_at set) stay queryable for the 7-day
--   trash; a scheduled job purges rows older than 7 days.
-- * Private pockets: privacy is enforced by NOT RETURNING private rows to
--   non-owners (extend tx_read with account.sharing checks + a summary RPC),
--   never by hiding in the UI only (spec §3.2, §10).
-- * Next server-side steps: edge function for daily RBZ rate upsert into
--   rate_snapshot, and RPCs `log_activity` (hash chaining) + `sync_flush`.


-- ═════════════════════════════════════════════════════════════════════════════
-- Sync-scope completion (premium pass, 2026-09-21)
-- * updated_at + triggers on EVERY synced table (the pull API orders by
--   updated_at — tables missing it would fail on first live sync);
-- * chore gains `state` (local ChoreState), assignee becomes nullable,
--   mukando gains `round_order` (member names, v1 simplification);
-- * new recurring_rule table (budget rules now sync across the family).
-- ═════════════════════════════════════════════════════════════════════════════

alter table envelope     add column if not exists updated_at timestamptz not null default now();
alter table goal         add column if not exists updated_at timestamptz not null default now();
alter table goal_tx      add column if not exists updated_at timestamptz not null default now();
alter table list_item    add column if not exists updated_at timestamptz not null default now();
alter table kid_request  add column if not exists updated_at timestamptz not null default now();
alter table earning      add column if not exists updated_at timestamptz not null default now();
alter table mukando      add column if not exists updated_at timestamptz not null default now();
alter table chore        add column if not exists updated_at timestamptz not null default now();

alter table chore add column if not exists state text not null default 'todo'
  check (state in ('todo','waiting','confirmed'));
alter table chore alter column assignee_member_id drop not null;
alter table mukando add column if not exists round_order text[] not null default '{}';

create or replace trigger trg_envelope_updated    before update on envelope     for each row execute function set_updated_at();
create or replace trigger trg_goal_updated        before update on goal         for each row execute function set_updated_at();
create or replace trigger trg_goal_tx_updated     before update on goal_tx      for each row execute function set_updated_at();
create or replace trigger trg_list_item_updated   before update on list_item    for each row execute function set_updated_at();
create or replace trigger trg_kid_request_updated before update on kid_request  for each row execute function set_updated_at();
create or replace trigger trg_earning_updated     before update on earning      for each row execute function set_updated_at();
create or replace trigger trg_mukando_updated     before update on mukando      for each row execute function set_updated_at();
create or replace trigger trg_chore_updated       before update on chore        for each row execute function set_updated_at();

create table if not exists recurring_rule (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references family_space(id) on delete cascade,
  name text not null,
  emoji text not null default '',
  amount_minor bigint not null check (amount_minor > 0),
  currency text not null default 'USD' check (currency in ('USD','ZWG')),
  envelope_id uuid references envelope(id) on delete set null,
  member_id uuid references user_profile(id) on delete set null,
  method text not null default 'cash'
    check (method in ('cash','mobile_money','bank_card','bank_transfer','agent','other')),
  frequency text not null default 'monthly'
    check (frequency in ('weekly','monthly','term')),
  next_due date not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_recurring_rule_space on recurring_rule (space_id);

create or replace trigger trg_recurring_rule_updated
  before update on recurring_rule
  for each row execute function set_updated_at();

alter table recurring_rule enable row level security;
create policy recurring_read on recurring_rule
  for select using (space_role(space_id) is not null);
create policy recurring_write on recurring_rule
  for all using (space_role(space_id) is not null)
  with check (space_role(space_id) is not null);

-- Self-service account deletion. The authenticated role can invoke this
-- function but never receives direct access to auth.users.
create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  delete from auth.users where id = v_user;
end;
$$;

revoke all on function public.delete_own_account() from public, anon;
grant execute on function public.delete_own_account() to authenticated;
