-- 078: Intra-batch adopted-entity ID remapping in push_sync_ops
--
-- When two offline devices independently create the same natural-key parent
-- (for example an active shared `envelope` named "Electricity", an `account`,
-- or a `budget_cycle_plan`) AND one device also creates child records
-- referencing its local parent UUID before syncing, both the parent op and the
-- child ops arrive in a single `push_sync_ops(p_ops)` call (ordered parent
-- first by `kPushOrder`).
--
-- Without intra-batch ID remapping, the parent op adopts the existing server
-- row (`outcome = 'adopted_existing'`, `replaced_id = <client_uuid>`,
-- `row.id = <canonical_uuid>`), and subsequent child ops in the same batch
-- still reference `<client_uuid>`, causing foreign-key failures on `envelope_tx`
-- / `transaction` / `recurring_rule` / `budget_cycle_plan.allocations`.
--
-- This migration upgrades `push_sync_ops` to track `adopted_existing` ID
-- remappings across the batch and rewrite downstream FK fields + allocation
-- map keys automatically within the same single-RPC push.

create or replace function public._remap_sync_payload_ids(
  p_obj jsonb,
  p_map jsonb
) returns jsonb
language plpgsql
immutable
set search_path = public, pg_temp
as $$
declare
  v_out     jsonb := p_obj;
  v_field   text;
  v_val     text;
  v_alloc   jsonb;
  v_new_all jsonb := '{}'::jsonb;
  v_k       text;
  v_v       jsonb;
  v_mapped  text;
begin
  if p_obj is null or jsonb_typeof(p_obj) <> 'object'
     or p_map is null or p_map = '{}'::jsonb then
    return p_obj;
  end if;

  foreach v_field in array array[
    'id',
    'account_id',
    'envelope_id',
    '_envelope_id',
    'goal_id',
    'list_id',
    'recurring_rule_id',
    'commitment_id',
    'occurrence_id',
    'campaign_id',
    'pledge_id',
    'debt_id',
    'settled_tx_id',
    'transaction_id'
  ] loop
    if v_out ? v_field and jsonb_typeof(v_out->v_field) = 'string' then
      v_val := v_out->>v_field;
      if v_val is not null and p_map ? v_val then
        v_out := jsonb_set(v_out, array[v_field], to_jsonb(p_map->>v_val));
      end if;
    end if;
  end loop;

  if v_out ? 'allocations' and jsonb_typeof(v_out->'allocations') = 'object' then
    v_alloc := v_out->'allocations';
    for v_k, v_v in select key, value from jsonb_each(v_alloc) loop
      v_mapped := coalesce(p_map->>v_k, v_k);
      if v_new_all ? v_mapped
         and jsonb_typeof(v_new_all->v_mapped) = 'number'
         and jsonb_typeof(v_v) = 'number' then
        v_new_all := jsonb_set(
          v_new_all,
          array[v_mapped],
          to_jsonb((v_new_all->>v_mapped)::numeric + (v_v #>> '{}')::numeric)
        );
      else
        v_new_all := jsonb_set(v_new_all, array[v_mapped], v_v);
      end if;
    end loop;
    v_out := jsonb_set(v_out, '{allocations}', v_new_all);
  end if;

  return v_out;
end;
$$;

revoke all on function public._remap_sync_payload_ids(jsonb, jsonb)
  from public, anon;
grant execute on function public._remap_sync_payload_ids(jsonb, jsonb)
  to authenticated;

create or replace function public.push_sync_ops(p_ops jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_total        integer;
  v_idx          integer := 0;
  v_end          integer;
  v_k            integer;
  v_group_id     text;
  v_op           jsonb;
  v_payload      jsonb;
  v_base         jsonb;
  v_table        text;
  v_raw_id       text;
  v_id           uuid;
  v_space_id     uuid;
  v_res          jsonb;
  v_group_res    jsonb[];
  v_results      jsonb[] := array[]::jsonb[];
  v_id_remap     jsonb := '{}'::jsonb;
  v_group_remap  jsonb;
  v_replaced_id  text;
  v_canonical_id text;
  v_server_row   jsonb;
  v_permanent    boolean;
  v_err_state    text;
  v_err_msg      text;
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

    v_group_res := array[]::jsonb[];
    v_group_remap := v_id_remap;
    begin
      for v_k in v_idx .. v_end loop
        v_op := p_ops->v_k;
        v_table := v_op->>'table';
        v_payload := public._remap_sync_payload_ids(
          coalesce(v_op->'payload', '{}'::jsonb),
          v_group_remap
        );
        v_base := case
          when v_op ? 'base' and jsonb_typeof(v_op->'base') = 'object'
            then public._remap_sync_payload_ids(v_op->'base', v_group_remap)
          else null
        end;
        v_raw_id := coalesce(nullif(v_op->>'id', ''), nullif(v_payload->>'id', ''));
        if v_raw_id is not null and v_group_remap ? v_raw_id then
          v_raw_id := v_group_remap->>v_raw_id;
        end if;
        v_id := v_raw_id::uuid;
        v_space_id := nullif(v_op->>'space_id', '')::uuid;

        v_res := public.apply_sync_mutation(
          p_table           => v_table,
          p_id              => v_id,
          p_new             => v_payload,
          p_base_updated_at => nullif(v_op->>'base_updated_at', '')::timestamptz,
          p_base            => v_base,
          p_op_id           => nullif(v_op->>'op_id', ''),
          p_space_id        => v_space_id,
          p_force           => coalesce((v_op->>'force')::boolean, false)
        );

        if v_res->>'outcome' = 'adopted_existing' then
          v_replaced_id := nullif(v_res->>'replaced_id', '');
          v_canonical_id := nullif(v_res->'row'->>'id', '');
          if v_replaced_id is not null
             and v_canonical_id is not null
             and v_replaced_id <> v_canonical_id then
            v_group_remap := jsonb_set(
              v_group_remap,
              array[v_replaced_id],
              to_jsonb(v_canonical_id)
            );
          end if;
        end if;

        v_group_res := array_append(
          v_group_res,
          v_res || jsonb_build_object(
            'op_id', v_op->'op_id',
            'table', v_table,
            'id', coalesce(v_res->'row'->>'id', v_id::text)
          )
        );
      end loop;

      v_id_remap := v_group_remap;
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
