-- 064: Shared family rewards and child task submission permissions.
create table if not exists public.family_reward (
  id uuid primary key,
  space_id uuid not null references public.family_space(id) on delete cascade,
  name text not null check (length(btrim(name)) between 1 and 120),
  points_cost integer not null check (points_cost > 0),
  description text,
  is_archived boolean not null default false,
  redeemed_by_member_id uuid references public.user_profile(id) on delete set null,
  redeemed_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.family_task
  add column if not exists completed_by_member_id uuid
  references public.user_profile(id) on delete set null;

-- The app uses this state while a child task waits for an adult's approval.
alter table public.family_task
  drop constraint if exists family_task_status_check;
alter table public.family_task
  add constraint family_task_status_check
  check (status in ('open', 'inProgress', 'awaitingApproval', 'done'));

-- Keep child write permissions narrow and server-enforced. The policy permits
-- moving an assigned responsibility to the configured completion state while
-- preserving every other field.
create or replace function public.guard_kid_task_submission()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if public.space_role(old.space_id) = 'kid' then
    if old.assignee_member_id is distinct from auth.uid()
       or new.assignee_member_id is distinct from auth.uid()
       or new.completed_by_member_id is distinct from auth.uid()
       or (old.requires_approval and new.status <> 'awaitingApproval')
       or (not old.requires_approval and new.status <> 'done')
       or (old.requires_approval and
           (new.approved_by_member_id is not null or new.approved_at is not null))
       or (not old.requires_approval and
           (new.approved_by_member_id is distinct from auth.uid()
            or new.approved_at is null))
       or old.status not in ('open', 'inProgress')
       or (to_jsonb(new) - 'status' - 'completed_at' - 'completed_by_member_id'
           - 'approved_by_member_id' - 'approved_at' - 'updated_at')
          <> (to_jsonb(old) - 'status' - 'completed_at' - 'completed_by_member_id'
              - 'approved_by_member_id' - 'approved_at' - 'updated_at') then
      raise exception 'Kids may only submit their assigned family tasks';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_kid_task_submission on public.family_task;
create trigger trg_guard_kid_task_submission
before update on public.family_task
for each row execute function public.guard_kid_task_submission();

-- Children need to see only tasks assigned to them so they can submit them.
drop policy if exists family_task_read on public.family_task;
create policy family_task_read on public.family_task for select using (
  public.space_role(space_id) is not null
  and (
    public.space_role(space_id) <> 'kid'
    or assignee_member_id = auth.uid()
  )
);

drop policy if exists family_task_update on public.family_task;
create policy family_task_update on public.family_task for update
using (
  public.space_role(space_id) in ('owner', 'co_parent', 'adult', 'contributor', 'teen')
  or (public.space_role(space_id) = 'kid' and assignee_member_id = auth.uid())
)
with check (
  public.space_role(space_id) in ('owner', 'co_parent', 'adult', 'contributor', 'teen')
  or (
    public.space_role(space_id) = 'kid'
    and assignee_member_id = auth.uid()
    and completed_by_member_id = auth.uid()
    and (
      (requires_approval and status = 'awaitingApproval'
       and approved_by_member_id is null and approved_at is null)
      or (not requires_approval and status = 'done'
          and approved_by_member_id = auth.uid() and approved_at is not null)
    )
  )
);

alter table public.family_reward enable row level security;
drop policy if exists family_reward_read on public.family_reward;
create policy family_reward_read on public.family_reward for select using (
  public.space_role(space_id) is not null
);
drop policy if exists family_reward_insert on public.family_reward;
create policy family_reward_insert on public.family_reward for insert with check (
  public.space_role(space_id) in ('owner', 'co_parent')
);
drop policy if exists family_reward_update on public.family_reward;
create policy family_reward_update on public.family_reward for update
using (
  public.space_role(space_id) in ('owner', 'co_parent')
  or (
    redeemed_at is null
    and not is_archived
    and public.space_role(space_id) in ('adult', 'contributor', 'teen', 'kid')
  )
)
with check (
  (
    public.space_role(space_id) in ('owner', 'co_parent')
    and (redeemed_by_member_id is null or redeemed_by_member_id = auth.uid())
  )
  or (
    public.space_role(space_id) in ('adult', 'contributor', 'teen', 'kid')
    and redeemed_by_member_id = auth.uid()
    and redeemed_at is not null
    and not is_archived
  )
);
create or replace function public.guard_family_reward_redemption()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if public.space_role(old.space_id) not in ('owner', 'co_parent') then
    if old.redeemed_at is not null
       or old.is_archived
       or new.id is distinct from old.id
       or new.space_id is distinct from old.space_id
       or new.name is distinct from old.name
       or new.points_cost is distinct from old.points_cost
       or new.description is distinct from old.description
       or new.is_archived is distinct from old.is_archived
       or new.redeemed_by_member_id is distinct from auth.uid()
       or new.redeemed_at is null then
      raise exception 'Family member may only redeem an available reward';
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists trg_guard_family_reward_redemption on public.family_reward;
create trigger trg_guard_family_reward_redemption
before update on public.family_reward
for each row execute function public.guard_family_reward_redemption();
grant select, insert, update on public.family_reward to authenticated;

revoke all on function public.guard_kid_task_submission() from public, anon, authenticated;
revoke all on function public.guard_family_reward_redemption() from public, anon, authenticated;
