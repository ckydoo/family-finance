-- 049: deterministic commitments, generated occurrences, and links to
-- existing expense transactions. Additive only; no production execution is
-- performed by this repository change.

create table if not exists public.financial_commitment (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.family_space(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 120),
  amount_minor bigint not null check (amount_minor > 0),
  currency text not null check (
    currency in ('USD', 'EUR', 'GBP', 'ZAR', 'CAD', 'AUD', 'KES', 'NGN', 'INR', 'ZWG')
  ),
  first_due_date timestamptz not null,
  recurrence text not null check (
    recurrence in ('oneTime', 'weekly', 'fortnightly', 'monthly', 'quarterly', 'yearly')
  ),
  created_by uuid not null references auth.users(id),
  envelope_id uuid references public.envelope(id) on delete set null,
  status text not null default 'active' check (
    status in ('active', 'paused', 'ended', 'archived')
  ),
  end_date timestamptz,
  reminder_days_before jsonb not null default '[3]'::jsonb check (
    jsonb_typeof(reminder_days_before) = 'array'
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_date is null or end_date >= first_due_date)
);

create table if not exists public.commitment_occurrence (
  id uuid primary key default gen_random_uuid(),
  commitment_id uuid not null references public.financial_commitment(id) on delete cascade,
  occurrence_key text not null check (occurrence_key ~ '^\d{4}-\d{2}-\d{2}$'),
  due_date timestamptz not null,
  amount_minor bigint not null check (amount_minor > 0),
  currency text not null check (
    currency in ('USD', 'EUR', 'GBP', 'ZAR', 'CAD', 'AUD', 'KES', 'NGN', 'INR', 'ZWG')
  ),
  status text not null default 'scheduled' check (
    status in ('scheduled', 'upcoming', 'partiallyPaid', 'paid', 'skipped', 'canceled')
  ),
  created_at timestamptz not null default now(),
  unique (commitment_id, occurrence_key)
);

