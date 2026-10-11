-- 032: align savings permissions with the app role contract and complete
-- creator attribution in the activity feed.

-- Owner/Admin may manage every savings goal. Adult Members may create goals
-- and manage only the goals they created. Contributors, Teens and Kids may
-- contribute to existing goals through goal_tx; Viewers remain read-only.
drop policy if exists goal_write on public.goal;
drop policy if exists goal_insert on public.goal;
drop policy if exists goal_update on public.goal;

create policy goal_insert on public.goal for insert
  with check (
    public.space_role(space_id) in ('owner','co_parent','adult')
    and created_by = auth.uid()
  );

create policy goal_update on public.goal for update
  using (
    public.can_manage_finances(space_id)
    or (public.space_role(space_id) = 'adult' and created_by = auth.uid())
  )
  with check (
    public.can_manage_finances(space_id)
    or (public.space_role(space_id) = 'adult' and created_by = auth.uid())
  );

-- Contributions are open to active members except read-only Viewers. The
-- provenance triggers force member_id to the authenticated user.
drop policy if exists gtx_insert on public.goal_tx;
drop policy if exists gtx_update on public.goal_tx;
create policy gtx_insert on public.goal_tx for insert with check (
  public.space_role((select g.space_id from public.goal g where g.id=goal_id))
    in ('owner','co_parent','adult','contributor','teen','kid')
  and member_id=auth.uid());
create policy gtx_update on public.goal_tx for update
  using (
    member_id=auth.uid()
    or public.can_manage_finances((select g.space_id from public.goal g where g.id=goal_id)))
  with check (
    member_id=auth.uid()
    or public.can_manage_finances((select g.space_id from public.goal g where g.id=goal_id)));

drop policy if exists contribution_pledge_write on public.contribution_pledge;
create policy contribution_pledge_write on public.contribution_pledge for all
  using (exists(
    select 1 from public.contribution_campaign c where c.id=campaign_id and (
      public.can_manage_finances(c.space_id)
      or (member_id=auth.uid() and public.space_role(c.space_id)<>'viewer'))))
  with check (exists(
    select 1 from public.contribution_campaign c where c.id=campaign_id and (
      public.can_manage_finances(c.space_id)
      or (member_id=auth.uid() and public.space_role(c.space_id)<>'viewer'))));

drop policy if exists contribution_payment_insert on public.contribution_payment;
create policy contribution_payment_insert on public.contribution_payment for insert
  with check (exists(
    select 1 from public.contribution_campaign c where c.id=campaign_id and (
      public.can_manage_finances(c.space_id)
      or (member_id=auth.uid() and public.space_role(c.space_id)<>'viewer'))));

-- Budget administration and family approvals belong to Owner/Admin. Adult
-- Members retain everyday transactions, lists, savings and debt access.
drop policy if exists account_write on public.account;
create policy account_write on public.account for all
  using (public.can_manage_finances(space_id))
  with check (public.can_manage_finances(space_id));

drop policy if exists category_write on public.category;
create policy category_write on public.category for all
  using (public.can_manage_finances(space_id))
  with check (public.can_manage_finances(space_id));

drop policy if exists chore_write on public.chore;
drop policy if exists chore_insert on public.chore;
drop policy if exists chore_update on public.chore;
create policy chore_insert on public.chore for insert
  with check (public.can_manage_finances(space_id));
create policy chore_update on public.chore for update
  using (
    public.can_manage_finances(space_id)
    or (public.space_role(space_id)='kid'
        and (assignee_member_id is null or assignee_member_id=auth.uid())))
  with check (
    public.can_manage_finances(space_id)
    or (public.space_role(space_id)='kid'
        and assignee_member_id=auth.uid()
        and state='waiting'));

drop policy if exists mukando_write on public.mukando;
create policy mukando_write on public.mukando for all
  using (public.can_manage_finances(space_id))
  with check (public.can_manage_finances(space_id));

drop policy if exists req_decide on public.kid_request;
create policy req_decide on public.kid_request for update
  using (public.can_manage_finances(space_id))
  with check (public.can_manage_finances(space_id));

drop policy if exists req_insert on public.kid_request;
create policy req_insert on public.kid_request for insert
  with check (
    requester_id=auth.uid()
    and public.space_role(space_id)='kid');
