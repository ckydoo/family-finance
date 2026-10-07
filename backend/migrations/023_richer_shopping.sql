-- 023: assignments, actual prices and purchaser attribution for shopping.

alter table public.list_item
  add column if not exists actual_price_minor bigint,
  add column if not exists actual_currency text,
  add column if not exists purchased_by uuid references public.user_profile(id);

alter table public.list_item drop constraint if exists list_item_actual_price_check;
alter table public.list_item add constraint list_item_actual_price_check
  check (actual_price_minor is null or actual_price_minor >= 0);

alter table public.list_item drop constraint if exists list_item_actual_currency_check;
alter table public.list_item add constraint list_item_actual_currency_check
  check (
    (actual_price_minor is null and actual_currency is null) or
    (actual_price_minor is not null and actual_currency is not null)
  );

-- assigned_to already exists in the baseline; keep assignments inside the
-- same family even when a crafted API request bypasses the app.
create or replace function public.guard_list_item_people() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_space uuid;
begin
  select space_id into v_space from public.shopping_list where id = new.list_id;
  if new.assigned_to is not null and not exists (
    select 1 from public.membership where space_id = v_space
      and user_id = new.assigned_to and invite_status = 'active'
  ) then raise exception 'ASSIGNEE_NOT_IN_FAMILY'; end if;
  if new.purchased_by is not null and not exists (
    select 1 from public.membership where space_id = v_space
      and user_id = new.purchased_by and invite_status = 'active'
  ) then raise exception 'PURCHASER_NOT_IN_FAMILY'; end if;
  return new;
end; $$;

drop trigger if exists trg_guard_list_item_people on public.list_item;
create trigger trg_guard_list_item_people
before insert or update on public.list_item
for each row execute function public.guard_list_item_people();
