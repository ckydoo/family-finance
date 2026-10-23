-- 051: Post-050 security and entitlement alignment
-- 1. Harden account personal/private privacy policies (handle 'private' per account_sharing_check)
-- 2. Prevent non-owner writes to private accounts
-- 3. Prevent transaction & split leakage for private account transactions
-- 4. Drop legacy http_request webhook trigger containing obsolete hardcoded bearer token
-- 5. Revoke anon permissions on commitment tables and chat RPCs
-- Forward-only and idempotent.

-- 1. Private account read privacy (handle both 'private' and 'personal' values)
drop policy if exists account_personal_privacy on public.account;
create policy account_personal_privacy on public.account
  as restrictive
  for select to authenticated
  using (
    coalesce(sharing, 'shared') not in ('personal', 'private')
    or owner_member_id = (select auth.uid())
  );

-- 2. Private account write privacy (only owner can modify/delete or create their private account)
drop policy if exists account_personal_write_privacy on public.account;
create policy account_personal_write_privacy on public.account
  as restrictive
  for all to authenticated
  using (
    coalesce(sharing, 'shared') not in ('personal', 'private')
    or owner_member_id = (select auth.uid())
  )
  with check (
    coalesce(sharing, 'shared') not in ('personal', 'private')
    or owner_member_id = (select auth.uid())
  );

-- 3. Private account transaction privacy (read & write boundary)
drop policy if exists tx_personal_account_privacy on public.transaction;
create policy tx_personal_account_privacy on public.transaction
  as restrictive
  for all to authenticated
  using (
    account_id is null
    or exists (
      select 1 from public.account a
       where a.id = transaction.account_id
         and a.space_id = transaction.space_id
         and (
           coalesce(a.sharing, 'shared') not in ('personal', 'private')
           or a.owner_member_id = (select auth.uid())
         )
    )
  )
  with check (
    account_id is null
    or exists (
      select 1 from public.account a
       where a.id = transaction.account_id
         and a.space_id = transaction.space_id
         and (
           coalesce(a.sharing, 'shared') not in ('personal', 'private')
           or a.owner_member_id = (select auth.uid())
         )
    )
  );

-- 4. Prevent private transaction split leakage
drop policy if exists tx_split_personal_account_privacy on public.transaction_split;
create policy tx_split_personal_account_privacy on public.transaction_split
  as restrictive
  for select to authenticated
  using (
    exists (
      select 1 from public.transaction t
       where t.id = transaction_split.transaction_id
    )
  );

-- 5. Drop legacy dashboard trigger containing hardcoded token on activity_log
-- (vault-backed trg_activity_push handles notifications securely via dispatch_activity_push)
drop trigger if exists "important-family-push" on public.activity_log;

-- 6. Revoke anon table privileges from commitments tables
revoke all on public.financial_commitment from anon;
revoke all on public.commitment_occurrence from anon;
revoke all on public.commitment_payment from anon;

-- 7. Restrict chat RPC execute privileges to authenticated only
revoke execute on function public.create_family_chat_poll(uuid, text, jsonb, boolean, timestamptz) from anon, public;
grant execute on function public.create_family_chat_poll(uuid, text, jsonb, boolean, timestamptz) to authenticated;

revoke execute on function public.vote_family_chat_poll(uuid, integer[]) from anon, public;
grant execute on function public.vote_family_chat_poll(uuid, integer[]) to authenticated;

revoke execute on function public.close_family_chat_poll(uuid) from anon, public;
grant execute on function public.close_family_chat_poll(uuid) to authenticated;

revoke execute on function public.set_family_chat_pin(uuid, uuid, boolean) from anon, public;
grant execute on function public.set_family_chat_pin(uuid, uuid, boolean) to authenticated;

revoke execute on function public.search_family_chat_messages(uuid, text, uuid, timestamptz, timestamptz, text, integer, integer) from anon, public;
grant execute on function public.search_family_chat_messages(uuid, text, uuid, timestamptz, timestamptz, text, integer, integer) to authenticated;

-- 8. Add updated_at to commitment_occurrence and commitment_payment for sync cursors
alter table public.commitment_occurrence
  add column if not exists updated_at timestamptz not null default now();

alter table public.commitment_payment
  add column if not exists updated_at timestamptz not null default now();

create or replace function public.validate_commitment_occurrence_row()
returns trigger language plpgsql set search_path = public as $$
declare parent public.financial_commitment%rowtype;
declare caller_role text;
begin
  select * into parent from public.financial_commitment where id = new.commitment_id;
  caller_role := public.space_role(parent.space_id);
  if not found or caller_role is null or caller_role = 'viewer' then
    raise exception 'FAMILY_ACCESS_DENIED';
  end if;
  if new.currency <> parent.currency then raise exception 'CURRENCY_MISMATCH'; end if;
  new.updated_at := now();
  return new;
end; $$;


