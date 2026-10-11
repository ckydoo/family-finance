-- Opening account balances contribute to the Family Pool, so they must use
-- the same incremental-sync contract as the rest of the shared ledger.
alter table public.account
  add column if not exists updated_at timestamptz not null default now();

drop trigger if exists trg_account_updated on public.account;
create trigger trg_account_updated
before update on public.account
for each row execute function public.set_updated_at();
