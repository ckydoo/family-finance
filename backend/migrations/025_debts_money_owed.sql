-- 025: family debts, money owed and immutable partial repayments.
create table if not exists public.family_debt (
  id uuid primary key, space_id uuid not null references public.family_space(id) on delete cascade,
  name text not null, direction text not null check(direction in ('iOwe','owedToMe','familyLoan')),
  principal_minor bigint not null check(principal_minor > 0), currency text not null,
  counterparty_member_id uuid references public.user_profile(id), due_date timestamptz,
  status text not null default 'active' check(status in ('active','settled','archived')),
  created_by uuid not null references public.user_profile(id),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.debt_repayment (
  id uuid primary key, debt_id uuid not null references public.family_debt(id) on delete cascade,
  member_id uuid not null references public.user_profile(id), amount_minor bigint not null check(amount_minor > 0),
  currency text not null, paid_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.family_debt enable row level security;
alter table public.debt_repayment enable row level security;
drop policy if exists family_debt_read on public.family_debt;
create policy family_debt_read on public.family_debt for select using(public.space_role(space_id) is not null);
drop policy if exists family_debt_write on public.family_debt;
create policy family_debt_write on public.family_debt for all using(public.is_adult(space_id)) with check(public.is_adult(space_id));
drop policy if exists debt_repayment_read on public.debt_repayment;
create policy debt_repayment_read on public.debt_repayment for select using(exists(select 1 from public.family_debt d where d.id=debt_id and public.space_role(d.space_id) is not null));
drop policy if exists debt_repayment_insert on public.debt_repayment;
create policy debt_repayment_insert on public.debt_repayment for insert with check(exists(select 1 from public.family_debt d where d.id=debt_id and public.is_adult(d.space_id)));
drop trigger if exists trg_family_debt_updated on public.family_debt;
create trigger trg_family_debt_updated before update on public.family_debt for each row execute function public.set_updated_at();
grant select,insert,update on public.family_debt to authenticated;
grant select,insert on public.debt_repayment to authenticated;

create or replace function public.audit_debt_repayment() returns trigger language plpgsql security definer set search_path=public as $$
declare v_space uuid;
begin
  select space_id into v_space from public.family_debt where id=new.debt_id;
  insert into public.activity_log(space_id,actor_id,action,entity,entity_id,detail,hash)
  values(v_space,coalesce(auth.uid(),new.member_id),'debt.repayment','debt_repayment',new.id,
    jsonb_build_object('debt_id',new.debt_id,'amount_minor',new.amount_minor,'currency',new.currency),
    md5(new.id::text||':debt:'||clock_timestamp()));
  return new;
end $$;
drop trigger if exists trg_audit_debt_repayment on public.debt_repayment;
create trigger trg_audit_debt_repayment after insert on public.debt_repayment for each row execute function public.audit_debt_repayment();
