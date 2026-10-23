# Smart Bills & Commitments

## Scope

Commitments are additive to the existing Free recurring-bill workflow. Creating
a commitment creates a plan only; it never creates or posts a transaction.

The domain is split into three durable records:

- `financial_commitment`: definition, recurrence, lifecycle, reminder offsets.
- `commitment_occurrence`: stable dated obligation keyed by commitment and
  `YYYY-MM-DD` occurrence key.
- `commitment_payment`: idempotent allocation from an existing expense
  transaction to an occurrence.

## Invariants

- Amounts are positive integer minor units with an explicit currency.
- Monthly schedules retain the original anchor day after a short month.
- Paused, ended, and archived definitions generate no new occurrences.
- Generation is replay safe through the unique commitment/occurrence key and
  deterministic UUID derived from that key.
- A payment must reference an existing, non-deleted expense in the same
  currency. It never creates another expense.
- Payments cannot exceed either the occurrence outstanding amount or the
  unallocated amount of the source transaction.
- Duplicate payment mutation IDs are rejected.
- Planner input uses only the outstanding amount and retains evidence pointing
  to the source occurrence. Actual, planned, and estimated values remain
  distinct.
- Currencies are never combined implicitly.

## Storage and synchronization

SQLite schema version 24 adds the three tables, indexes, uniqueness, and local
foreign keys. All records participate in seed/reload, account isolation,
outbox serialization, ordered pulls, and in-memory merges.

Migration `049_financial_commitments.sql` is forward-only and has not been
applied to production. It adds matching PostgreSQL tables, RLS, family-scope
checks, author checks, currency validation, expense-only payment links, and
server-side overpayment/over-allocation guards.

## Reminders and views

App state exposes upcoming and overdue occurrences. Reminder offsets are stored
per commitment; each offset creates a stable notification key. Overdue unpaid
occurrences receive a stable overdue reminder. Paid, skipped, canceled, paused,
ended, and archived records are excluded as appropriate.

## Verification

Focused tests cover month-end recurrence, pause/end behavior, outstanding
calculation, duplicate prevention, partial payments, transaction allocation
limits, planner conversion, sync round trips, and SQLite restart durability.
