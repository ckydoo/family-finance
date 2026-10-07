-- 028: DURABLE BILL PAYMENT LINKS.
-- Posted recurring bills remain identifiable after their rule advances, so
-- every device can show paid/upcoming/overdue state from real transactions.

alter table public.transaction
  add column if not exists recurring_rule_id uuid references public.recurring_rule(id);

create index if not exists transaction_recurring_rule_idx
  on public.transaction(recurring_rule_id, occurred_at desc)
  where recurring_rule_id is not null and deleted_at is null;
