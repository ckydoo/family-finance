-- 021: syncable family activity feed and audit coverage for plans/shopping.

alter table public.activity_log
  add column if not exists updated_at timestamptz not null default now();
create index if not exists activity_log_space_updated_idx
  on public.activity_log(space_id, updated_at);

create or replace function public.audit_budget_cycle_plan() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_action text;
begin
  v_action := case
    when new.status = 'closed' and (tg_op = 'INSERT' or old.status <> 'closed')
      then 'budget_plan.close'
    else 'budget_plan.save'
  end;
  insert into public.activity_log(
    space_id, actor_id, action, entity, entity_id, detail, hash)
  values (
    new.space_id, coalesce(auth.uid(), new.created_by), v_action,
    'budget_cycle_plan', new.id,
    jsonb_build_object('cycle_start', new.cycle_start,
                       'income_mode', new.income_mode),
    md5(new.id::text || ':' || v_action || ':' || clock_timestamp()));
  return new;
end; $$;

drop trigger if exists trg_audit_budget_cycle_plan on public.budget_cycle_plan;
create trigger trg_audit_budget_cycle_plan
after insert or update on public.budget_cycle_plan
for each row execute function public.audit_budget_cycle_plan();

create or replace function public.audit_shopping_item() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_space uuid; v_actor uuid;
begin
  select space_id into v_space from public.shopping_list where id = new.list_id;
  v_actor := coalesce(auth.uid(), new.added_by);
  if v_space is null or v_actor is null then return new; end if;
  insert into public.activity_log(
    space_id, actor_id, action, entity, entity_id, detail, hash)
  values (
    v_space, v_actor,
    case when tg_op = 'INSERT' then 'shopping.item_add'
         when new.state = 'done' and old.state <> 'done' then 'shopping.item_done'
         else 'shopping.item_update' end,
    'list_item', new.id,
    jsonb_build_object('name', new.name, 'qty', new.qty, 'state', new.state),
    md5(new.id::text || ':shopping:' || clock_timestamp()));
  return new;
end; $$;

drop trigger if exists trg_audit_shopping_item on public.list_item;
create trigger trg_audit_shopping_item
after insert or update on public.list_item
for each row execute function public.audit_shopping_item();

