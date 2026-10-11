-- 033: family tasks are shared family data. Every active family role except
-- kids may read them; viewers are read-only.

create table if not exists public.family_task (
  id uuid primary key,
  space_id uuid not null references public.family_space(id) on delete cascade,
  title text not null check (length(btrim(title)) between 1 and 200),
  note text,
  assignee_member_id uuid references public.user_profile(id) on delete set null,
  created_by uuid not null references public.user_profile(id),
  created_at timestamptz not null default now(),
  due_at timestamptz,
  status text not null default 'open'
    check (status in ('open', 'inProgress', 'done')),
  points integer not null default 1 check (points between 0 and 20),
  requires_approval boolean not null default true,
  approved_by_member_id uuid references public.user_profile(id) on delete set null,
  approved_at timestamptz,
  completed_at timestamptz,
  is_archived boolean not null default false,
  updated_at timestamptz not null default now()
);

create index if not exists family_task_space_due_idx
  on public.family_task(space_id, due_at, created_at desc);

alter table public.family_task enable row level security;

create or replace function public.guard_family_task() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    new.created_by := auth.uid();
    new.created_at := coalesce(new.created_at, now());
  else
    new.created_by := old.created_by;
    new.created_at := old.created_at;
  end if;
  new.updated_at := now();
  return new;
end; $$;

drop trigger if exists trg_family_task_guard on public.family_task;
create trigger trg_family_task_guard
before insert or update on public.family_task
for each row execute function public.guard_family_task();

drop policy if exists family_task_read on public.family_task;
create policy family_task_read on public.family_task for select using (
  public.space_role(space_id) is not null
  and public.space_role(space_id) <> 'kid'
);

drop policy if exists family_task_insert on public.family_task;
create policy family_task_insert on public.family_task for insert with check (
  public.space_role(space_id) in
    ('owner', 'co_parent', 'adult', 'contributor', 'teen')
  and created_by = auth.uid()
);

drop policy if exists family_task_update on public.family_task;
create policy family_task_update on public.family_task for update
using (
  public.space_role(space_id) in
    ('owner', 'co_parent', 'adult', 'contributor', 'teen')
)
with check (
  public.space_role(space_id) in
    ('owner', 'co_parent', 'adult', 'contributor', 'teen')
);

grant select, insert, update on public.family_task to authenticated;
