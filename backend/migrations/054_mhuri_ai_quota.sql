-- 054: family-scoped daily usage for Ask Mhuri. Provider keys and financial
-- context stay server-side; clients can never increment or inspect this table.
create table if not exists public.ai_usage_quota (
  space_id uuid not null references public.family_space(id) on delete cascade,
  usage_date date not null,
  request_count integer not null default 0 check (request_count >= 0),
  updated_at timestamptz not null default now(),
  primary key (space_id, usage_date)
);

alter table public.ai_usage_quota enable row level security;
revoke all on public.ai_usage_quota from anon, authenticated;
grant all on public.ai_usage_quota to service_role;

create or replace function public.consume_ai_usage(
  p_space_id uuid,
  p_daily_limit integer
) returns table (used integer, daily_limit integer, reset_at timestamptz)
language plpgsql security definer set search_path = public as $$
declare
  today_utc date := (now() at time zone 'utc')::date;
  next_utc timestamptz := ((today_utc + 1)::timestamp at time zone 'utc');
  new_count integer;
begin
  if p_space_id is null or p_daily_limit < 1 then
    raise exception 'INVALID_AI_QUOTA_REQUEST';
  end if;
  insert into public.ai_usage_quota as q (space_id, usage_date, request_count)
  values (p_space_id, today_utc, 1)
  on conflict (space_id, usage_date) do update
    set request_count = q.request_count + 1, updated_at = now()
    where q.request_count < p_daily_limit
  returning request_count into new_count;
  if new_count is null then
    -- Return limit + 1 as an in-memory signal to the caller; do not write an
    -- extra usage row once the cap is reached.
    select q.request_count + 1 into new_count
      from public.ai_usage_quota q
     where q.space_id = p_space_id and q.usage_date = today_utc;
  end if;
  return query select new_count, p_daily_limit, next_utc;
end;
$$;

revoke all on function public.consume_ai_usage(uuid, integer) from public;
revoke all on function public.consume_ai_usage(uuid, integer) from anon, authenticated;
grant execute on function public.consume_ai_usage(uuid, integer) to service_role;

-- Index supports future retention cleanup; this table stores aggregate counts,
-- never question text or conversation content.
create index if not exists ai_usage_quota_date_idx
  on public.ai_usage_quota (usage_date);

-- Existing active Plus families receive the new shared AI allowance too.
update public.family_entitlement
   set features = features || '["ask_mhuri"]'::jsonb,
       updated_at = now()
 where status in ('active', 'gracePeriod', 'canceledActive')
   and (expires_at is null or expires_at > now())
   and not (features ? 'ask_mhuri');
