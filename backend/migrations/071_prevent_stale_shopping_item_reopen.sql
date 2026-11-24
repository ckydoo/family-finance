-- 070: prevent stale clients from reopening completed shopping items.
-- A deliberate restart of a checked-out item clears its purchase fields in
-- the same mutation. A stale update that only rolls state back is rejected.

create or replace function public.guard_bulk_shopping_regression()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_regressions integer;
begin
  select count(*)
    into v_regressions
    from old_rows old_row
    join new_rows new_row using (id)
   where old_row.deleted_at is null
     and new_row.deleted_at is null
     and old_row.state = 'done'
     and new_row.state = 'tobuy'
     and not (
       old_row.checked_out = true
       and new_row.checked_out = false
       and new_row.actual_price_minor is null
       and new_row.purchased_by is null
     );

  if v_regressions > 0 then
    raise exception using
      errcode = '40001',
      message = 'STALE_SHOPPING_ITEM_REOPEN_REJECTED',
      detail = format(
        'Rejected %s completed shopping items regressing to to-buy without an explicit new cycle.',
        v_regressions
      ),
      hint = 'Refresh the family list and retry only an intentional new shopping cycle.';
  end if;
  return null;
end;
$$;

drop trigger if exists trg_guard_bulk_shopping_regression
  on public.list_item;
create trigger trg_guard_bulk_shopping_regression
after update on public.list_item
referencing old table as old_rows new table as new_rows
for each statement execute function public.guard_bulk_shopping_regression();

revoke all on function public.guard_bulk_shopping_regression()
  from public, anon, authenticated;
