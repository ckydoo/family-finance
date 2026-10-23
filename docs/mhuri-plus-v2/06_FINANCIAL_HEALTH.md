# Financial Health Check

The premium health review is computed from recorded same-currency evidence for
an explicit period. It covers income versus expenses, budget versus assigned
actual spending, largest category change against the preceding equal-length
period, upcoming commitments, cumulative savings progress, debt repayment
progress, and evidence-triggered suggested actions.

Every insight contains:

- the start and end dates;
- the exact minor-unit calculation;
- IDs of source records used for drill-down;
- limitations describing excluded or unknown data;
- an amount with an explicit currency where applicable.

The engine never converts or combines currencies. It does not infer missing
cash, transfers, interest, lender balances, or ungenerated commitments. Advice
is limited to a prompt to review concrete recorded evidence. The responsive UI
exposes calculations, record IDs, and limitations in expandable cards and has
an explicit no-data state.
