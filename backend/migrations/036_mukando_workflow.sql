alter table public.mukando
  add column if not exists participant_ids uuid[] not null default '{}';

create table if not exists public.mukando_payment (
  id uuid primary key,
  space_id uuid not null references public.family_space(id) on delete cascade,
  round_no integer not null check (round_no >= 1),
  member_id uuid not null references public.user_profile(id),
  recorded_by uuid not null references public.user_profile(id),
  amount_minor bigint not null check (amount_minor > 0),
  currency text not null check (currency in ('USD','ZWG')),
  paid_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (space_id, round_no, member_id)
);

alter table public.mukando_payment enable row level security;
create policy mukando_payment_read on public.mukando_payment for select
  using (public.space_role(space_id) is not null);
create policy mukando_payment_insert on public.mukando_payment for insert
  with check (
    public.can_manage_finances(space_id)
    or (member_id = auth.uid() and recorded_by = auth.uid())
  );
create policy mukando_payment_update on public.mukando_payment for update
  using (public.can_manage_finances(space_id))
  with check (public.can_manage_finances(space_id));
grant select, insert, update on public.mukando_payment to authenticated;

drop trigger if exists trg_mukando_payment_updated on public.mukando_payment;
create trigger trg_mukando_payment_updated before update on public.mukando_payment
for each row execute function public.set_updated_at();

create or replace function public.audit_mukando_payment() returns trigger
language plpgsql security definer set search_path=public as $$
begin
  insert into public.activity_log(space_id, actor_id, action, entity, entity_id, detail, hash)
  values(new.space_id, coalesce(auth.uid(), new.recorded_by), 'mukando.payment',
    'mukando_payment', new.id,
    jsonb_build_object('round',new.round_no,'member_id',new.member_id,
      'amount_minor',new.amount_minor,'currency',new.currency),
    md5(new.id::text||':mukando-payment:'||clock_timestamp()));
  return new;
end $$;
drop trigger if exists trg_audit_mukando_payment on public.mukando_payment;
create trigger trg_audit_mukando_payment after insert on public.mukando_payment
for each row execute function public.audit_mukando_payment();
