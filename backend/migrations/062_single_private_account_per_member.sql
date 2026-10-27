-- 062: a member may keep one private account in each family space.
-- Serialize concurrent account creation per owner so two devices cannot race.

create or replace function public.enforce_single_private_account()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if coalesce(new.sharing, 'shared') not in ('private', 'personal')
     or new.owner_member_id is null then
    return new;
  end if;

  if tg_op = 'UPDATE'
     and old.space_id is not distinct from new.space_id
     and old.owner_member_id is not distinct from new.owner_member_id
     and old.sharing is not distinct from new.sharing then
    return new;
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(
      'private-account:' || new.space_id::text || ':' ||
      new.owner_member_id::text,
      0
    )
  );

  if exists (
    select 1
      from public.account a
     where a.space_id = new.space_id
       and a.owner_member_id = new.owner_member_id
       and coalesce(a.sharing, 'shared') in ('private', 'personal')
       and a.id <> new.id
  ) then
    raise exception using
      errcode = '23505',
      message = 'PRIVATE_ACCOUNT_LIMIT_REACHED';
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_single_private_account on public.account;
create trigger enforce_single_private_account
before insert or update of space_id, sharing, owner_member_id
on public.account
for each row execute function public.enforce_single_private_account();

do $$
begin
  if not exists (
    select 1 from pg_trigger
     where tgname = 'enforce_single_private_account'
       and not tgisinternal
  ) then
    raise exception '062 SELF-TEST FAILED: single private account guard missing';
  end if;
end;
$$;
