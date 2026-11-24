-- 075: Fix merge_sync_row() SQL/type bugs and enforce RLS via SECURITY INVOKER.
--
-- Fixes three issues in 074_server_authoritative_merge.sql:
-- 1. Uses jsonb_populate_record(NULL::public.<table>, payload) so uuid, bigint,
--    integer, boolean, timestamptz, and jsonb columns receive their native types
--    instead of raw text from ->>.
-- 2. Fixes the INSERT branch (previously referenced non-existent $3 and mixed
--    UPDATE col = val syntax into an INSERT column list).
-- 3. Switches from SECURITY DEFINER to SECURITY INVOKER and restricts p_table to
--    an explicit allowlist of conflict-tracked sync tables so caller RLS
--    policies are always enforced.
-- 4. Handles all-conflicting merges safely with COALESCE(..., '{}'::jsonb) and
--    treats omitted JSON keys consistently with JSON null.

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
  v_current     jsonb;
  v_payload     jsonb;
  v_cols        text;
  v_select_cols text;
  v_update_cols text;
  v_set_clause  text;
  v_sql         text;
  v_merged_flag boolean := false;
begin
  -- Explicit allowlist of conflict-tracked syncable tables.
  if p_table not in (
    'account',
    'transaction',
    'envelope',
    'goal',
    'recurring_rule',
    'list_item',
    'budget_cycle_plan',
    'family_debt',
    'contribution_campaign',
    'family_task',
    'family_reward',
    'financial_commitment'
  ) then
    raise exception using errcode = '42P01', message = 'UNKNOWN_MERGE_TABLE';
  end if;

  -- Lock the current row (subject to caller RLS) and read it as jsonb.
  v_sql := format(
    'SELECT to_jsonb(t.*) FROM public.%I AS t WHERE t.id = $1 FOR UPDATE',
    p_table
  );
  execute v_sql using p_id into v_current;

  -- Row does not exist: apply the client's new row directly (insert path).
  if v_current is null then
    select
      coalesce(string_agg(format('%I', c.column_name), ', '), ''),
      coalesce(string_agg(format('i.%I', c.column_name), ', '), ''),
      coalesce(string_agg(format('%I = EXCLUDED.%I', c.column_name, c.column_name), ', '), '')
    into v_cols, v_select_cols, v_update_cols
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = p_table
      and c.column_name not in ('id', 'updated_at', 'created_at')
      and p_new ? c.column_name;

    if v_cols = '' then
      v_sql := format(
        'INSERT INTO public.%I AS t (id, updated_at)
         VALUES ($1, now())
         ON CONFLICT (id) DO UPDATE SET updated_at = now()
         RETURNING to_jsonb(t.*)',
        p_table
      );
      execute v_sql using p_id into v_current;
    else
      v_sql := format(
        'INSERT INTO public.%I AS t (id, %s, updated_at)
         SELECT $1, %s, now()
         FROM jsonb_populate_record(NULL::public.%I, $2) AS i
         ON CONFLICT (id) DO UPDATE SET %s, updated_at = now()
         RETURNING to_jsonb(t.*)',
        p_table, v_cols, v_select_cols, p_table, v_update_cols
      );
      execute v_sql using p_id, p_new into v_current;
    end if;

    return jsonb_build_object('row', v_current, 'merged', false);
  end if;

  -- Fast path: the client's base matches the server's current version, or
  -- conflict path: deterministic field-level merge.
  if (v_current->>'updated_at')::timestamptz = p_base_updated_at then
    v_payload := p_new;
    v_merged_flag := false;
  else
    v_payload := v_current || coalesce((
      select jsonb_object_agg(k, p_new->k)
      from jsonb_object_keys(p_new) as k
      where coalesce(p_base->k, 'null'::jsonb)
            is not distinct from coalesce(v_current->k, 'null'::jsonb)
    ), '{}'::jsonb);
    v_merged_flag := true;
  end if;

  -- Persist the resulting row (server-managed columns excluded; updated_at
  -- stamped on the server).
  select coalesce(string_agg(
    format('%I = i.%I', c.column_name, c.column_name), ', '), '')
  into v_set_clause
  from information_schema.columns c
  where c.table_schema = 'public'
    and c.table_name = p_table
    and c.column_name not in ('id', 'updated_at', 'created_at')
    and v_payload ? c.column_name;

  if v_set_clause = '' then
    v_sql := format(
      'UPDATE public.%I AS t SET updated_at = now() WHERE t.id = $1 RETURNING to_jsonb(t.*)',
      p_table
    );
    execute v_sql using p_id into v_current;
  else
    v_sql := format(
      'WITH incoming AS (
         SELECT * FROM jsonb_populate_record(NULL::public.%I, $2)
       )
       UPDATE public.%I AS t
          SET %s, updated_at = now()
         FROM incoming AS i
        WHERE t.id = $1
       RETURNING to_jsonb(t.*)',
      p_table, p_table, v_set_clause
    );
    execute v_sql using p_id, v_payload into v_current;
  end if;

  return jsonb_build_object('row', v_current, 'merged', v_merged_flag);
end;
$$;

revoke all on function public.merge_sync_row(text, uuid, timestamptz, jsonb, jsonb)
  from public, anon, authenticated;
grant execute on function public.merge_sync_row(text, uuid, timestamptz, jsonb, jsonb)
  to authenticated;
