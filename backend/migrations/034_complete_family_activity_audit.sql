-- 034: Complete family-facing audit coverage for shared app actions.
-- Authentication secrets and message contents are deliberately excluded.

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

do $$
declare table_name text;
begin
  foreach table_name in array array[
    'family_task', 'family_chat_message', 'chore', 'earning', 'mukando',
    'shopping_list', 'account'
  ] loop
    if to_regclass('public.' || table_name) is not null then
      execute format('drop trigger if exists %I on public.%I',
        'trg_audit_' || table_name || '_complete', table_name);
      execute format(
        'create trigger %I after insert or update or delete on public.%I '
        'for each row execute function public.audit_shared_family_change()',
        'trg_audit_' || table_name || '_complete', table_name);
    end if;
  end loop;
end;
$$;

-- Profile changes are visible in every active family the person belongs to,
-- but private profile fields such as email and phone are never copied.
create or replace function public.audit_profile_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare membership_row record;
begin
  if new.name is not distinct from old.name
     and new.avatar_url is not distinct from old.avatar_url
     and new.avatar is not distinct from old.avatar then
    return new;
  end if;
  for membership_row in
    select space_id from public.membership
     where user_id = new.id and invite_status = 'active'
  loop
    insert into public.activity_log
      (space_id, actor_id, action, entity, entity_id, detail, hash)
    values
      (membership_row.space_id, coalesce(auth.uid(), new.id),
       'profile.update', 'user_profile', new.id,
       jsonb_build_object('name', new.name),
       md5(new.id::text || ':profile.update:' || clock_timestamp()));
  end loop;
  return new;
end;
$$;

drop trigger if exists trg_audit_profile_change on public.user_profile;
create trigger trg_audit_profile_change
after update on public.user_profile
for each row execute function public.audit_profile_change();

revoke all on function public.audit_shared_family_change() from public, anon, authenticated;
revoke all on function public.audit_profile_change() from public, anon, authenticated;

-- Debt deletion is an archive so financial history remains intact. Name that
-- action explicitly in the feed instead of presenting it as a generic edit.
create or replace function public.audit_debt_lifecycle()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_action text;
begin
  v_action := case
    when tg_op = 'INSERT' then 'family_debt.create'
    when new.status = 'archived' and old.status is distinct from 'archived'
      then 'family_debt.archive'
    else 'family_debt.update'
  end;
  insert into public.activity_log
    (space_id, actor_id, action, entity, entity_id, detail, hash)
  values
    (new.space_id, coalesce(auth.uid(), new.created_by), v_action,
     'family_debt', new.id, jsonb_build_object('name', new.name),
     md5(new.id::text || ':' || v_action || ':' || clock_timestamp()));
  return new;
end;
$$;
drop trigger if exists trg_audit_family_debt_lifecycle on public.family_debt;
create trigger trg_audit_family_debt_lifecycle
after insert or update on public.family_debt
for each row execute function public.audit_debt_lifecycle();
revoke all on function public.audit_debt_lifecycle() from public, anon, authenticated;
