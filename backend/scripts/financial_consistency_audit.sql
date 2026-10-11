select json_build_object(
  'accounts', (select count(*) from public.account where not is_archived),
  'account_updated_at_ready', exists(
    select 1 from information_schema.columns
    where table_schema='public' and table_name='account' and column_name='updated_at'
  ),
  'transactions', (select count(*) from public.transaction where deleted_at is null),
  'invalid_transaction_amounts', (select count(*) from public.transaction where amount_minor <= 0),
  'orphan_transaction_members', (select count(*) from public.transaction t left join public.user_profile p on p.id=t.member_id where p.id is null),
  'orphan_goal_transactions', (select count(*) from public.goal_tx gt left join public.goal g on g.id=gt.goal_id where g.id is null),
  'orphan_debt_repayments', (select count(*) from public.debt_repayment r left join public.family_debt d on d.id=r.debt_id where d.id is null),
  'overpaid_debts', (select count(*) from public.family_debt d where (select coalesce(sum(r.amount_minor),0) from public.debt_repayment r where r.debt_id=d.id) > d.principal_minor),
  'settled_with_balance', (select count(*) from public.family_debt d where d.status='settled' and (select coalesce(sum(r.amount_minor),0) from public.debt_repayment r where r.debt_id=d.id) < d.principal_minor),
  'active_fully_paid', (select count(*) from public.family_debt d where d.status='active' and (select coalesce(sum(r.amount_minor),0) from public.debt_repayment r where r.debt_id=d.id) >= d.principal_minor),
  'duplicate_repayment_ids', (select count(*) from (select id from public.debt_repayment group by id having count(*) > 1) x)
) as audit;
