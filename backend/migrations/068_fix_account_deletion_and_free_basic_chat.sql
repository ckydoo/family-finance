-- 068: Fix account deletion cascades/triggers and keep basic family chat free.
--
-- 1. audit_shared_family_change() must not insert into activity_log when the
--    enclosing family_space row has already been deleted during a cascade.
-- 2. Relax intra-space foreign keys (commitment_payment.transaction_id,
--    transaction_split.envelope_id, transaction.recurring_rule_id) so deleting
--    a solo-owned family_space never fails on cascade ordering.
-- 3. Make leave_family() and delete_own_account() multi-space aware, safe
--    against Supabase Storage's protect_delete trigger, and resilient when
--    retained history in a previously-joined family still references the user.
-- 4. Keep basic text chat, replies, and own-message deletion free while
--    requiring enhanced_family_chat on Mhuri Plus for media, voice notes,
--    stickers, financial references, and message edits.

-- ── 1. Safe audit trigger during family_space cascade deletion ──────────────
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
  if v_space is null or v_actor is null or v_id is null
     or not exists (select 1 from public.family_space where id = v_space) then
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

revoke all on function public.audit_shared_family_change() from public, anon, authenticated;

-- ── 2. Intra-space FK cascade safety for family deletion ────────────────────
do $$
begin
  if to_regclass('public.commitment_payment') is not null then
    alter table public.commitment_payment
      drop constraint if exists commitment_payment_transaction_id_fkey;
    alter table public.commitment_payment
      add constraint commitment_payment_transaction_id_fkey
      foreign key (transaction_id) references public.transaction(id) on delete cascade;
  end if;

  if to_regclass('public.transaction_split') is not null then
    alter table public.transaction_split
      drop constraint if exists transaction_split_envelope_id_fkey;
    alter table public.transaction_split
      add constraint transaction_split_envelope_id_fkey
      foreign key (envelope_id) references public.envelope(id) on delete cascade;
  end if;

  if to_regclass('public.transaction') is not null
     and to_regclass('public.recurring_rule') is not null then
    alter table public.transaction
      drop constraint if exists transaction_recurring_rule_id_fkey;
    alter table public.transaction
      add constraint transaction_recurring_rule_id_fkey
      foreign key (recurring_rule_id) references public.recurring_rule(id) on delete set null;
  end if;
end;
$$;

-- ── 3. Hardened leave_family() and delete_own_account() ─────────────────────
create or replace function public.leave_family()
returns void
language plpgsql
security definer
set search_path = public, storage
as $$
declare
  v_user uuid := auth.uid();
  v_space uuid;
  v_role text;
begin
  if v_user is null then raise exception 'NOT_AUTHENTICATED'; end if;

  select space_id, role into v_space, v_role
  from public.membership
  where user_id = v_user and invite_status = 'active'
  order by case when role = 'owner' then 1 else 0 end, joined_at desc nulls last
  limit 1;

  if v_space is null then raise exception 'NO_FAMILY'; end if;
  if v_role = 'owner' then
    raise exception 'OWNER_TRANSFER_REQUIRED';
  end if;

  insert into public.activity_log (space_id, actor_id, action, entity, entity_id, detail, hash)
  values (v_space, v_user, 'member.leave', 'membership', v_user,
          jsonb_build_object('role', v_role),
          md5(v_user::text || ':leave:' || clock_timestamp()));

  delete from public.membership where space_id = v_space and user_id = v_user;

  if not exists (
    select 1 from public.membership
    where user_id = v_user and invite_status = 'active'
  ) then
    update public.user_profile
      set name = 'Former member', email = null, avatar_url = null, avatar = '👤'
      where id = v_user;

    begin
      perform set_config('storage.allow_delete_query', 'true', true);
      delete from storage.objects
        where bucket_id = 'avatars'
          and (storage.foldername(name))[1] = v_user::text;
    exception when others then
      null;
    end;
  end if;
end;
$$;

revoke all on function public.leave_family() from public, anon;
grant execute on function public.leave_family() to authenticated;

create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = public, storage
as $$
declare
  v_user uuid := auth.uid();
  v_rec record;
  v_owned_spaces int := 0;
  v_member_spaces int := 0;
