-- 066: reject stale bulk regressions at the authoritative database boundary.
--
-- A client may intentionally restart one purchased item for a new shopping
-- cycle. A stale device must never reset an entire completed list in one
-- merge-upsert. This statement-level guard runs inside the same transaction
-- as the PostgREST batch, so any detected regression rejects the whole batch.

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
     and new_row.state = 'tobuy';

  if v_regressions > 1 then
    raise exception using
      errcode = '40001',
      message = 'STALE_SHOPPING_BATCH_REJECTED',
      detail = format(
        'Rejected %s completed shopping items regressing to to-buy.',
        v_regressions
      ),
      hint = 'Reload the family data and retry only an intentional single-item reset.';
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

