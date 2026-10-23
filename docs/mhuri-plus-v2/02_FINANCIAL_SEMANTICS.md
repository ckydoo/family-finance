# Phase B — Financial Semantics

## Authoritative distinctions

Mhuri Plus calculations use typed values. Similar-looking amounts are not interchangeable:

| Value | Meaning | Changes real cash? |
|---|---|---:|
| Recorded opening balance | Account/ledger-derived money at a stated time | Already reflected |
| Confirmed opening balance | A user-confirmed planner starting point | No |
| Recorded transaction | Received income or paid expense | Yes |
| Expected income | Dated future inflow | No |
| Commitment | Promise/obligation | No |
| Commitment payment | Allocation of a recorded transaction to an occurrence | Transaction does |
| Budget allocation | Spending intention/cap | No |
| Planned essential | Forecast-only intended outflow | No |
| Savings allocation | Forecast-only transfer out of spendable cash | No external expense |
| Estimate | Explicit uncertain assumption | No |
| Scenario adjustment | Ephemeral what-if overlay | No |

## Core rules

1. All amounts are integer minor units plus an explicit `Currency`.
2. Direction is separate from magnitude; planning magnitudes cannot be negative.
3. A forecast uses a half-open period `[start, end)` and stable IDs.
4. Opening available money must be confirmed. A derived value may be offered as a prefill with its timestamp and evidence, but is not silently authoritative.
5. Forecasts never silently combine currencies. Each currency receives an independent opening balance and timeline.
6. Expected income is added only on its expected date and remains visibly planned.
7. Creating a commitment never creates a transaction.
8. A transaction is counted once. Split allocations explain categories; they do not duplicate the transaction's cash movement.
9. A commitment payment associates transaction value with an occurrence. The same transaction amount cannot be allocated twice.
10. Savings contributions remain family assets but leave spendable cash. A planned savings allocation is not a completed contribution.
11. Scenarios are immutable overlays. They may move, replace, remove, or add forecast inputs but cannot mutate repositories.
12. No interest or exchange rate is invented. Consolidated converted forecasts require a separately approved, dated FX assumption.

## Deterministic engine

`app/lib/core/planning/financial_planner.dart` is a pure calculation boundary. It accepts a confirmed opening balance, dated typed entries, evidence, and optional scenario changes. It produces:

- deterministic chronological points (same-day ties ordered by stable ID);
- closing and lowest balances;
- first transitions below zero;
- included evidence suitable for explanation/drill-down;
- independent per-currency results.

It performs no I/O and mutates no inputs. UI, repositories, preview RPCs, and future authorized Assistant operations must use this same semantic layer instead of reimplementing balance logic.

## Shortfall semantics

A shortfall begins when the projected balance crosses from zero-or-positive to negative. The result identifies the triggering entry, date, and amount below zero. Remaining negative days do not create duplicate warnings; a later recovery followed by another crossing creates a new shortfall.

## Scenario semantics

Scenario changes have stable IDs. A change may:

- shift a target entry's date (late income);
- replace its magnitude (higher groceries or extra savings);
- remove it from the scenario;
- add a `scenarioAdjustment` entry (candidate purchase).

Source records remain unchanged. Confirmation of a scenario is a separate future business operation with validation and user confirmation.

## Evidence and limitations

Every planning entry carries a source type, source ID, label, and estimate flag. User-facing results must show the period, opening-balance source, included planned/actual values, and limitations. Missing inputs are described as missing; historical averages are never presented as confirmed future payments.

## Tests

`app/test/financial_planner_test.dart` covers the canonical planner example, unconfirmed balance rejection, shortfalls, late income, candidate purchases, changed essentials, period boundaries, deterministic order, currency isolation, duplicate prevention, invalid values, and source immutability.
