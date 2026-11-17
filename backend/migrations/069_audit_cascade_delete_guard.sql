-- 069: Guard audit triggers when a family_space or user_profile is being
-- removed (for example during sole-owner delete_own_account() cascade delete).

create or replace function public.audit_shared_family_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
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

  -- When a family_space is cascading deletes (e.g. sole-owner account deletion)
  -- or the actor profile no longer exists, skip writing orphan audit rows.
  if not exists (select 1 from public.family_space where id = v_space)
     or not exists (select 1 from public.user_profile where id = v_actor) then
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

create or replace function public.audit_profile_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  membership_row record;
  v_actor uuid;
begin
  if new.name is not distinct from old.name
     and new.avatar_url is not distinct from old.avatar_url
     and new.avatar is not distinct from old.avatar then
    return new;
  end if;
  v_actor := case
    when auth.uid() is not null
      and exists (select 1 from public.user_profile where id = auth.uid())
      then auth.uid()
    else new.id
  end;
  for membership_row in
    select space_id from public.membership
     where user_id = new.id and invite_status = 'active'
  loop
    if exists (select 1 from public.family_space where id = membership_row.space_id) then
      insert into public.activity_log
        (space_id, actor_id, action, entity, entity_id, detail, hash)
      values
        (membership_row.space_id, v_actor,
         'profile.update', 'user_profile', new.id,
         jsonb_build_object('name', new.name),
         md5(new.id::text || ':profile.update:' || clock_timestamp()));
    end if;
  end loop;
  return new;
end;
$$;

revoke all on function public.audit_shared_family_change() from public, anon, authenticated;
revoke all on function public.audit_profile_change() from public, anon, authenticated;
