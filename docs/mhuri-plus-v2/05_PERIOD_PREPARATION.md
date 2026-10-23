# Automated Period Preparation

The existing Free **Use last month** action remains unchanged. Plus families
with the verified `period_preparation` feature receive a separate preview-first
workflow.

Each preview has a stable operation ID and is persisted locally as JSON before
application. It proposes prior allocations and expected income, active
commitments, prior-period savings contribution amounts, and reusable completed
shopping items. Users can edit allocation and income amounts and deselect
proposed records before applying.

Application is replay safe:

- the budget-plan ID, generated occurrences, and shopping-item IDs are
  deterministic;
- an applied operation returns success without applying again;
- an `applying` operation can resume after an interrupted write sequence;
- an unrelated existing target plan causes a visible failure instead of an
  overwrite;
- invalid currencies, missing envelopes, and negative values fail closed.

Historical transactions, completed expenses, debt principal, repayments, and
goal contributions are never copied. Savings values remain proposals rather
than being posted as contributions. The operation record is isolated with the
family cache and removed on a family/account switch.

Tests cover JSON durability, idempotent retries, target conflicts, ledger and
debt non-duplication, restart persistence, and compatibility with the Free
budget-copy workflow.
