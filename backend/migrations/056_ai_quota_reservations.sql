-- 056: Count successful Ask Mhuri answers separately from in-flight requests.
create table if not exists public.ai_usage_reservation (
  reservation_id uuid primary key,
  space_id uuid not null references public.family_space(id) on delete cascade,
  usage_date date not null,
  created_at timestamptz not null default now()
);

create index if not exists ai_usage_reservation_family_date_idx
  on public.ai_usage_reservation (space_id, usage_date, created_at);

alter table public.ai_usage_reservation enable row level security;
revoke all on public.ai_usage_reservation from anon, authenticated;
grant all on public.ai_usage_reservation to service_role;

create or replace function public.reserve_ai_usage(
  p_space_id uuid,
  p_reservation_id uuid,
  p_daily_limit integer
) returns table (status text, used integer, daily_limit integer, reset_at timestamptz)
language plpgsql security definer set search_path = public as $$
declare
  today_utc date := (now() at time zone 'utc')::date;
  next_utc timestamptz := ((today_utc + 1)::timestamp at time zone 'utc');
  successful_count integer;
  pending_count integer;
begin
  if p_space_id is null or p_reservation_id is null or p_daily_limit < 1 then
    raise exception 'INVALID_AI_QUOTA_REQUEST';
  end if;

  delete from public.ai_usage_reservation
   where created_at < now() - interval '2 minutes';

  insert into public.ai_usage_quota (space_id, usage_date, request_count)
  values (p_space_id, today_utc, 0)
  on conflict (space_id, usage_date) do nothing;

  select q.request_count into successful_count
    from public.ai_usage_quota q
   where q.space_id = p_space_id and q.usage_date = today_utc
   for update;

  if successful_count >= p_daily_limit then
    return query select 'limit', successful_count, p_daily_limit, next_utc;
    return;
  end if;

  select count(*)::integer into pending_count
    from public.ai_usage_reservation r
   where r.space_id = p_space_id and r.usage_date = today_utc;
  if pending_count >= 3 then
    return query select 'busy', successful_count, p_daily_limit, next_utc;
    return;
  end if;

  insert into public.ai_usage_reservation (reservation_id, space_id, usage_date)
  values (p_reservation_id, p_space_id, today_utc);
  return query select 'reserved', successful_count, p_daily_limit, next_utc;
end;
$$;

create or replace function public.finish_ai_usage(
  p_space_id uuid,
  p_reservation_id uuid,
  p_success boolean
) returns void
language plpgsql security definer set search_path = public as $$
declare
  reservation_date date;
begin
  delete from public.ai_usage_reservation r
   where r.reservation_id = p_reservation_id and r.space_id = p_space_id
  returning r.usage_date into reservation_date;

  if p_success and reservation_date is not null then
    update public.ai_usage_quota
       set request_count = request_count + 1, updated_at = now()
     where space_id = p_space_id and usage_date = reservation_date;
  end if;
end;
$$;

revoke all on function public.reserve_ai_usage(uuid, uuid, integer) from public;
revoke all on function public.reserve_ai_usage(uuid, uuid, integer) from anon, authenticated;
grant execute on function public.reserve_ai_usage(uuid, uuid, integer) to service_role;
revoke all on function public.finish_ai_usage(uuid, uuid, boolean) from public;
revoke all on function public.finish_ai_usage(uuid, uuid, boolean) from anon, authenticated;
grant execute on function public.finish_ai_usage(uuid, uuid, boolean) to service_role;
