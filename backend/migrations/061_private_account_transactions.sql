-- 061: enforce ownership and family scope when transactions use private accounts.
-- Existing shared account and transaction behavior is unchanged.

create or replace function public.guard_private_account_transaction()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  account_space uuid;
  account_sharing text;
  account_owner uuid;
begin
  if new.account_id is null then
    return new;
  end if;

  select a.space_id, coalesce(a.sharing, 'shared'), a.owner_member_id
    into account_space, account_sharing, account_owner
    from public.account a
   where a.id = new.account_id;

  if not found or account_space is distinct from new.space_id then
    raise exception 'ACCOUNT_NOT_IN_FAMILY';
  end if;

  if account_sharing in ('private', 'personal') and (
    auth.uid() is null or account_owner is distinct from auth.uid()
    or new.member_id is distinct from auth.uid()
  ) then
    raise exception 'PRIVATE_ACCOUNT_OWNER_ONLY';
  end if;

  return new;
end;
$$;

-- Let a family member create/update only their own private account. Existing
-- shared account management remains limited to finance administrators.
drop policy if exists private_account_owner_write on public.account;
create policy private_account_owner_write on public.account
  for all to authenticated
  using (
    coalesce(sharing, 'shared') in ('private', 'personal')
    and owner_member_id = (select auth.uid())
    and public.space_role(space_id) in
      ('owner', 'co_parent', 'adult', 'contributor', 'teen')
  )
  with check (
    coalesce(sharing, 'shared') in ('private', 'personal')
    and owner_member_id = (select auth.uid())
    and public.space_role(space_id) in
      ('owner', 'co_parent', 'adult', 'contributor', 'teen')
  );

drop trigger if exists guard_private_account_transaction
  on public.transaction;
create trigger guard_private_account_transaction
before insert or update of account_id, member_id, space_id
on public.transaction
for each row execute function public.guard_private_account_transaction();

-- Transaction audit rows contain amount and currency, so never copy private
-- transaction details into the family-wide activity log.
create or replace function public.audit_transaction_changes()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  action_name text;
  account_sharing text;
begin
  if tg_op = 'UPDATE' then
    if old.account_id is not null then
      select coalesce(a.sharing, 'shared') into account_sharing
        from public.account a where a.id = old.account_id;
      if account_sharing in ('private', 'personal') then
        return new;
      end if;
      account_sharing := null;
    end if;
  end if;
  if new.account_id is not null then
    select coalesce(a.sharing, 'shared') into account_sharing
      from public.account a where a.id = new.account_id;
    if account_sharing in ('private', 'personal') then
      return new;
    end if;
  end if;

  if tg_op = 'INSERT' then
    action_name := 'tx.create';
  elsif new.deleted_at is not null and old.deleted_at is null then
    action_name := 'tx.delete';
  elsif new is distinct from old then
    action_name := 'tx.update';
  else
    return new;
  end if;

  insert into public.activity_log
    (space_id, actor_id, action, entity, entity_id, detail, hash)
  values (
    new.space_id,
    coalesce(auth.uid(), new.updated_by, new.created_by),
    action_name,
    'transaction',
    new.id,
    jsonb_build_object(
      'amount_minor', new.amount_minor,
      'currency', new.currency,
      'member_id', new.member_id
    ),
    md5(new.id::text || ':' || action_name || ':' || clock_timestamp())
  );
  return new;
end;
$$;

-- Account audit metadata can expose private account names. Keep audit events
-- for shared account changes and omit private-account lifecycle events.
drop trigger if exists trg_audit_account_complete on public.account;
create trigger trg_audit_account_shared_insert_update
after insert or update on public.account
for each row
when (coalesce(new.sharing, 'shared') not in ('private', 'personal'))
execute function public.audit_shared_family_change();
create trigger trg_audit_account_shared_delete
after delete on public.account
for each row
when (coalesce(old.sharing, 'shared') not in ('private', 'personal'))
execute function public.audit_shared_family_change();

-- A private transaction must not be attached to shared budget allocations.
drop policy if exists transaction_split_private_account on public.transaction_split;
create policy transaction_split_private_account on public.transaction_split
  as restrictive
  for all to authenticated
  using (
    exists (
      select 1
        from public.transaction t
        left join public.account a on a.id = t.account_id
       where t.id = transaction_split.transaction_id
         and coalesce(a.sharing, 'shared') not in ('private', 'personal')
    )
  )
  with check (
    exists (
      select 1
        from public.transaction t
        left join public.account a on a.id = t.account_id
       where t.id = transaction_split.transaction_id
         and coalesce(a.sharing, 'shared') not in ('private', 'personal')
    )
  );

do $$
begin
  if not exists (
    select 1 from pg_trigger
     where tgname = 'guard_private_account_transaction'
       and not tgisinternal
  ) then
    raise exception '061 SELF-TEST FAILED: private transaction ownership guard missing';
  end if;
  if not exists (
    select 1 from pg_policies
     where schemaname = 'public'
       and tablename = 'transaction_split'
       and policyname = 'transaction_split_private_account'
       and permissive = 'RESTRICTIVE'
  ) then
    raise exception '061 SELF-TEST FAILED: private transaction split policy missing';
  end if;
end;
$$;
