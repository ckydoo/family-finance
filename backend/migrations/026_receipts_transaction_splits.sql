-- 026: receipt references and exact multi-budget expense allocations.
create table if not exists public.transaction_split (
  id uuid primary key, space_id uuid not null references public.family_space(id) on delete cascade,
  transaction_id uuid not null references public.transaction(id) on delete cascade,
  envelope_id uuid not null references public.envelope(id),
  amount_minor bigint not null check(amount_minor > 0), currency text not null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(transaction_id,envelope_id)
);
alter table public.transaction_split enable row level security;
drop policy if exists transaction_split_read on public.transaction_split;
create policy transaction_split_read on public.transaction_split for select using(public.space_role(space_id) is not null);
drop policy if exists transaction_split_write on public.transaction_split;
create policy transaction_split_write on public.transaction_split for all using(public.is_adult(space_id)) with check(public.is_adult(space_id));
grant select,insert,update on public.transaction_split to authenticated;
drop trigger if exists trg_transaction_split_updated on public.transaction_split;
create trigger trg_transaction_split_updated before update on public.transaction_split for each row execute function public.set_updated_at();

create or replace function public.guard_transaction_split() returns trigger language plpgsql security definer set search_path=public as $$
declare v_tx_space uuid; v_env_space uuid;
begin
  select space_id into v_tx_space from public.transaction where id=new.transaction_id;
  select space_id into v_env_space from public.envelope where id=new.envelope_id;
  if v_tx_space is null or v_tx_space<>new.space_id or v_env_space<>new.space_id then
    raise exception 'SPLIT_CROSS_FAMILY';
  end if;
  return new;
end $$;
drop trigger if exists trg_guard_transaction_split on public.transaction_split;
create trigger trg_guard_transaction_split before insert or update on public.transaction_split for each row execute function public.guard_transaction_split();
