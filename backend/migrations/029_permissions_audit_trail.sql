-- 029: EXPLICIT ROLES + COMPLETE FINANCIAL AUDIT TRAIL.

alter table public.membership drop constraint if exists membership_role_check;
alter table public.membership add constraint membership_role_check
  check (role in ('owner','co_parent','adult','contributor','teen','kid','viewer'));

create or replace function public.is_adult(s uuid) returns boolean
language sql stable security definer set search_path=public as $$
  select coalesce(public.space_role(s) in ('owner','co_parent','adult'),false);
$$;

create or replace function public.can_manage_finances(s uuid) returns boolean
language sql stable security definer set search_path=public as $$
  select coalesce(public.space_role(s) in ('owner','co_parent'),false);
$$;
revoke all on function public.can_manage_finances(uuid) from public,anon;
grant execute on function public.can_manage_finances(uuid) to authenticated;

-- Shared records are readable by active members. Only Owner/Admin can change
-- budgets; Adult and Contributor can author their own transactions.
drop policy if exists tx_read on public.transaction;
create policy tx_read on public.transaction for select
  using (public.space_role(space_id) is not null);
drop policy if exists tx_write on public.transaction;
drop policy if exists tx_insert on public.transaction;
create policy tx_insert on public.transaction for insert with check (
  member_id=auth.uid() and (
    public.space_role(space_id) in ('owner','co_parent','adult','contributor')
    or (public.space_role(space_id)='teen' and public.role_perm(space_id,'teen_transactions',true))
    or (public.space_role(space_id)='kid' and public.role_perm(space_id,'child_transactions',false))));
drop policy if exists tx_update on public.transaction;
create policy tx_update on public.transaction for update
  using (created_by=auth.uid() or public.can_manage_finances(space_id))
  with check (created_by=auth.uid() or public.can_manage_finances(space_id));

drop policy if exists envelope_insert on public.envelope;
drop policy if exists envelope_update on public.envelope;
create policy envelope_insert on public.envelope for insert
  with check (public.can_manage_finances(space_id));
create policy envelope_update on public.envelope for update
  using (public.can_manage_finances(space_id)) with check (public.can_manage_finances(space_id));
drop policy if exists goal_insert on public.goal;
drop policy if exists goal_update on public.goal;
create policy goal_insert on public.goal for insert
  with check (public.can_manage_finances(space_id));
create policy goal_update on public.goal for update
  using (public.can_manage_finances(space_id)) with check (public.can_manage_finances(space_id));
drop policy if exists recurring_insert on public.recurring_rule;
drop policy if exists recurring_update on public.recurring_rule;
create policy recurring_insert on public.recurring_rule for insert
  with check (public.can_manage_finances(space_id));
create policy recurring_update on public.recurring_rule for update
  using (public.can_manage_finances(space_id)) with check (public.can_manage_finances(space_id));