drop policy if exists req_read on public.kid_request;
create policy req_read on public.kid_request for select
  using (public.can_manage_finances(space_id) or requester_id=auth.uid());

-- Shared transaction visibility follows the same Teen/Kid budget switches
-- used by the app. Adult-facing roles and read-only Viewers see the ledger.
drop policy if exists tx_read on public.transaction;
create policy tx_read on public.transaction for select using (
  public.space_role(space_id) in ('owner','co_parent','adult','contributor','viewer')
  or (public.space_role(space_id)='teen'
      and public.role_perm(space_id,'teen_budget',true))
  or (public.space_role(space_id)='kid'
      and public.role_perm(space_id,'child_budget',true)));

drop policy if exists earn_read on public.earning;
drop policy if exists earning_read on public.earning;
create policy earning_read on public.earning for select
  using (public.can_manage_finances(space_id) or member_id=auth.uid());
drop policy if exists earn_write on public.earning;
drop policy if exists earning_write on public.earning;
create policy earning_write on public.earning for all
  using (member_id=auth.uid() and public.space_role(space_id)='teen')
  with check (member_id=auth.uid() and public.space_role(space_id)='teen');

drop policy if exists budget_cycle_plan_insert on public.budget_cycle_plan;
create policy budget_cycle_plan_insert on public.budget_cycle_plan for insert
  with check (public.can_manage_finances(space_id));
drop policy if exists budget_cycle_plan_update on public.budget_cycle_plan;
create policy budget_cycle_plan_update on public.budget_cycle_plan for update
  using (public.can_manage_finances(space_id))
  with check (public.can_manage_finances(space_id));

drop policy if exists family_chat_message_update on public.family_chat_message;
create policy family_chat_message_update on public.family_chat_message for update
  using (
    public.space_role(space_id) is not null
    and (sender_id=auth.uid() or public.can_manage_finances(space_id)))
  with check (
    public.space_role(space_id) is not null
    and (sender_id=auth.uid() or public.can_manage_finances(space_id)));

-- A member who may create a transaction may also attach its allocations.
drop policy if exists etx_write on public.envelope_tx;
create policy etx_write on public.envelope_tx for all
  using (exists(
    select 1 from public.transaction t where t.id=transaction_id and
      (t.created_by=auth.uid() or public.can_manage_finances(t.space_id))))
  with check (exists(
    select 1 from public.transaction t where t.id=transaction_id and
      (t.created_by=auth.uid() or public.can_manage_finances(t.space_id))));

drop policy if exists transaction_split_write on public.transaction_split;
create policy transaction_split_write on public.transaction_split for all
  using (exists(
    select 1 from public.transaction t where t.id=transaction_id and
      (t.created_by=auth.uid() or public.can_manage_finances(t.space_id))))
  with check (exists(
    select 1 from public.transaction t where t.id=transaction_id and
      (t.created_by=auth.uid() or public.can_manage_finances(t.space_id))));

-- Never trust a client-supplied creator. Preserve attribution on edits.
create or replace function public.guard_savings_creator() returns trigger
language plpgsql security definer set search_path=public as $$
begin
  if tg_op = 'INSERT' then
    new.created_by := auth.uid();
  else
    new.created_by := old.created_by;
  end if;
  return new;
end; $$;

drop trigger if exists trg_goal_creator_guard on public.goal;
create trigger trg_goal_creator_guard before insert or update on public.goal
for each row execute function public.guard_savings_creator();

drop trigger if exists trg_contribution_campaign_creator_guard on public.contribution_campaign;
create trigger trg_contribution_campaign_creator_guard
before insert or update on public.contribution_campaign
for each row execute function public.guard_savings_creator();

drop trigger if exists trg_family_debt_creator_guard on public.family_debt;
create trigger trg_family_debt_creator_guard
before insert or update on public.family_debt
for each row execute function public.guard_savings_creator();

-- The shared activity feed records who created or changed each shared savings
-- record. Payment and contribution rows already record their acting member.
drop trigger if exists trg_audit_contribution_campaign_lifecycle
  on public.contribution_campaign;
create trigger trg_audit_contribution_campaign_lifecycle
after insert or update on public.contribution_campaign
for each row execute function public.audit_financial_container();

drop trigger if exists trg_audit_family_debt_lifecycle on public.family_debt;
create trigger trg_audit_family_debt_lifecycle
after insert or update on public.family_debt
for each row execute function public.audit_financial_container();

