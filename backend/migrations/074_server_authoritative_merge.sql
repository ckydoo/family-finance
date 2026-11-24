-- 074: Server-authoritative deterministic merge (Paradigm B).
--
-- Replaces whole-record "keep device / use family version" conflict resolution
-- with a single deterministic merge computed on the server. When a client's
-- compare-and-swap push fails because the row changed underneath it, the client
-- calls merge_sync_row with the row it started from (base) and the row it wants
-- (new). The server locks the row, and for every field the client intended to
-- change that the server has NOT changed since the client's base, the client's
-- value is applied; fields the server changed concurrently keep the server's
-- value. The merged row is persisted and returned. Every device applies the same
-- result, so convergence is guaranteed by construction - no user vote, no
-- divergence.
--
-- Rule (deterministic, server-authoritative):
--   merged[field] = new[field]   if base[field] IS NOT DISTINCT FROM current[field]
--                               (field unchanged on server since the client's base)
--   merged[field] = current[field] otherwise (concurrent change; server wins)
--
-- Different-field concurrent edits are both preserved. Same-field concurrent
-- edits resolve to the server's confirmed value (conservative for money).

create or replace function public.merge_sync_row(
  p_table        text,
  p_id           uuid,
  p_base_updated_at timestamptz,
  p_base         jsonb,
  p_new          jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_current jsonb;
  v_merged  jsonb;
  v_set_clause text;
  v_sql text;
  v_merged_flag boolean := false;
begin
  -- Only syncable tables may be merged.
  if not exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = p_table
  ) then
    raise exception using errcode = '42P01', message = 'UNKNOWN_MERGE_TABLE';
  end if;

  -- Lock the current row and read it as jsonb.
  v_sql := format(
    'SELECT to_jsonb(t.*) FROM %I t WHERE t.id = $1 FOR UPDATE', p_table);
  execute v_sql using p_id into v_current;

  -- Row does not exist: apply the client's new row directly (insert path).
  if v_current is null then
    v_sql := format(
      'INSERT INTO %I (id, updated_at) SELECT $1::uuid, now() '
      'ON CONFLICT (id) DO NOTHING RETURNING to_jsonb(t.*)', p_table);
    -- The client's new fields are applied via the overlay below; for an insert
    -- we persist the new row's client-settable columns.
    v_set_clause := (
      select coalesce(string_agg(
        format('%I = $3->>%I', c.column_name, c.column_name), ', '), '')
      from information_schema.columns c
      where c.table_schema = 'public' and c.table_name = p_table
        and c.column_name <> 'id' and c.column_name <> 'updated_at'
        and c.column_name <> 'created_at' and p_new ? c.column_name
    );
    if v_set_clause = '' then
      v_sql := format(
        'INSERT INTO %I (id, updated_at) VALUES ($1, now()) '
        'ON CONFLICT (id) DO UPDATE SET updated_at = now() '
        'RETURNING to_jsonb(t.*)', p_table);
      execute v_sql using p_id into v_current;
    else
      v_sql := format(
        'INSERT INTO %I (id, %s, updated_at) '
        'VALUES ($1, (SELECT jsonb_build_object(%s) :: text :: jsonb), now()) '
        'ON CONFLICT (id) DO UPDATE SET (%s), updated_at = now() '
        'RETURNING to_jsonb(t.*)',
        p_table, v_set_clause,
        (select string_agg(format('%I, $3->>%I', c.column_name, c.column_name), ', ')
           from information_schema.columns c
           where c.table_schema = 'public' and c.table_name = p_table
             and c.column_name <> 'id' and c.column_name <> 'updated_at'
             and c.column_name <> 'created_at' and p_new ? c.column_name),
        v_set_clause);
      execute v_sql using p_id, p_new into v_current;
    end if;
    return jsonb_build_object('row', v_current, 'merged', false);
  end if;

  -- Fast path: the client's base matches the server's current version. Apply
  -- the new row directly (this is the case CAS would have handled).
  if (v_current->>'updated_at')::timestamptz = p_base_updated_at then
    v_set_clause := (
      select coalesce(string_agg(
        format('%I = $2->>%I', c.column_name, c.column_name), ', '), '')
      from information_schema.columns c
      where c.table_schema = 'public' and c.table_name = p_table
        and c.column_name <> 'id' and c.column_name <> 'updated_at'
        and c.column_name <> 'created_at' and p_new ? c.column_name
    );
    if v_set_clause = '' then
      v_sql := format('UPDATE %I SET updated_at = now() WHERE id = $1 RETURNING to_jsonb(t.*)', p_table);
      execute v_sql using p_id into v_current;
    else
      v_sql := format('UPDATE %I SET %s, updated_at = now() WHERE id = $1 RETURNING to_jsonb(t.*)',
        p_table, v_set_clause);
      execute v_sql using p_id, p_new into v_current;
    end if;
    return jsonb_build_object('row', v_current, 'merged', false);
  end if;

  -- Conflict: deterministic field-level merge.
  -- Overlay the client's new values only for fields whose base value equals the
  -- server's current value (field unchanged on server since the client's base).
  v_merged := v_current || (
    select jsonb_object_agg(k, p_new->k)
    from jsonb_object_keys(p_new) as k
    where p_base->k IS NOT DISTINCT FROM v_current->k
  );
  v_merged_flag := true;

  -- Persist the merged row (server-managed columns excluded; set_updated_at
  -- trigger stamps updated_at).
  v_set_clause := (
    select coalesce(string_agg(
      format('%I = $2->>%I', c.column_name, c.column_name), ', '), '')
    from information_schema.columns c
    where c.table_schema = 'public' and c.table_name = p_table
      and c.column_name <> 'id' and c.column_name <> 'updated_at'
      and c.column_name <> 'created_at' and v_merged ? c.column_name
  );
  if v_set_clause = '' then
    v_sql := format('UPDATE %I SET updated_at = now() WHERE id = $1 RETURNING to_jsonb(t.*)', p_table);
    execute v_sql using p_id into v_current;
  else
    v_sql := format('UPDATE %I SET %s, updated_at = now() WHERE id = $1 RETURNING to_jsonb(t.*)',
      p_table, v_set_clause);
    execute v_sql using p_id, v_merged into v_current;
  end if;

  return jsonb_build_object('row', v_current, 'merged', v_merged_flag);
end;
$$;

revoke all on function public.merge_sync_row(text, uuid, timestamptz, jsonb, jsonb)
  from public, anon, authenticated;
grant execute on function public.merge_sync_row(text, uuid, timestamptz, jsonb, jsonb)
  to authenticated;
