-- 079_simplify_tasks_and_points_integrity.sql
-- Aligns family_task & family_reward points math and unassigned-task claiming:
--   1. Archiving an already-completed & approved task keeps earned points intact
--      (matching redeemed family_reward archiving).
--   2. Reopening an approved task whose points have already been spent on a
--      reward is rejected ('TASK_POINTS_ALREADY_REDEEMED') so earned >= spent
--      remains an unbreakable ledger invariant.
--   3. Kids can view and claim/submit unassigned ('Anyone') household tasks in
--      addition to tasks directly assigned to them, matching client UI.

create or replace function public.guard_family_reward_redemption()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_earned bigint := 0;
  v_spent bigint := 0;
begin
  if tg_op = 'UPDATE' and auth.uid() is not null
     and public.space_role(old.space_id) not in ('owner', 'co_parent') then
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

  if new.redeemed_at is not null
     and new.redeemed_by_member_id is not null
     and (tg_op = 'INSERT' or old.redeemed_at is null) then
    select coalesce(sum(t.points), 0)
      into v_earned
      from public.family_task t
     where t.space_id = new.space_id
       and t.status = 'done'
       and t.approved_by_member_id is not null
       and coalesce(t.completed_by_member_id, t.assignee_member_id) = new.redeemed_by_member_id;

    select coalesce(sum(r.points_cost), 0)
      into v_spent
      from public.family_reward r
     where r.space_id = new.space_id
       and r.id is distinct from new.id
       and r.redeemed_at is not null
       and r.redeemed_by_member_id = new.redeemed_by_member_id;

    if (v_earned - v_spent) < new.points_cost then
      raise exception 'INSUFFICIENT_TASK_POINTS';
    end if;
  end if;

  return new;
end;
$$;
revoke all on function public.guard_family_reward_redemption() from public, anon, authenticated;

create or replace function public.guard_family_task()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_role text;
  v_earner uuid;
  v_remaining_earned bigint := 0;
  v_spent bigint := 0;
begin
  if tg_op = 'INSERT' then
    if auth.uid() is not null then
      new.created_by := auth.uid();
    end if;
    new.created_at := coalesce(new.created_at, now());
  else
    new.created_by := old.created_by;
    new.created_at := old.created_at;
  end if;

  if auth.uid() is not null then
    v_role := public.space_role(new.space_id);
    if v_role is distinct from 'owner' and v_role is distinct from 'co_parent' then
      if tg_op = 'UPDATE' and old.requires_approval and not new.requires_approval then
        raise exception 'TASK_APPROVAL_REQUIRED_LOCKED';
      end if;
      if (new.requires_approval or (tg_op = 'UPDATE' and old.requires_approval))
         and (new.status = 'done' or new.approved_by_member_id is not null) then
        raise exception 'TASK_APPROVER_ONLY';
      end if;
      if tg_op = 'UPDATE' and old.approved_by_member_id is not null
         and (new.points is distinct from old.points
              or new.approved_by_member_id is distinct from old.approved_by_member_id
              or new.completed_by_member_id is distinct from old.completed_by_member_id) then
        raise exception 'TASK_REWARD_LOCKED';
      end if;
    end if;
  end if;

  if new.status in ('open', 'inProgress') then
    new.completed_at := null;
    new.completed_by_member_id := null;
    new.approved_at := null;
    new.approved_by_member_id := null;
  elsif new.status = 'done' and not new.requires_approval then
    new.completed_by_member_id := coalesce(
      new.completed_by_member_id,
      new.assignee_member_id,
      auth.uid(),
      new.created_by
    );
    new.completed_at := coalesce(new.completed_at, now());
    new.approved_by_member_id := coalesce(
      new.approved_by_member_id,
      auth.uid(),
      new.completed_by_member_id
    );
    new.approved_at := coalesce(new.approved_at, now());
  end if;

  -- Prevent revoking/reopening an approved task if its points were already redeemed.
  if tg_op = 'UPDATE'
     and old.status = 'done'
     and old.approved_by_member_id is not null
     and old.points > 0
     and (new.status <> 'done' or new.approved_by_member_id is null) then
    v_earner := coalesce(old.completed_by_member_id, old.assignee_member_id);
    if v_earner is not null then
      select coalesce(sum(t.points), 0)
        into v_remaining_earned
        from public.family_task t
       where t.space_id = old.space_id
         and t.id is distinct from old.id
         and t.status = 'done'
         and t.approved_by_member_id is not null
         and coalesce(t.completed_by_member_id, t.assignee_member_id) = v_earner;

      select coalesce(sum(r.points_cost), 0)
        into v_spent
        from public.family_reward r
       where r.space_id = old.space_id
         and r.redeemed_at is not null
         and r.redeemed_by_member_id = v_earner;

      if v_remaining_earned < v_spent then
        raise exception 'TASK_POINTS_ALREADY_REDEEMED';
      end if;
    end if;
  end if;

  new.updated_at := now();
  return new;
end;
$$;
revoke all on function public.guard_family_task() from public, anon, authenticated;

create or replace function public.guard_kid_task_submission()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.space_role(old.space_id) = 'kid' then
    if (old.assignee_member_id is not null and old.assignee_member_id is distinct from auth.uid())
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
       or (to_jsonb(new) - 'assignee_member_id' - 'status' - 'completed_at'
           - 'completed_by_member_id' - 'approved_by_member_id' - 'approved_at'
           - 'updated_at' - 'sync_seq')
          <> (to_jsonb(old) - 'assignee_member_id' - 'status' - 'completed_at'
              - 'completed_by_member_id' - 'approved_by_member_id' - 'approved_at'
              - 'updated_at' - 'sync_seq') then
      raise exception 'Kids may only submit their assigned or available family tasks';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.guard_kid_task_submission() from public, anon, authenticated;

drop policy if exists family_task_read on public.family_task;
create policy family_task_read on public.family_task
  for select to public
  using (
    public.space_role(space_id) is not null
    and (
      public.space_role(space_id) <> 'kid'
      or assignee_member_id is null
      or assignee_member_id = auth.uid()
    )
  );

drop policy if exists family_task_update on public.family_task;
create policy family_task_update on public.family_task
  for update to public
  using (
    public.space_role(space_id) in ('owner', 'co_parent', 'adult', 'contributor', 'teen')
    or (
      public.space_role(space_id) = 'kid'
      and (assignee_member_id is null or assignee_member_id = auth.uid())
    )
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