begin
  if v_user is null then raise exception 'NOT_AUTHENTICATED'; end if;

  -- 1. Refuse if the caller owns any active family space that still has other
  --    active members. They must transfer ownership or remove members first.
  if exists (
    select 1
    from public.membership m
    where m.user_id = v_user
      and m.invite_status = 'active'
      and m.role = 'owner'
      and exists (
        select 1
        from public.membership other
        where other.space_id = m.space_id
          and other.invite_status = 'active'
          and other.user_id <> v_user
      )
  ) then
    raise exception 'OWNERSHIP_TRANSFER_REQUIRED';
  end if;

  -- 2. Leave every active family where the caller is not the owner.
  for v_rec in
    select space_id, role
    from public.membership
    where user_id = v_user
      and invite_status = 'active'
      and role <> 'owner'
  loop
    v_member_spaces := v_member_spaces + 1;
    insert into public.activity_log (space_id, actor_id, action, entity, entity_id, detail, hash)
    values (v_rec.space_id, v_user, 'member.leave', 'membership', v_user,
            jsonb_build_object('role', v_rec.role),
            md5(v_user::text || ':leave:' || v_rec.space_id::text || ':' || clock_timestamp()));
    delete from public.membership
     where space_id = v_rec.space_id and user_id = v_user;
  end loop;

  -- 3. Remove Plus multi-space grant links referencing this user or their
  --    solo-owned spaces before deleting family_space or auth.users.
  if to_regclass('public.family_plus_space_grant') is not null then
    delete from public.family_plus_space_grant
     where created_by = v_user
        or space_id in (
          select space_id from public.membership
          where user_id = v_user and invite_status = 'active' and role = 'owner'
        )
        or source_space_id in (
          select space_id from public.membership
          where user_id = v_user and invite_status = 'active' and role = 'owner'
        );
  end if;

  -- 4. Delete every solo-owned family space and its dependent records.
  for v_rec in
    select space_id
    from public.membership
    where user_id = v_user
      and invite_status = 'active'
      and role = 'owner'
  loop
    v_owned_spaces := v_owned_spaces + 1;

    if to_regclass('public.commitment_payment') is not null then
      delete from public.commitment_payment
       where occurrence_id in (
         select o.id
         from public.commitment_occurrence o
         join public.financial_commitment c on c.id = o.commitment_id
         where c.space_id = v_rec.space_id
       );
    end if;
    if to_regclass('public.financial_commitment') is not null then
      delete from public.financial_commitment where space_id = v_rec.space_id;
    end if;
    if to_regclass('public.transaction_split') is not null then
      delete from public.transaction_split where space_id = v_rec.space_id;
    end if;

    begin
      perform set_config('storage.allow_delete_query', 'true', true);
      delete from storage.objects
        where bucket_id = 'chat-media'
          and (storage.foldername(name))[1] = v_rec.space_id::text;
    exception when others then
      null;
    end;

    delete from public.family_space where id = v_rec.space_id;
  end loop;

  -- Clean up any inactive/left membership rows for this user.
  delete from public.membership where user_id = v_user;

  -- 5. Purge avatar objects (best-effort; storage.allow_delete_query satisfies
  --    Supabase Storage's protect_delete trigger).
  begin
    perform set_config('storage.allow_delete_query', 'true', true);
    delete from storage.objects
      where bucket_id = 'avatars'
        and (storage.foldername(name))[1] = v_user::text;
  exception when others then
    null;
  end;

  -- 6. Revoke sessions and refresh tokens.
  begin
    delete from auth.sessions where user_id = v_user;
    delete from auth.refresh_tokens where user_id = v_user;
  exception when others then
    null;
  end;

  -- 7. Sole owner with no shared-family membership history deletes the auth
  --    identity completely. If retained history in a previously-joined family
  --    still references this user, fall back to tombstoning + neutering.
  if v_owned_spaces > 0 and v_member_spaces = 0 then
    begin
      delete from auth.users where id = v_user;
      return;
    exception when foreign_key_violation then
      null;
    end;
  end if;

  -- 8. Anonymize profile in place and neuter the auth identity so retained
  --    family financial history stays intact while freeing the email address.
  update public.user_profile
    set name = 'Former member', email = null, avatar_url = null, avatar = '👤'
    where id = v_user;

  update auth.users
    set encrypted_password = '!',
        email = 'deleted+' || substr(v_user::text, 1, 8) || '@invalid.mhuri',
        email_confirmed_at = null
    where id = v_user;
end;
$$;

revoke all on function public.delete_own_account() from public, anon;
grant execute on function public.delete_own_account() to authenticated;

-- ── 4. Keep basic text chat + replies free; enhanced features require Plus ──
create or replace function public.guard_family_chat_message()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  has_enhanced_chat boolean;
begin
  if tg_op = 'INSERT' then
    if auth.uid() is null then
      raise exception 'Authentication required';
    end if;
    new.sender_id := auth.uid();
  end if;

  select exists (
    select 1
      from public.family_entitlement e
     where e.space_id = new.space_id
       and e.status in ('active', 'gracePeriod', 'canceledActive')
       and (e.expires_at is null or e.expires_at > now())
       and e.features ? 'enhanced_family_chat'
  ) into has_enhanced_chat;

  if tg_op = 'INSERT' then
    if not has_enhanced_chat and (
      new.media_url is not null or new.media_type is not null or
      new.sticker is not null or new.reference_type is not null or
      new.reference_id is not null or new.reference_title is not null or
      new.reference_meta is not null
    ) then
      raise exception 'PLUS_FEATURE_REQUIRED';
    end if;
  elsif not has_enhanced_chat then
    if new.deleted is distinct from old.deleted then
      if old.deleted
         or not new.deleted
         or new.sender_id is distinct from auth.uid()
         or new.is_system
         or (to_jsonb(new) - 'deleted' - 'updated_at')
            <> (to_jsonb(old) - 'deleted' - 'updated_at') then
        raise exception 'NOT_AUTHORIZED';
      end if;
    elsif (
      new.text is distinct from old.text or
      new.edited_at is distinct from old.edited_at or
      new.media_url is distinct from old.media_url or
      new.media_type is distinct from old.media_type or
      new.sticker is distinct from old.sticker or
      new.reference_type is distinct from old.reference_type or
      new.reference_id is distinct from old.reference_id or
      new.reference_title is distinct from old.reference_title or
      new.reference_meta is distinct from old.reference_meta
    ) then
      raise exception 'PLUS_FEATURE_REQUIRED';
    end if;
  end if;

  new.updated_at := now();
  return new;
end;
$$;

revoke all on function public.guard_family_chat_message()
  from public, anon, authenticated;

do $$
begin
  if to_regprocedure('public.delete_own_account()') is null
     or to_regprocedure('public.leave_family()') is null
     or to_regprocedure('public.audit_shared_family_change()') is null
     or to_regprocedure('public.guard_family_chat_message()') is null then
    raise exception '068 SELF-TEST FAILED: required functions missing';
  end if;
end;
$$;
