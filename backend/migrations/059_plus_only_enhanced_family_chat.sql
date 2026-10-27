-- 059: free chat remains text plus replies; enhanced chat tools require Plus.
-- Existing Plus entitlements receive the new capability without changing
-- their status or expiry. Existing messages and attachments remain readable.

update public.family_entitlement
   set features = features || '["enhanced_family_chat"]'::jsonb,
       updated_at = now()
 where status in ('active', 'gracePeriod', 'canceledActive')
   and (expires_at is null or expires_at > now())
   and not (features ? 'enhanced_family_chat');

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

-- Keep historical photos readable to family members, but require Plus for
-- every new upload. Expiration therefore leaves existing media in place.
drop policy if exists chat_media_insert on storage.objects;
create policy chat_media_insert on storage.objects for insert to authenticated
with check (
  bucket_id = 'chat-media' and
  public.space_role(((storage.foldername(name))[1])::uuid) is not null and
  owner_id = auth.uid()::text and
  exists (
    select 1 from public.family_entitlement e
     where e.space_id = ((storage.foldername(name))[1])::uuid
       and e.status in ('active', 'gracePeriod', 'canceledActive')
       and (e.expires_at is null or e.expires_at > now())
       and e.features ? 'enhanced_family_chat'
  )
);

create or replace function public.vote_family_chat_poll(
  p_poll_id uuid,
  p_option_indexes integer[]
) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  poll_row public.family_chat_poll%rowtype;
  caller_role text;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into poll_row from public.family_chat_poll
   where id = p_poll_id for update;
  if not found then raise exception 'FAMILY_ACCESS_DENIED'; end if;
  caller_role := public.space_role(poll_row.space_id);
  if caller_role is null or caller_role = 'viewer' then
    raise exception 'FAMILY_ACCESS_DENIED';
  end if;
  if not exists (
    select 1 from public.family_entitlement e
     where e.space_id = poll_row.space_id
       and e.status in ('active', 'gracePeriod', 'canceledActive')
       and (e.expires_at is null or e.expires_at > now())
       and e.features ? 'family_polls_pins'
  ) then raise exception 'PLUS_FEATURE_REQUIRED'; end if;
  if poll_row.closed_at is not null or
     (poll_row.closes_at is not null and poll_row.closes_at <= now()) then
    raise exception 'POLL_CLOSED';
  end if;
  if p_option_indexes is null or cardinality(p_option_indexes) < 1
     or cardinality(p_option_indexes) > 6
     or (not poll_row.allow_multiple and cardinality(p_option_indexes) <> 1)
     or array_position(p_option_indexes, null) is not null
     or exists (select 1 from unnest(p_option_indexes) as choices(option_index)
                 where option_index < 0 or option_index >= jsonb_array_length(poll_row.options))
     or cardinality(p_option_indexes) <>
        (select count(distinct option_index)
           from unnest(p_option_indexes) as choices(option_index)) then
    raise exception 'INVALID_POLL_VOTE';
  end if;
  insert into public.family_chat_poll_vote(
    poll_id, space_id, user_id, option_indexes, updated_at
  ) values (p_poll_id, poll_row.space_id, auth.uid(), p_option_indexes, now())
  on conflict (poll_id, user_id) do update
    set option_indexes = excluded.option_indexes, updated_at = now();
end;
$$;

create or replace function public.close_family_chat_poll(p_poll_id uuid)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare
  poll_row public.family_chat_poll%rowtype;
  caller_role text;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into poll_row from public.family_chat_poll
   where id = p_poll_id for update;
  if not found then raise exception 'FAMILY_ACCESS_DENIED'; end if;
  caller_role := public.space_role(poll_row.space_id);
  if caller_role is null then raise exception 'FAMILY_ACCESS_DENIED'; end if;
  if poll_row.created_by <> auth.uid()
     and caller_role not in ('owner', 'co_parent', 'adult') then
    raise exception 'NOT_AUTHORIZED';
  end if;
  if not exists (
    select 1 from public.family_entitlement e
     where e.space_id = poll_row.space_id
       and e.status in ('active', 'gracePeriod', 'canceledActive')
       and (e.expires_at is null or e.expires_at > now())
       and e.features ? 'family_polls_pins'
  ) then raise exception 'PLUS_FEATURE_REQUIRED'; end if;
  update public.family_chat_poll
     set closed_at = coalesce(closed_at, now())
   where id = p_poll_id;
end;
$$;

create or replace function public.set_family_chat_pin(
  p_space_id uuid,
  p_message_id uuid,
  p_pinned boolean
) returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare
  caller_role text;
  pin_owner uuid;
  msg_sender uuid;
begin
  caller_role := public.space_role(p_space_id);
  if auth.uid() is null or caller_role is null or caller_role = 'viewer' then
    raise exception 'FAMILY_ACCESS_DENIED';
  end if;
  if p_pinned and not exists (
    select 1 from public.family_entitlement e
     where e.space_id = p_space_id
       and e.status in ('active', 'gracePeriod', 'canceledActive')
       and (e.expires_at is null or e.expires_at > now())
       and e.features ? 'family_polls_pins'
  ) then raise exception 'PLUS_FEATURE_REQUIRED'; end if;
  if not p_pinned then
    select pinned_by into pin_owner
      from public.family_chat_pin
     where space_id = p_space_id and message_id = p_message_id
       for update;
    if not found then return; end if;
    select sender_id into msg_sender
      from public.family_chat_message
     where id = p_message_id and space_id = p_space_id;
    if caller_role not in ('owner', 'co_parent', 'adult')
       and pin_owner is distinct from auth.uid()
       and msg_sender is distinct from auth.uid() then
      raise exception 'NOT_AUTHORIZED';
    end if;
    delete from public.family_chat_pin
     where space_id = p_space_id and message_id = p_message_id;
    return;
  end if;
  if not exists (select 1 from public.family_chat_message
                  where id = p_message_id and space_id = p_space_id and not deleted) then
    raise exception 'MESSAGE_NOT_FOUND';
  end if;
  if not exists (select 1 from public.family_chat_pin
                  where space_id = p_space_id and message_id = p_message_id)
     and (select count(*) from public.family_chat_pin where space_id = p_space_id) >= 20 then
    raise exception 'PIN_LIMIT_REACHED';
  end if;
  insert into public.family_chat_pin(space_id, message_id, pinned_by)
  values (p_space_id, p_message_id, auth.uid())
  on conflict (space_id, message_id) do nothing;
end;
$$;

revoke all on function public.vote_family_chat_poll(uuid, integer[]) from public, anon;
grant execute on function public.vote_family_chat_poll(uuid, integer[]) to authenticated;
revoke all on function public.close_family_chat_poll(uuid) from public, anon;
grant execute on function public.close_family_chat_poll(uuid) to authenticated;
revoke all on function public.set_family_chat_pin(uuid, uuid, boolean) from public, anon;
grant execute on function public.set_family_chat_pin(uuid, uuid, boolean) to authenticated;
