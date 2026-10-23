-- 053: prevent stale sync regressions and enforce lifecycle invariants.
-- Additive and idempotent. Existing production rows were audited before this
-- migration was prepared and satisfy the shopping constraints below.

-- Mutable commitment occurrences need a real change cursor. Falling back to
-- created_at discovers inserts but permanently misses later status changes.
alter table public.commitment_occurrence
  add column if not exists updated_at timestamptz not null default now();

drop trigger if exists trg_commitment_occurrence_updated
  on public.commitment_occurrence;
create trigger trg_commitment_occurrence_updated
before update on public.commitment_occurrence
for each row execute function public.set_updated_at();

create index if not exists commitment_occurrence_updated_idx
  on public.commitment_occurrence(updated_at);

-- A checked-out item has already contributed to an expense. It must remain
-- done and retain purchaser attribution. A done-but-not-checked-out row stays
-- valid while it is waiting for the user to finish the shopping trip.
alter table public.list_item
  drop constraint if exists list_item_checkout_lifecycle_check;
alter table public.list_item
  add constraint list_item_checkout_lifecycle_check check (
    (checked_out = false and purchased_by is null)
    or
    (checked_out = true and state = 'done' and purchased_by is not null)
  );

-- Do not manufacture family activity when a merge-upsert writes the same
-- business values again. Server-maintained updated_at is ignored.
create or replace function public.audit_shopping_item() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_space uuid; v_actor uuid;
begin
  if tg_op = 'UPDATE'
     and (to_jsonb(new) - 'updated_at') = (to_jsonb(old) - 'updated_at') then
    return new;
  end if;
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

create or replace function public.audit_shared_family_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  row_data jsonb := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
  old_data jsonb := case when tg_op = 'UPDATE' then to_jsonb(old) else '{}'::jsonb end;
  v_space uuid;
  v_actor uuid;
  v_id uuid;
  v_action text;
  v_detail jsonb;
begin
  if tg_op = 'UPDATE'
     and (row_data - 'updated_at') = (old_data - 'updated_at') then
    return new;
  end if;
  v_space := nullif(row_data->>'space_id', '')::uuid;
  v_actor := coalesce(
    auth.uid(),
    nullif(row_data->>'created_by', '')::uuid,
    nullif(row_data->>'sender_id', '')::uuid,
    nullif(row_data->>'member_id', '')::uuid,
    nullif(row_data->>'added_by', '')::uuid
  );
  v_id := nullif(row_data->>'id', '')::uuid;
  if v_space is null or v_actor is null or v_id is null then
    if tg_op = 'DELETE' then return old; else return new; end if;
  end if;

  v_action := case
    when tg_table_name = 'family_chat_message' and tg_op = 'INSERT' then 'chat.send'
    when tg_table_name = 'family_chat_message'
      and coalesce((row_data->>'deleted')::boolean, false)
      and not coalesce((old_data->>'deleted')::boolean, false) then 'chat.delete'
    when tg_table_name = 'family_chat_message' then 'chat.update'
    when tg_table_name = 'family_task' and tg_op = 'INSERT' then 'task.create'
    when tg_table_name = 'family_task'
      and coalesce((row_data->>'is_archived')::boolean, false)
      and not coalesce((old_data->>'is_archived')::boolean, false) then 'task.archive'
    when tg_table_name = 'family_task'
      and row_data->>'status' = 'done'
      and old_data->>'status' is distinct from 'done' then 'task.complete'
    when tg_table_name = 'family_task' then 'task.update'
    when tg_table_name = 'shopping_list' and tg_op = 'INSERT' then 'shopping.list_create'
    when tg_table_name = 'shopping_list' and row_data->>'deleted_at' is not null
      and old_data->>'deleted_at' is null then 'shopping.list_delete'
    when tg_table_name = 'shopping_list' then 'shopping.list_update'
    when tg_op = 'INSERT' then tg_table_name || '.create'
    when tg_op = 'DELETE' then tg_table_name || '.delete'
    else tg_table_name || '.update'
  end;

  v_detail := jsonb_strip_nulls(jsonb_build_object(
    'name', row_data->>'name',
    'title', row_data->>'title',
    'status', row_data->>'status',
    'state', row_data->>'state',
    'member_id', row_data->>'member_id',
    'assignee_member_id', row_data->>'assignee_member_id'
  ));
  insert into public.activity_log
    (space_id, actor_id, action, entity, entity_id, detail, hash)
  values
    (v_space, v_actor, v_action, tg_table_name, v_id, v_detail,
     md5(v_id::text || ':' || v_action || ':' || clock_timestamp()));
  if tg_op = 'DELETE' then return old; else return new; end if;
end;
$$;

revoke all on function public.audit_shopping_item() from public, anon, authenticated;
revoke all on function public.audit_shared_family_change() from public, anon, authenticated;
