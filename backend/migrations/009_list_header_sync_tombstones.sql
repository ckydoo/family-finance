-- 009: shopping-list HEADER sync + tombstones (closes the Phase-1 gap where
-- only list_item rows synced — a second device never learned the list
-- existed, and items were pushed with a null list_id and rejected).
--
-- 1. shopping_list.updated_at — the pull cursor requires it (001 added it to
--    list_item but missed the header table).
-- 2. deleted_at on shopping_list AND list_item — tombstones so a delete on
--    device A reaches device B (hard deletes cannot sync).
-- 3. create_space now also returns default_list_id so the creating device
--    can stamp every item push with the real list id (joiners learn it by
--    pulling the header).
-- Rollback: drop the new columns / keep the previous create_space from 008.

-- ── 1. header pull cursor ───────────────────────────────────────────────────
alter table shopping_list
  add column if not exists updated_at timestamptz not null default now();

drop trigger if exists trg_shopping_list_updated on shopping_list;
create trigger trg_shopping_list_updated
  before update on shopping_list
  for each row execute function set_updated_at();

-- ── 2. tombstones ───────────────────────────────────────────────────────────
alter table shopping_list add column if not exists deleted_at timestamptz;
alter table list_item    add column if not exists deleted_at timestamptz;

create index if not exists list_item_list_updated_idx
  on list_item (list_id, updated_at);
create index if not exists shopping_list_space_updated_idx
  on shopping_list (space_id, updated_at);

-- ── 3. create_space returns the default list id ─────────────────────────────
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

  -- Default shopping list so Lists works from minute one. Its id goes back
  -- to the creating device and reaches joiners through the header pull.
  insert into public.shopping_list (space_id, name)
  values (v_space, 'Groceries')
  returning id into v_list;

  insert into public.activity_log
    (space_id, actor_id, action, entity, entity_id, detail, hash)
  values (v_space, v_user, 'family.create', 'family_space', v_space,
          jsonb_build_object('name', btrim(p_name),
                             'base_currency', p_base_currency),
          md5(v_space::text || ':create:' || clock_timestamp()));

  return jsonb_build_object('id', v_space, 'invite_code', v_code,
                            'default_list_id', v_list);
end;
$$;

grant execute on function public.create_space(text,text,text,text)
  to authenticated;

-- ── 4. backfill: families created before 008 have no default list ──────────
-- Every existing family gets a 'Groceries' list so header sync + item pushes
-- work immediately after this migration (joiners learn the id on next pull).
insert into public.shopping_list (space_id, name)
select s.id, 'Groceries'
from public.family_space s
where not exists (
  select 1 from public.shopping_list l
   where l.space_id = s.id and l.deleted_at is null
);

-- ── self-test ───────────────────────────────────────────────────────────────
do $$
begin
  if not exists (select 1 from information_schema.columns
                  where table_schema='public' and table_name='shopping_list'
                    and column_name='updated_at') then
    raise exception '009 SELF-TEST FAILED: shopping_list.updated_at missing';
  end if;
  if not exists (select 1 from information_schema.columns
                  where table_schema='public' and table_name='list_item'
                    and column_name='deleted_at') then
    raise exception '009 SELF-TEST FAILED: list_item.deleted_at missing';
  end if;
end $$;
