-- 020: explicit, reusable monthly family plans.
-- Additive and safe to run after the existing family-space migrations.

create table if not exists public.budget_cycle_plan (
  id uuid primary key,
  space_id uuid not null references public.family_space(id) on delete cascade,
  cycle_start date not null,
  income_mode text not null check (income_mode in ('known_monthly', 'as_earned')),
  expected_income_minor bigint,
  currency text not null default 'USD',
  allocations jsonb not null default '{}'::jsonb,
  status text not null default 'active' check (status in ('active', 'closed')),
  copied_from date,
  closed_at timestamptz,
  created_by uuid references public.user_profile(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (space_id, cycle_start),
  check (
    (income_mode = 'as_earned' and expected_income_minor is null) or
    (income_mode = 'known_monthly' and expected_income_minor > 0)
  )
);

alter table public.budget_cycle_plan enable row level security;

drop policy if exists budget_cycle_plan_read on public.budget_cycle_plan;
create policy budget_cycle_plan_read on public.budget_cycle_plan for select
  using (public.space_role(space_id) is not null);

drop policy if exists budget_cycle_plan_insert on public.budget_cycle_plan;
create policy budget_cycle_plan_insert on public.budget_cycle_plan for insert
  with check (public.is_adult(space_id));

drop policy if exists budget_cycle_plan_update on public.budget_cycle_plan;
create policy budget_cycle_plan_update on public.budget_cycle_plan for update
  using (public.is_adult(space_id)) with check (public.is_adult(space_id));

create or replace function public.guard_budget_cycle_plan() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    new.created_by := auth.uid();
  else
    new.space_id := old.space_id;
    new.cycle_start := old.cycle_start;
    new.created_by := old.created_by;
    if old.status = 'closed' then
      raise exception 'CLOSED_PLAN_IMMUTABLE';
    end if;
  end if;
  if new.status = 'closed' and new.closed_at is null then
    new.closed_at := now();
  end if;
  new.updated_at := now();
  return new;
end; $$;

drop trigger if exists trg_budget_cycle_plan_guard on public.budget_cycle_plan;
create trigger trg_budget_cycle_plan_guard
before insert or update on public.budget_cycle_plan
for each row execute function public.guard_budget_cycle_plan();

grant select, insert, update on public.budget_cycle_plan to authenticated;
