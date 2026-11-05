-- 067: family chat is a Mhuri Plus feature, including ordinary text messages.
-- Existing conversations remain readable at the database boundary. The app
-- gates the whole conversation for Free families. Authors may still delete
-- their own historical messages after downgrade; editing and all new sends
-- require an active enhanced_family_chat entitlement.

create or replace function public.guard_family_chat_message()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  has_family_chat boolean;
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
  ) into has_family_chat;

  if tg_op = 'INSERT' then
    -- Text, replies, media, stickers, references, and client-created system
    -- updates all use the same premium family-chat write boundary.
    if not has_family_chat then
      raise exception 'PLUS_FEATURE_REQUIRED';
    end if;
  elsif not has_family_chat then
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
  if to_regprocedure('public.guard_family_chat_message()') is null then
    raise exception '067 SELF-TEST FAILED: family chat guard missing';
  end if;
end;
$$;
