# Mhuri AI — Database Changes Specification

**Date:** 2026-10-23  
**Migration:** `054_mhuri_ai_quota.sql`  
**Status:** Additive, Forward-Only, Non-Destructive  

---

## 1. Schema Extensions

Phase 1 requires a concurrency-safe table to track daily AI usage per family and an atomic function to enforce quota caps without race conditions.

### 1.1 `public.ai_usage_quota` Table
```sql
create table if not exists public.ai_usage_quota (
  space_id uuid not null references public.family_space(id) on delete cascade,
  usage_date date not null default current_date,
  request_count int not null default 0,
  updated_at timestamptz not null default now(),
  primary key (space_id, usage_date)
);

alter table public.ai_usage_quota enable row level security;

-- Only service role updates/reads full quota stats; authenticated members
-- can read their own family's quota status.
create policy ai_usage_quota_select
  on public.ai_usage_quota for select to authenticated
  using (exists (
    select 1 from public.membership m
     where m.space_id = ai_usage_quota.space_id
       and m.user_id = auth.uid()
       and m.invite_status = 'active'
  ));

revoke all on public.ai_usage_quota from anon, authenticated;
grant select on public.ai_usage_quota to authenticated;
```

### 1.2 Atomic Quota Increment Function
```sql
create or replace function public.check_and_increment_ai_quota(
  p_space_id uuid,
  p_limit int
) returns table (
  allowed boolean,
  current_count int,
  remaining int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_count int;
begin
  -- Insert or increment atomically
  insert into public.ai_usage_quota (space_id, usage_date, request_count, updated_at)
  values (p_space_id, current_date, 1, now())
  on conflict (space_id, usage_date)
  do update set
    request_count = case
      when ai_usage_quota.request_count < p_limit then ai_usage_quota.request_count + 1
      else ai_usage_quota.request_count
    end,
    updated_at = now()
  returning request_count into v_count;

  if v_count <= p_limit then
    return query select true, v_count, (p_limit - v_count);
  else
    return query select false, v_count, 0;
  end if;
end;
$$;

revoke all on function public.check_and_increment_ai_quota(uuid, int) from public;
grant execute on function public.check_and_increment_ai_quota(uuid, int) to service_role;
```

---

## 2. Retention & Deletion Policy
- Usage quota records older than 90 days can be pruned safely as they are daily aggregates.
- Cascade delete on `space_id` guarantees that if a family space is deleted, quota records are purged immediately.

