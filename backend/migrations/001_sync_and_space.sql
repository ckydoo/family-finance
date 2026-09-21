-- ============================================================================
-- Mhuri Money — M3 sync & family-space migration (run AFTER schema.sql)
-- Adds: updated_at sync columns + triggers, family bootstrap functions.
-- Safe to re-run (idempotent).
-- ============================================================================

-- ── 1. updated_at on every synced table ─────────────────────────────────────
-- Pull uses `updated_at > cursor`; push relies on the server maintaining this
-- column so all devices converge on the same ordering.

alter table envelope    add column if not exists updated_at timestamptz not null default now();
alter table goal        add column if not exists updated_at timestamptz not null default now();
alter table goal_tx     add column if not exists updated_at timestamptz not null default now();
alter table list_item   add column if not exists updated_at timestamptz not null default now();
alter table kid_request add column if not exists updated_at timestamptz not null default now();
alter table earning     add column if not exists updated_at timestamptz not null default now();

create or replace function set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_envelope_updated    on envelope;
create trigger trg_envelope_updated    before update on envelope    for each row execute function set_updated_at();
drop trigger if exists trg_goal_updated        on goal;
create trigger trg_goal_updated        before update on goal        for each row execute function set_updated_at();
drop trigger if exists trg_goal_tx_updated     on goal_tx;
create trigger trg_goal_tx_updated     before update on goal_tx     for each row execute function set_updated_at();
drop trigger if exists trg_list_item_updated   on list_item;
create trigger trg_list_item_updated   before update on list_item   for each row execute function set_updated_at();
drop trigger if exists trg_kid_request_updated on kid_request;
create trigger trg_kid_request_updated before update on kid_request for each row execute function set_updated_at();
drop trigger if exists trg_earning_updated     on earning;
create trigger trg_earning_updated     before update on earning     for each row execute function set_updated_at();

-- ── 2. Invite codes ─────────────────────────────────────────────────────────

create unique index if not exists membership_invite_code_idx
  on membership (invite_code)
  where invite_code is not null;

-- ── 3. Family bootstrap (SECURITY DEFINER — RLS can't see a space you're
--      not in yet, so joining/creating must run with elevated rights) ───────

-- Creates a space + owner membership atomically. Returns {id, invite_code}.
create or replace function create_space(p_name text, p_household text default 'couple_kids')
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_space_id uuid;
  v_code text;
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  -- ensure the profile row exists (phone OTP users land here on first login)
  insert into user_profile (id, name)
  values (v_user, coalesce((select phone from auth.users where id = v_user), 'Member'))
  on conflict (id) do nothing;

  v_code := 'MHRI-' || upper(substr(md5(random()::text), 1, 4));

  insert into family_space (name, household_type)
  values (p_name, p_household)
  returning id into v_space_id;

  insert into membership (space_id, user_id, role, sharing_level, invite_status, invite_code, joined_at)
  values (v_space_id, v_user, 'owner', 'full', 'active', v_code, now());

  return jsonb_build_object('id', v_space_id, 'invite_code', v_code);
end;
$$;

-- Joins an existing space by invite code as an adult member.
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

  -- ensure the profile row exists
  insert into user_profile (id, name)
  values (v_user, coalesce((select phone from auth.users where id = v_user), 'Member'))
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

revoke all on function create_space(text, text) from public, anon;
revoke all on function join_space(text) from public, anon;
grant execute on function create_space(text, text) to authenticated;
grant execute on function join_space(text) to authenticated;

-- ── 4. Optional: realtime (Supabase Studio → Database → Replication).
--      M3 uses pull-on-start + 45s polling; enabling realtime replication for
--      list_item and kid_request gives instant list/approval updates later:
-- alter publication supabase_realtime add table list_item;
-- alter publication supabase_realtime add table kid_request;

-- ── Notes ───────────────────────────────────────────────────────────────────
-- * Conflict policy (M3): last-writer-wins via merge-duplicates upserts.
--   Decisions (approvals) made by two parents at the same moment resolve to
--   the latest write — acceptable at family scale, revisited in hardening.
-- * Synced entity set: transaction, envelope, goal, goal_tx, list_item,
--   kid_request (money + teen proposals), earning. Chore/stars/mukando stay
--   device-local for M3 by design.
