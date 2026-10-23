# Payday-to-Payday Planner

The planner uses the pure deterministic engine documented in
`02_FINANCIAL_SEMANTICS.md`. Its UI is available from the existing Plus
cash-flow card when the family has the verified `cash_flow_forecast` feature.

Users select one active currency and a 30, 60, or 90 day period, enter and
explicitly confirm available opening money, and may add expected income,
planned essentials, savings allocations, and a hypothetical purchase.
Outstanding commitment occurrences in that currency are included with source
evidence. A different currency is never converted or combined silently.

The result shows projected closing and lowest balances and the first possible
shortfall. Scenario entries exist only in widget memory and never mutate the
ledger, commitments, budgets, or savings records.

Engine tests cover ordering, period boundaries, evidence, scenario isolation,
late income, changed essentials, purchases, increased savings, currency
separation, and invalid inputs. A widget test verifies the confirmation gate
and an interactive forecast.
