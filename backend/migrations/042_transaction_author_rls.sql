-- 042: Keep transaction subject and authenticated author distinct.
--
-- Parents can legitimately record a transaction for a child (including the
-- approved-proposal flow). `member_id` identifies whose transaction it is;
-- `created_by` identifies the authenticated author.

create or replace function public.set_transaction_authors() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    new.created_by := auth.uid();
  end if;
  new.updated_by := auth.uid();
  return new;
end;
$$;

drop trigger if exists trg_transaction_authors on public.transaction;
create trigger trg_transaction_authors
before insert or update on public.transaction
for each row execute function public.set_transaction_authors();

drop policy if exists tx_write on public.transaction;
drop policy if exists tx_insert on public.transaction;
create policy tx_insert on public.transaction for insert with check (
  created_by = auth.uid()
  and (
    public.can_manage_finances(space_id)
    or (
      member_id = auth.uid()
      and (
        public.space_role(space_id) in ('owner','co_parent','adult','contributor')
        or (public.space_role(space_id) = 'teen'
            and public.role_perm(space_id,'teen_transactions',true))
        or (public.space_role(space_id) = 'kid'
            and public.role_perm(space_id,'child_transactions',false))
      )
    )
  )
);

revoke all on function public.set_transaction_authors() from public, anon;
grant execute on function public.set_transaction_authors() to authenticated;