create table if not exists public.commitment_payment (
  id uuid primary key default gen_random_uuid(),
  occurrence_id uuid not null references public.commitment_occurrence(id) on delete cascade,
  transaction_id uuid not null references public.transaction(id) on delete restrict,
  amount_minor bigint not null check (amount_minor > 0),
  currency text not null check (
    currency in ('USD', 'EUR', 'GBP', 'ZAR', 'CAD', 'AUD', 'KES', 'NGN', 'INR', 'ZWG')
  ),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

create index if not exists financial_commitment_space_status_idx
  on public.financial_commitment(space_id, status);
create index if not exists commitment_occurrence_due_idx
  on public.commitment_occurrence(commitment_id, due_date, status);
create index if not exists commitment_payment_occurrence_idx
  on public.commitment_payment(occurrence_id, created_at);
create index if not exists commitment_payment_transaction_idx
  on public.commitment_payment(transaction_id);

create or replace function public.validate_financial_commitment_row()
returns trigger language plpgsql set search_path = public as $$
declare caller_role text;
begin
  caller_role := public.space_role(new.space_id);
  if caller_role is null or caller_role = 'viewer' then
    raise exception 'FAMILY_ACCESS_DENIED';
  end if;
  if tg_op = 'INSERT' and new.created_by <> auth.uid() then
    raise exception 'AUTHOR_MISMATCH';
  end if;
  if tg_op = 'UPDATE' and new.created_by <> old.created_by then
    raise exception 'AUTHOR_IMMUTABLE';
  end if;
  if new.envelope_id is not null and not exists (
    select 1 from public.envelope e
     where e.id = new.envelope_id and e.space_id = new.space_id
  ) then raise exception 'ENVELOPE_SPACE_MISMATCH'; end if;
  if exists (
    select 1 from jsonb_array_elements(new.reminder_days_before) value
     where jsonb_typeof(value) <> 'number'
        or (value::text)::integer not between 0 and 365
  ) then raise exception 'INVALID_REMINDER_DAYS'; end if;
  new.updated_at := now();
  return new;
end; $$;

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
  return new;
end; $$;

create or replace function public.validate_commitment_payment_row()
returns trigger language plpgsql set search_path = public as $$
declare occurrence public.commitment_occurrence%rowtype;
declare commitment public.financial_commitment%rowtype;
declare expense public.transaction%rowtype;
declare occurrence_paid bigint;
declare transaction_allocated bigint;
declare caller_role text;
begin
  if tg_op = 'INSERT' and new.created_by <> auth.uid() then
    raise exception 'AUTHOR_MISMATCH';
  end if;
  if tg_op = 'UPDATE' and new.created_by <> old.created_by then
    raise exception 'AUTHOR_IMMUTABLE';
  end if;
  select o.* into occurrence from public.commitment_occurrence o
   where o.id = new.occurrence_id;
  select c.* into commitment from public.financial_commitment c
   where c.id = occurrence.commitment_id;
  select t.* into expense from public.transaction t
   where t.id = new.transaction_id and t.deleted_at is null;
  caller_role := public.space_role(commitment.space_id);
  if commitment.id is null or expense.id is null
     or commitment.space_id <> expense.space_id
     or caller_role is null or caller_role = 'viewer' then
    raise exception 'INVALID_PAYMENT_LINK';
  end if;
  if expense.type <> 'expense' then raise exception 'EXPENSE_REQUIRED'; end if;
  if new.currency <> occurrence.currency or new.currency <> expense.currency then
    raise exception 'CURRENCY_MISMATCH';
  end if;
  select coalesce(sum(p.amount_minor), 0) into occurrence_paid
    from public.commitment_payment p where p.occurrence_id = new.occurrence_id
      and p.id <> new.id;
  select coalesce(sum(p.amount_minor), 0) into transaction_allocated
    from public.commitment_payment p where p.transaction_id = new.transaction_id
      and p.id <> new.id;
  if occurrence_paid + new.amount_minor > occurrence.amount_minor then
    raise exception 'OCCURRENCE_OVERPAID';
  end if;
  if transaction_allocated + new.amount_minor > expense.amount_minor then
    raise exception 'TRANSACTION_OVERALLOCATED';
  end if;
  return new;
end; $$;

drop trigger if exists financial_commitment_validate on public.financial_commitment;
create trigger financial_commitment_validate before insert or update
  on public.financial_commitment for each row
  execute function public.validate_financial_commitment_row();
drop trigger if exists commitment_occurrence_validate on public.commitment_occurrence;
create trigger commitment_occurrence_validate before insert or update
  on public.commitment_occurrence for each row
  execute function public.validate_commitment_occurrence_row();
drop trigger if exists commitment_payment_validate on public.commitment_payment;
create trigger commitment_payment_validate before insert or update
  on public.commitment_payment for each row
  execute function public.validate_commitment_payment_row();

alter table public.financial_commitment enable row level security;
alter table public.commitment_occurrence enable row level security;
alter table public.commitment_payment enable row level security;

drop policy if exists financial_commitment_member_all on public.financial_commitment;
drop policy if exists financial_commitment_select on public.financial_commitment;
drop policy if exists financial_commitment_write on public.financial_commitment;
create policy financial_commitment_select on public.financial_commitment
  for select to authenticated using (public.space_role(space_id) is not null);
create policy financial_commitment_write on public.financial_commitment
  for all to authenticated
  using (
    public.space_role(space_id) is not null
    and public.space_role(space_id) <> 'viewer'
  )
  with check (
    public.space_role(space_id) is not null
    and public.space_role(space_id) <> 'viewer'
  );

drop policy if exists commitment_occurrence_member_all on public.commitment_occurrence;
drop policy if exists commitment_occurrence_select on public.commitment_occurrence;
drop policy if exists commitment_occurrence_write on public.commitment_occurrence;
create policy commitment_occurrence_select on public.commitment_occurrence
  for select to authenticated using (exists (
    select 1 from public.financial_commitment c where c.id = commitment_id
      and public.space_role(c.space_id) is not null
  ));
create policy commitment_occurrence_write on public.commitment_occurrence
  for all to authenticated using (exists (
    select 1 from public.financial_commitment c where c.id = commitment_id
      and public.space_role(c.space_id) is not null
      and public.space_role(c.space_id) <> 'viewer'
  )) with check (exists (
    select 1 from public.financial_commitment c where c.id = commitment_id
      and public.space_role(c.space_id) is not null
      and public.space_role(c.space_id) <> 'viewer'
  ));

drop policy if exists commitment_payment_member_all on public.commitment_payment;
drop policy if exists commitment_payment_select on public.commitment_payment;
drop policy if exists commitment_payment_write on public.commitment_payment;
create policy commitment_payment_select on public.commitment_payment
  for select to authenticated using (exists (
    select 1 from public.commitment_occurrence o
    join public.financial_commitment c on c.id = o.commitment_id
    where o.id = occurrence_id and public.space_role(c.space_id) is not null
  ));
create policy commitment_payment_write on public.commitment_payment
  for all to authenticated using (exists (
    select 1 from public.commitment_occurrence o
    join public.financial_commitment c on c.id = o.commitment_id
    where o.id = occurrence_id
      and public.space_role(c.space_id) is not null
      and public.space_role(c.space_id) <> 'viewer'
  )) with check (exists (
    select 1 from public.commitment_occurrence o
    join public.financial_commitment c on c.id = o.commitment_id
    where o.id = occurrence_id
      and public.space_role(c.space_id) is not null
      and public.space_role(c.space_id) <> 'viewer'
  ));

grant select, insert, update, delete on public.financial_commitment,
  public.commitment_occurrence, public.commitment_payment to authenticated;