-- Space-scoped role changes. Owner is immutable here; ownership transfer has
-- its own RPC. Admins cannot promote another owner.
create or replace function public.change_member_role(p_member uuid,p_role text,p_space_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_old text; v_admins int;
begin
  if not public.is_family_admin(p_space_id) then raise exception 'ADMIN_REQUIRED'; end if;
  if p_member=auth.uid() then raise exception 'CANNOT_CHANGE_OWN_ROLE'; end if;
  if p_role not in ('co_parent','adult','contributor','teen','kid','viewer') then raise exception 'BAD_ROLE'; end if;
  select role into v_old from public.membership where space_id=p_space_id
    and user_id=p_member and invite_status='active' for update;
  if v_old is null then raise exception 'MEMBER_NOT_FOUND'; end if;
  if v_old='owner' then raise exception 'USE_OWNERSHIP_TRANSFER'; end if;
  if p_role='co_parent' and v_old not in ('adult','contributor') then raise exception 'ADULT_REQUIRED'; end if;
  if v_old='co_parent' and p_role<>'co_parent' then
    select count(*) into v_admins from public.membership where space_id=p_space_id
      and invite_status='active' and role in ('owner','co_parent');
    if v_admins<=1 then raise exception 'LAST_ADMIN'; end if;
  end if;
  update public.membership set role=p_role where space_id=p_space_id and user_id=p_member;
  insert into public.activity_log(space_id,actor_id,action,entity,entity_id,detail,hash)
  values(p_space_id,auth.uid(),'member.role_change','membership',p_member,
    jsonb_build_object('from',v_old,'to',p_role),md5(p_member::text||':role:'||clock_timestamp()));
end; $$;

-- Trigger helpers append immutable audit rows for create/edit/archive actions.
create or replace function public.audit_transaction_changes() returns trigger
language plpgsql security definer set search_path=public as $$
declare v_action text;
begin
  if tg_op='INSERT' then v_action:='tx.create';
  elsif new.deleted_at is not null and old.deleted_at is null then v_action:='tx.delete';
  elsif new is distinct from old then v_action:='tx.update'; else return new; end if;
  insert into public.activity_log(space_id,actor_id,action,entity,entity_id,detail,hash)
  values(new.space_id,coalesce(auth.uid(),new.updated_by,new.created_by),v_action,'transaction',new.id,
    jsonb_build_object('amount_minor',new.amount_minor,'currency',new.currency,'member_id',new.member_id),
    md5(new.id::text||':'||v_action||':'||clock_timestamp()));
  return new;
end; $$;
drop trigger if exists trg_audit_tx on public.transaction;
create trigger trg_audit_tx after insert or update on public.transaction
for each row execute function public.audit_transaction_changes();

create or replace function public.audit_financial_container() returns trigger
language plpgsql security definer set search_path=public as $$
declare v_action text; v_name text; v_archived boolean:=false;
begin
  v_name:=coalesce(new.name,'');
  if tg_table_name='envelope' then v_archived:=coalesce(new.is_archived,false);
  elsif tg_table_name='goal' then v_archived:=new.status='archived';
  elsif tg_table_name='recurring_rule' then v_archived:=new.archived_at is not null; end if;
  v_action:=tg_table_name||case when v_archived then '.archive' when tg_op='INSERT' then '.create' else '.update' end;
  insert into public.activity_log(space_id,actor_id,action,entity,entity_id,detail,hash)
  values(new.space_id,coalesce(auth.uid(),new.created_by),v_action,tg_table_name,new.id,
    jsonb_build_object('name',v_name),md5(new.id::text||':'||v_action||':'||clock_timestamp()));
  return new;
end; $$;
drop trigger if exists trg_audit_envelope_lifecycle on public.envelope;
create trigger trg_audit_envelope_lifecycle after insert or update on public.envelope
for each row execute function public.audit_financial_container();
drop trigger if exists trg_audit_goal_lifecycle on public.goal;
create trigger trg_audit_goal_lifecycle after insert or update on public.goal
for each row execute function public.audit_financial_container();
drop trigger if exists trg_audit_recurring_lifecycle on public.recurring_rule;
create trigger trg_audit_recurring_lifecycle after insert or update on public.recurring_rule
for each row execute function public.audit_financial_container();

revoke all on function public.change_member_role(uuid,text,uuid) from public,anon;
grant execute on function public.change_member_role(uuid,text,uuid) to authenticated;

create or replace function public.create_invite(p_role text,p_email text,p_space_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_code text; v_id uuid; v_open int; v_email text:=lower(btrim(coalesce(p_email,'')));
begin
  if not public.is_family_admin(p_space_id) then raise exception 'ADMIN_REQUIRED'; end if;
  if p_role not in ('adult','co_parent','contributor','teen','kid','viewer') then raise exception 'BAD_ROLE'; end if;
  select count(*) into v_open from public.family_invite where space_id=p_space_id
    and revoked_at is null and accepted_at is null and expires_at>now();
  if v_open>=5 then raise exception 'TOO_MANY_INVITES'; end if;
  if v_email<>'' and v_email !~* '^\S+@\S+\.\S+$' then raise exception 'BAD_EMAIL'; end if;
  loop
    v_code:='MHRI-'||upper(substr(md5(random()::text||clock_timestamp()::text),1,6));
    exit when not exists(select 1 from public.family_invite where code=v_code);
  end loop;
  insert into public.family_invite(space_id,code,role,email,created_by)
  values(p_space_id,v_code,p_role,nullif(v_email,''),auth.uid()) returning id into v_id;
  insert into public.activity_log(space_id,actor_id,action,entity,entity_id,detail,hash)
  values(p_space_id,auth.uid(),'invite.create','family_invite',v_id,
    jsonb_build_object('role',p_role,'email_bound',v_email<>''),
    md5(v_id::text||':invite:'||clock_timestamp()));
  return jsonb_build_object('id',v_id,'code',v_code,'role',p_role);
end; $$;
revoke all on function public.create_invite(text,text,uuid) from public,anon;
grant execute on function public.create_invite(text,text,uuid) to authenticated;
