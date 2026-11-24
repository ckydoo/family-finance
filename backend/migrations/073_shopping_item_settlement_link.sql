-- 073: link each completed shopping item to the transaction that settled
-- (paid for) it, and add an explicit re-plan signal so a done→tobuy
-- transition can only be a deliberate act - never a stale or rebased push.
--
-- settled_tx_id lets the app distinguish "re-plan for next time" (keep the
-- purchase, balance unchanged) from "undo the purchase" (reverse the linked
-- transaction so the money returns).
--
-- replanned_at is set only by a deliberate re-plan / undo. The regression
-- guard accepts a done→tobuy transition only when replanned_at is set, so a
-- stale tobuy push (which leaves it null) is rejected instead of silently
-- reopening a completed purchase.

alter table public.list_item
  add column if not exists settled_tx_id uuid
    references public.transaction(id) on delete set null;

alter table public.list_item
  add column if not exists replanned_at timestamptz;

-- Populate the link for items that were already completed before these columns
-- existed, matching each done item to the most recent settlement transaction
-- in its list. Historical items without a clear match stay null and are treated
-- as "re-plan only" (their purchase cannot be undone without the link).
do $$
declare
  v_count integer;
begin
  update public.list_item li
     set settled_tx_id = (
       select t.id
         from public.transaction t
         join public.shopping_list l on l.id = li.list_id
        where t.envelope_id = l.envelope_id
          and t.type = 'expense'
          and t.deleted_at is null
          and t.when is not null
         order by t.when desc
         limit 1
     )
   where li.state = 'done'
     and li.checked_out = true
     and li.settled_tx_id is null;

  get diagnostics v_count = row_count;
  -- Not an error if nothing matched; the link is simply left null.
  void v_count;
end;
$$;

-- Tightened regression guard. A done→tobuy transition is accepted only when
-- the mutation clears the purchase fields AND sets replanned_at - the explicit
-- signal that a deliberate new cycle occurred. A stale or rebased tobuy push
-- leaves replanned_at null, so it is rejected. (The settlement-link check is
-- retained so a regression that fails to clear the link is also caught.)
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
       and new_row.replanned_at is not null
       and (new_row.replanned_at > old_row.replanned_at
            or old_row.replanned_at is null)
       and coalesce(new_row.settled_tx_id, '00000000-0000-0000-0000-000000000000'::uuid)
           is distinct from
         coalesce(old_row.settled_tx_id, '00000000-0000-0000-0000-000000000000'::uuid)
     );

  if v_regressions > 0 then
    raise exception using
      errcode = '40001',
      message = 'STALE_SHOPPING_ITEM_REOPEN_REJECTED',
      detail = format(
        'Rejected %s completed shopping items regressing to to-buy without an explicit re-plan.',
        v_regressions
      ),
      hint = 'Use "Put on list for next time" or "Undo purchase" to re-open a completed item deliberately.';
  end if;
  return null;
end;
$$;

-- Re-attach the guard trigger with the tightened logic.
drop trigger if exists trg_guard_bulk_shopping_regression
  on public.list_item;
create trigger trg_guard_bulk_shopping_regression
after update on public.list_item
referencing old table as old_rows new table as new_rows
for each statement execute function public.guard_bulk_shopping_regression();

revoke all on function public.guard_bulk_shopping_regression()
  from public, anon, authenticated;
