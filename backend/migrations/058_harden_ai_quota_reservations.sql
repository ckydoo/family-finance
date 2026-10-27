-- 058: Count in-flight Ask Mhuri requests against the same daily allowance
-- as completed answers, and make successful finalization retry-safe.
-- Apply only after the existing migration history has been reconciled.

alter table public.ai_usage_reservation
  add column if not exists status text not null default 'pending',
  add column if not exists finished_at timestamptz;

do $$
begin
  if not exists (
    select 1 from pg_constraint
     where conrelid = 'public.ai_usage_reservation'::regclass
       and conname = 'ai_usage_reservation_status_check'
  ) then
    alter table public.ai_usage_reservation
      add constraint ai_usage_reservation_status_check
      check (status in ('pending', 'completed', 'released', 'expired'));
  end if;
end;
$$;

create index if not exists ai_usage_reservation_pending_family_date_idx
  on public.ai_usage_reservation (space_id, usage_date, created_at)
  where status = 'pending';

create or replace function public.reserve_ai_usage(
  p_space_id uuid,
  p_reservation_id uuid,
  p_daily_limit integer
) returns table (status text, used integer, daily_limit integer, reset_at timestamptz)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  today_utc date := (now() at time zone 'utc')::date;
  next_utc timestamptz := ((today_utc + 1)::timestamp at time zone 'utc');
  successful_count integer;
  pending_count integer;
begin
  if p_space_id is null or p_reservation_id is null or p_daily_limit < 1 then
    raise exception 'INVALID_AI_QUOTA_REQUEST';
  end if;

  -- The Edge Function request budget is capped at 110 seconds. Expire only
  -- abandoned reservations after three minutes, leaving time for normal
  -- cleanup/finalization even on a slow request.
  update public.ai_usage_reservation r
     set status = 'expired', finished_at = now()
   where r.status = 'pending'
     and r.usage_date < today_utc
     and r.created_at < now() - interval '3 minutes';
  delete from public.ai_usage_reservation
   where created_at < now() - interval '7 days';

  insert into public.ai_usage_quota (space_id, usage_date, request_count)
  values (p_space_id, today_utc, 0)
  on conflict (space_id, usage_date) do nothing;

  -- Serializes reservations with each other and with successful finalization.
  select q.request_count into successful_count
    from public.ai_usage_quota q
   where q.space_id = p_space_id and q.usage_date = today_utc
   for update;

  select count(*)::integer into pending_count
    from public.ai_usage_reservation r
   where r.space_id = p_space_id and r.usage_date = today_utc
     and r.status = 'pending';

  if successful_count >= p_daily_limit then
    return query select 'limit', successful_count + pending_count,
                        p_daily_limit, next_utc;
    return;
  end if;

  -- Pending requests consume capacity immediately. A family cannot start
  -- more requests than the remaining daily allowance, even across devices.
  if successful_count + pending_count >= p_daily_limit or pending_count >= 3 then
    return query select 'busy', successful_count + pending_count,
                        p_daily_limit, next_utc;
    return;
  end if;

  insert into public.ai_usage_reservation (
    reservation_id, space_id, usage_date, status
  ) values (p_reservation_id, p_space_id, today_utc, 'pending');

  return query select 'reserved', successful_count + pending_count,
                      p_daily_limit, next_utc;
end;
$$;

-- The finalizer keeps its row so a retry can distinguish an already
-- committed answer from a released/expired reservation. It increments the
-- successful count exactly once.
create or replace function public.finalize_ai_usage(
  p_space_id uuid,
  p_reservation_id uuid,
  p_success boolean
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_reservation public.ai_usage_reservation%rowtype;
  v_status text;
begin
  -- Take the quota lock first, matching reserve_ai_usage. This serializes
  -- completion with new reservations and avoids lock-order deadlocks.
  perform 1
    from public.ai_usage_quota q
   where q.space_id = p_space_id
     and q.usage_date = (now() at time zone 'utc')::date
   for update;

  select * into v_reservation
    from public.ai_usage_reservation
   where reservation_id = p_reservation_id and space_id = p_space_id
   for update;

  if not found then return jsonb_build_object('status', 'not_found'); end if;
  -- Fail-path release must be allowed to clear a previous day's pending row
  -- even though today's quota row is the only one locked above.
  if v_reservation.usage_date <> (now() at time zone 'utc')::date then
    if v_reservation.status = 'pending' then
      update public.ai_usage_reservation
         set status = 'expired', finished_at = now()
       where reservation_id = p_reservation_id;
      return jsonb_build_object('status', 'expired');
    end if;
  end if;
  if v_reservation.status = 'completed' then
    return jsonb_build_object('status', 'completed', 'already_finalized', true);
  end if;
  if v_reservation.status <> 'pending' then
    return jsonb_build_object('status', v_reservation.status);
  end if;
  v_status := case when p_success then 'completed' else 'released' end;
  update public.ai_usage_reservation
     set status = v_status, finished_at = now()
   where reservation_id = p_reservation_id;

  if p_success then
  update public.ai_usage_quota
       set request_count = request_count + 1, updated_at = now()
     where space_id = p_space_id and usage_date = v_reservation.usage_date;
    if not found then raise exception 'AI_QUOTA_ROW_MISSING'; end if;
  end if;

  return jsonb_build_object('status', v_status, 'already_finalized', false);
end;
$$;

-- Preserve the existing internal RPC signature for fail-path cleanup while
-- routing it through the idempotent state transition.
create or replace function public.finish_ai_usage(
  p_space_id uuid,
  p_reservation_id uuid,
  p_success boolean
) returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform public.finalize_ai_usage(p_space_id, p_reservation_id, p_success);
end;
$$;

revoke all on function public.reserve_ai_usage(uuid, uuid, integer)
  from public, anon, authenticated;
grant execute on function public.reserve_ai_usage(uuid, uuid, integer)
  to service_role;

revoke all on function public.finalize_ai_usage(uuid, uuid, boolean)
  from public, anon, authenticated;
grant execute on function public.finalize_ai_usage(uuid, uuid, boolean)
  to service_role;
revoke all on function public.finish_ai_usage(uuid, uuid, boolean)
  from public, anon, authenticated;
grant execute on function public.finish_ai_usage(uuid, uuid, boolean)
  to service_role;

do $$
begin
  if to_regprocedure('public.reserve_ai_usage(uuid,uuid,integer)') is null
     or to_regprocedure('public.finalize_ai_usage(uuid,uuid,boolean)') is null then
    raise exception '058 SELF-TEST FAILED: hardened AI quota RPC missing';
  end if;
  if not exists (
    select 1 from pg_attribute
     where attrelid = 'public.ai_usage_reservation'::regclass
       and attname = 'status' and not attisdropped
  ) then
    raise exception '058 SELF-TEST FAILED: reservation state missing';
  end if;
end;
$$;
