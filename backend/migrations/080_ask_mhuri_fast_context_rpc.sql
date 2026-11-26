-- 080_ask_mhuri_fast_context_rpc.sql
-- Collapses Ask Mhuri's 12+ PostgREST round-trips and 40,000-row downloads into
-- a single, read-only, service-role SQL function with exact ledger parity:
--   * Excludes private/personal accounts and soft-deleted transactions & goal_txs
--   * Combines transaction_split (splits) + envelope_tx (single-envelope) without double-counting
--   * Includes per-member shared cycle spending ('member_spending')
--   * Includes both commitment_occurrence and active recurring_rule upcoming bills
--   * Includes open shopping list summary ('shopping_summary')

create or replace function public.get_ask_mhuri_context(
  p_space_id uuid,
  p_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_role text;
  v_space record;
  v_entitlement record;
  v_plus boolean := false;
  v_today timestamptz := now();
  v_today_date date := (now() at time zone 'UTC')::date;
  v_cycle_day int;
  v_cur_year int := extract(year from v_today_date)::int;
  v_cur_month int := extract(month from v_today_date)::int;
  v_cycle_start timestamptz;
  v_next_cycle timestamptz;
  v_prev_cycle timestamptz;
  v_occurrence_end timestamptz := v_today + interval '45 days';
  v_base_currency text;
  v_cycle_spending jsonb;
  v_cycle_income jsonb;
  v_prev_spending jsonb;
  v_prev_income jsonb;
  v_account_balances jsonb;
  v_available_after_savings jsonb;
  v_budgets jsonb;
  v_top_categories jsonb;
  v_member_spending jsonb;
  v_upcoming_commitments jsonb;
  v_savings_goals jsonb;
  v_debts jsonb;
  v_shopping_summary jsonb;
begin
  select m.role
    into v_role
    from public.membership m
   where m.space_id = p_space_id
     and m.user_id = p_user_id
     and m.invite_status = 'active'
   limit 1;

  if v_role is null then
    return jsonb_build_object('error', 'FAMILY_ACCESS_DENIED');
  end if;

  if v_role not in ('owner', 'admin', 'co_parent', 'adult', 'contributor', 'viewer') then
    return jsonb_build_object('error', 'ROLE_NOT_SUPPORTED');
  end if;

  select s.id, s.name, coalesce(s.base_currency, 'USD') as base_currency,
         greatest(1, least(31, coalesce(s.month_start_day, 1))) as month_start_day
    into v_space
    from public.family_space s
   where s.id = p_space_id;

  if not found then
    return jsonb_build_object('error', 'FAMILY_ACCESS_DENIED');
  end if;

  v_base_currency := v_space.base_currency;
  v_cycle_day := v_space.month_start_day;

  select e.status, e.features, e.expires_at
    into v_entitlement
    from public.family_entitlement e
   where e.space_id = p_space_id
   limit 1;

  if found then
    v_plus := coalesce(v_entitlement.status, 'free') in ('active', 'gracePeriod', 'canceledActive')
      and (v_entitlement.expires_at is null or v_entitlement.expires_at > v_today)
      and coalesce(v_entitlement.features, '[]'::jsonb) ? 'ask_mhuri';
  end if;

  -- Compute payday-aligned UTC cycle boundaries (clamped to month length).
  v_cycle_start := make_timestamptz(
    v_cur_year,
    v_cur_month,
    least(
      v_cycle_day,
      extract(day from (date_trunc('month', make_date(v_cur_year, v_cur_month, 1)) + interval '1 month - 1 day'))::int
    ),
    0, 0, 0, 'UTC'
  );
  if v_cycle_start > v_today then
    declare
      v_pm date := (make_date(v_cur_year, v_cur_month, 1) - interval '1 month')::date;
    begin
      v_cycle_start := make_timestamptz(
        extract(year from v_pm)::int,
        extract(month from v_pm)::int,
        least(
          v_cycle_day,
          extract(day from (date_trunc('month', v_pm) + interval '1 month - 1 day'))::int
        ),
        0, 0, 0, 'UTC'
      );
    end;
  end if;

  declare
    v_nm date := (date_trunc('month', v_cycle_start at time zone 'UTC')::date + interval '1 month')::date;
    v_prm date := (date_trunc('month', v_cycle_start at time zone 'UTC')::date - interval '1 month')::date;
  begin
    v_next_cycle := make_timestamptz(
      extract(year from v_nm)::int,
      extract(month from v_nm)::int,
      least(
        v_cycle_day,
        extract(day from (date_trunc('month', v_nm) + interval '1 month - 1 day'))::int
      ),
      0, 0, 0, 'UTC'
    );
    v_prev_cycle := make_timestamptz(
      extract(year from v_prm)::int,
      extract(month from v_prm)::int,
      least(
        v_cycle_day,
        extract(day from (date_trunc('month', v_prm) + interval '1 month - 1 day'))::int
      ),
      0, 0, 0, 'UTC'
    );
  end;

  -- Visible currencies across shared transactions & base currency.
  with visible_tx as (
    select t.id, t.type, t.amount_minor, t.currency, t.member_id, t.occurred_at
      from public."transaction" t
      left join public.account a on a.id = t.account_id
     where t.space_id = p_space_id
       and t.deleted_at is null
       and (
         t.account_id is null
         or (a.id is not null and coalesce(a.sharing, 'shared') not in ('private', 'personal'))
       )
  ),
  currencies as (
    select distinct code from (
      select v_base_currency as code
      union
      select vt.currency as code from visible_tx vt where vt.currency is not null and vt.currency <> ''
    ) c
  )
  select
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'currency', c.code,
        'minor_units', coalesce((
          select sum(vt.amount_minor)::bigint from visible_tx vt
           where vt.type = 'expense' and vt.currency = c.code
             and vt.occurred_at >= v_cycle_start and vt.occurred_at < v_next_cycle
        ), 0)
      ) order by c.code)
      from currencies c
    ), '[]'::jsonb),
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'currency', c.code,
        'minor_units', coalesce((
          select sum(vt.amount_minor)::bigint from visible_tx vt
           where vt.type = 'income' and vt.currency = c.code
             and vt.occurred_at >= v_cycle_start and vt.occurred_at < v_next_cycle
        ), 0)
      ) order by c.code)
      from currencies c
    ), '[]'::jsonb),
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'currency', c.code,
        'minor_units', coalesce((
          select sum(vt.amount_minor)::bigint from visible_tx vt
           where vt.type = 'expense' and vt.currency = c.code
             and vt.occurred_at >= v_prev_cycle and vt.occurred_at < v_cycle_start
        ), 0)
      ) order by c.code)
      from currencies c
    ), '[]'::jsonb),
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'currency', c.code,
        'minor_units', coalesce((
          select sum(vt.amount_minor)::bigint from visible_tx vt
           where vt.type = 'income' and vt.currency = c.code
             and vt.occurred_at >= v_prev_cycle and vt.occurred_at < v_cycle_start
        ), 0)
      ) order by c.code)
      from currencies c
    ), '[]'::jsonb)
  into v_cycle_spending, v_cycle_income, v_prev_spending, v_prev_income;

  -- Account balances & available after recorded savings (excluding soft-deleted goal_txs & private accounts).
  with shared_opening as (
    select a.currency, sum(a.opening_balance_minor)::bigint as opening_minor
      from public.account a
     where a.space_id = p_space_id
       and coalesce(a.sharing, 'shared') not in ('private', 'personal')
       and a.currency is not null and a.currency <> ''
     group by a.currency
  ),
  shared_movements as (
    select t.currency,
           sum(case when t.type = 'income' then t.amount_minor
                    when t.type = 'expense' then -t.amount_minor
                    else 0 end)::bigint as net_minor
      from public."transaction" t
      left join public.account a on a.id = t.account_id
     where t.space_id = p_space_id
       and t.deleted_at is null
       and (
         t.account_id is null
         or (a.id is not null and coalesce(a.sharing, 'shared') not in ('private', 'personal'))
       )
       and t.currency is not null and t.currency <> ''
     group by t.currency
  ),
  visible_saved as (
    select gt.currency, sum(gt.amount_minor)::bigint as saved_minor
      from public.goal_tx gt
      join public.goal g on g.id = gt.goal_id
     where g.space_id = p_space_id
       and g.status = 'active'
       and gt.deleted_at is null
       and not (coalesce(g.is_kid_jar, false) and g.owner_member_id is distinct from p_user_id)
       and gt.currency is not null and gt.currency <> ''
     group by gt.currency
  ),
  all_bal_currencies as (
    select currency from shared_opening
    union
    select currency from shared_movements
  ),
  balances as (
    select c.currency,
           (coalesce(o.opening_minor, 0) + coalesce(m.net_minor, 0))::bigint as balance_minor,
           (coalesce(o.opening_minor, 0) + coalesce(m.net_minor, 0) - coalesce(s.saved_minor, 0))::bigint as available_minor
      from all_bal_currencies c
      left join shared_opening o on o.currency = c.currency
      left join shared_movements m on m.currency = c.currency
      left join visible_saved s on s.currency = c.currency
  )
  select
    coalesce((
      select jsonb_agg(jsonb_build_object('currency', b.currency, 'minor_units', b.balance_minor) order by b.currency)
      from balances b
    ), '[]'::jsonb),
    coalesce((
      select jsonb_agg(jsonb_build_object('currency', b.currency, 'minor_units', b.available_minor) order by b.currency)
      from balances b
    ), '[]'::jsonb)
  into v_account_balances, v_available_after_savings;

  -- Per-member shared cycle spending (answers 'Who spent what?' / 'Did I spend more than my sister?').
  with cycle_member_tx as (
    select coalesce(up.name, 'Family member') as member_name,
           (t.member_id = p_user_id) as is_caller,
           t.currency,
           sum(t.amount_minor)::bigint as spent_minor,
           count(*)::int as tx_count
      from public."transaction" t
      left join public.account a on a.id = t.account_id
      left join public.user_profile up on up.id = t.member_id
     where t.space_id = p_space_id
       and t.deleted_at is null
       and t.type = 'expense'
       and t.occurred_at >= v_cycle_start
       and t.occurred_at < v_next_cycle
       and (
         t.account_id is null
         or (a.id is not null and coalesce(a.sharing, 'shared') not in ('private', 'personal'))
       )
     group by coalesce(up.name, 'Family member'), (t.member_id = p_user_id), t.currency
  ),
  currency_totals as (
    select currency, sum(spent_minor)::numeric as total_minor
      from cycle_member_tx
     group by currency
  )
  select coalesce((
    select jsonb_agg(jsonb_build_object(
      'name', left(m.member_name, 50),
      'is_you', m.is_caller,
      'currency', m.currency,
      'spent_minor', m.spent_minor,
      'tx_count', m.tx_count,
      'share_percent', case when ct.total_minor > 0
        then round((m.spent_minor::numeric * 100.0) / ct.total_minor)::int
        else 0 end
    ) order by m.spent_minor desc)
    from cycle_member_tx m
    join currency_totals ct on ct.currency = m.currency
  ), '[]'::jsonb)
  into v_member_spending;

  -- Budgets + top categories (combining transaction_split AND envelope_tx without double-counting).
  with cycle_visible_expenses as (
    select t.id, t.amount_minor, t.currency
      from public."transaction" t
      left join public.account a on a.id = t.account_id
     where t.space_id = p_space_id
       and t.deleted_at is null
       and t.type = 'expense'
       and t.occurred_at >= v_cycle_start
       and t.occurred_at < v_next_cycle
       and (
         t.account_id is null
         or (a.id is not null and coalesce(a.sharing, 'shared') not in ('private', 'personal'))
       )
  ),
  tx_with_splits as (
    select distinct ts.transaction_id
      from public.transaction_split ts
     where ts.space_id = p_space_id
  ),
  allocations as (
    select ts.envelope_id, ts.amount_minor as allocated_minor, ts.currency
      from public.transaction_split ts
      join cycle_visible_expenses cve on cve.id = ts.transaction_id
     where ts.space_id = p_space_id
    union all
    select et.envelope_id, et.allocated_minor, et.currency
      from public.envelope_tx et
      join cycle_visible_expenses cve on cve.id = et.transaction_id
     where not exists (
       select 1 from tx_with_splits s where s.transaction_id = et.transaction_id
     )
  ),
  env_status as (
    select e.id,
           e.name,
           e.limit_currency as currency,
           e.limit_minor,
           not exists (
             select 1 from allocations al
              where al.envelope_id = e.id and al.currency is distinct from e.limit_currency
           ) as complete,
           coalesce((
             select sum(al.allocated_minor)::bigint from allocations al
              where al.envelope_id = e.id and al.currency = e.limit_currency
           ), 0) as spent_minor
      from public.envelope e
     where e.space_id = p_space_id
       and not coalesce(e.is_archived, false)
       and coalesce(e.sharing, 'shared') <> 'personal'
  )
  select
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'name', coalesce(es.name, 'Budget'),
        'currency', es.currency,
        'complete', es.complete,
        'limit_minor', es.limit_minor,
        'spent_minor', case when es.complete then es.spent_minor else null end,
        'remaining_minor', case when es.complete then (es.limit_minor - es.spent_minor) else null end
      ) order by es.spent_minor desc, es.name asc)
      from env_status es
    ), '[]'::jsonb),
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'name', r.name,
        'currency', r.currency,
        'spent_minor', r.spent_minor
      ) order by r.currency, r.spent_minor desc)
      from (
        select coalesce(es.name, 'Budget') as name,
               es.currency,
               es.spent_minor,
               row_number() over (partition by es.currency order by es.spent_minor desc) as rn
          from env_status es
         where es.complete and es.spent_minor > 0
      ) r
      where r.rn <= 5
    ), '[]'::jsonb)
  into v_budgets, v_top_categories;

  -- Upcoming bills: unpaid commitment_occurrences AND active recurring_rules in next 45 days.
  with occ_bills as (
    select coalesce(fc.name, 'Upcoming bill') as name,
           o.due_date,
           o.currency,
           greatest(0, o.amount_minor - coalesce((
             select sum(cp.amount_minor)::bigint
               from public.commitment_payment cp
              where cp.occurrence_id = o.id and cp.currency = o.currency
           ), 0))::bigint as amount_minor
      from public.commitment_occurrence o
      join public.financial_commitment fc on fc.id = o.commitment_id
     where fc.space_id = p_space_id
       and fc.status = 'active'
       and o.due_date >= v_today
       and o.due_date <= v_occurrence_end
       and coalesce(o.status, 'pending') not in ('paid', 'skipped', 'canceled')
  ),
  rec_bills as (
    select coalesce(rr.name, 'Recurring bill') as name,
           make_timestamptz(
             extract(year from rr.next_due)::int,
             extract(month from rr.next_due)::int,
             extract(day from rr.next_due)::int,
             0, 0, 0, 'UTC'
           ) as due_date,
           rr.currency,
           rr.amount_minor
      from public.recurring_rule rr
     where rr.space_id = p_space_id
       and coalesce(rr.active, true)
       and rr.archived_at is null
       and rr.next_due >= v_today_date
       and rr.next_due <= (v_today_date + 45)
  ),
  combined_bills as (
    select name, due_date, currency, amount_minor from occ_bills where amount_minor > 0
    union all
    select rb.name, rb.due_date, rb.currency, rb.amount_minor
      from rec_bills rb
     where rb.amount_minor > 0
       and not exists (
         select 1 from occ_bills ob
          where lower(btrim(ob.name)) = lower(btrim(rb.name))
            and ob.due_date::date = rb.due_date::date
       )
  )
  select coalesce((
    select jsonb_agg(jsonb_build_object(
      'name', cb.name,
      'due_date', cb.due_date,
      'currency', cb.currency,
      'amount_minor', cb.amount_minor
    ) order by cb.due_date asc)
    from combined_bills cb
  ), '[]'::jsonb)
  into v_upcoming_commitments;

  -- Savings goals (excluding other kids' jars and soft-deleted goal_txs).
  with g_rows as (
    select g.id,
           coalesce(g.name, 'Savings goal') as name,
           g.target_currency as currency,
           g.target_minor,
           g.deadline,
           not exists (
             select 1 from public.goal_tx gt
              where gt.goal_id = g.id and gt.deleted_at is null
                and gt.currency is distinct from g.target_currency
           ) as complete,
           coalesce((
             select sum(gt.amount_minor)::bigint from public.goal_tx gt
              where gt.goal_id = g.id and gt.deleted_at is null
                and gt.currency = g.target_currency
           ), 0) as saved_minor
      from public.goal g
     where g.space_id = p_space_id
       and g.status = 'active'
       and not (coalesce(g.is_kid_jar, false) and g.owner_member_id is distinct from p_user_id)
  )
  select coalesce((
    select jsonb_agg(jsonb_build_object(
      'name', gr.name,
      'currency', gr.currency,
      'complete', gr.complete,
      'target_minor', gr.target_minor,
      'saved_minor', case when gr.complete then gr.saved_minor else null end,
      'remaining_minor', case when gr.complete then greatest(0, gr.target_minor - gr.saved_minor) else null end,
      'required_weekly_minor', case
        when gr.complete and gr.deadline is not null and gr.deadline > v_today_date and (gr.target_minor - gr.saved_minor) > 0
        then ceil((gr.target_minor - gr.saved_minor)::numeric / greatest(1, ceil((gr.deadline - v_today_date)::numeric / 7.0)))::bigint
        else null end,
      'weeks_to_deadline', case
        when gr.deadline is not null and gr.deadline > v_today_date
        then ceil((gr.deadline - v_today_date)::numeric / 7.0)::int
        else null end,
      'deadline', gr.deadline
    ) order by gr.deadline asc nulls last, gr.name asc)
    from g_rows gr
  ), '[]'::jsonb)
  into v_savings_goals;

  -- Active family debts.
  with d_rows as (
    select d.id,
           coalesce(d.name, 'Debt') as name,
           coalesce(d.direction, '') as direction,
           d.currency,
           d.principal_minor,
           d.due_date,
           not exists (
             select 1 from public.debt_repayment dr
              where dr.debt_id = d.id and dr.currency is distinct from d.currency
           ) as complete,
           coalesce((
             select sum(dr.amount_minor)::bigint from public.debt_repayment dr
              where dr.debt_id = d.id and dr.currency = d.currency
           ), 0) as repaid_minor
      from public.family_debt d
     where d.space_id = p_space_id
       and d.status = 'active'
  )
  select coalesce((
    select jsonb_agg(jsonb_build_object(
      'name', dr.name,
      'direction', dr.direction,
      'currency', dr.currency,
      'complete', dr.complete,
      'original_minor', dr.principal_minor,
      'repaid_minor', case when dr.complete then dr.repaid_minor else null end,
      'remaining_minor', case when dr.complete then greatest(0, dr.principal_minor - dr.repaid_minor) else null end,
      'due_date', dr.due_date
    ) order by dr.due_date asc nulls last, dr.name asc)
    from d_rows dr
  ), '[]'::jsonb)
  into v_debts;

  -- Active shopping list open items summary.
  with open_items as (
    select li.currency,
           count(*)::int as item_count,
           coalesce(sum(coalesce(li.est_price_minor, 0) * greatest(1, coalesce(li.qty, 1))), 0)::bigint as estimated_minor
      from public.list_item li
      join public.shopping_list sl on sl.id = li.list_id
     where sl.space_id = p_space_id
       and sl.deleted_at is null
       and coalesce(sl.status, 'active') = 'active'
       and li.deleted_at is null
       and not coalesce(li.checked_out, false)
       and coalesce(li.state, 'need') <> 'done'
     group by li.currency
  )
  select coalesce((
    select jsonb_agg(jsonb_build_object(
      'currency', oi.currency,
      'open_items', oi.item_count,
      'estimated_minor', oi.estimated_minor
    ) order by oi.currency)
    from open_items oi
  ), '[]'::jsonb)
  into v_shopping_summary;

  return jsonb_build_object(
    'ok', true,
    'role', v_role,
    'plus', v_plus,
    'daily_limit', case when v_plus then 50 else 5 end,
    'currency', v_base_currency,
    'as_of', to_char(v_today at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    'cycle_start', to_char(v_cycle_start at time zone 'UTC', 'YYYY-MM-DD'),
    'next_cycle_start', to_char(v_next_cycle at time zone 'UTC', 'YYYY-MM-DD'),
    'previous_cycle_start', to_char(v_prev_cycle at time zone 'UTC', 'YYYY-MM-DD'),
    'cycle_spending', v_cycle_spending,
    'cycle_income', v_cycle_income,
    'previous_cycle_spending', v_prev_spending,
    'previous_cycle_income', v_prev_income,
    'account_balances_estimate', v_account_balances,
    'available_after_recorded_savings', v_available_after_savings,
    'member_spending', v_member_spending,
    'budgets', v_budgets,
    'top_categories', v_top_categories,
    'upcoming_commitments', v_upcoming_commitments,
    'savings_goals', v_savings_goals,
    'debts', v_debts,
    'shopping_summary', v_shopping_summary
  );
end;
$$;

revoke all on function public.get_ask_mhuri_context(uuid, uuid) from public, anon, authenticated;
grant execute on function public.get_ask_mhuri_context(uuid, uuid) to service_role;
