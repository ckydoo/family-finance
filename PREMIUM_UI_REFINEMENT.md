
## Pass 2 — Data density and communication polish
- Savings goal, contribution and debt records now use compact row/divider presentation rather than repeated filled cards.
- Debt state is rendered as quiet metadata rather than a large chip.
- Chat bubbles use a more restrained radius and media corners to better match the premium design system.
- Existing task list architecture was retained because it already uses lazy, separated compact rows and scalable search/scope/period controls.
- Existing Family architecture was retained because it already follows the intended Members → Family features → Settings hierarchy.


## Pass 3 — App-wide consistency and density

- Shopping filters now use a compact horizontally scrollable chip rail so state filters do not wrap into multiple rows on smaller devices or with translated labels.
- Shopping totals were flattened into a separated summary section instead of another large card, reducing card stacking.
- Shopping item typography was softened and the checkout action reduced to a 50px, zero-elevation control with the shared small radius token.
- Activity date headers were softened for clearer hierarchy and a duplicate date-filter state update was removed.
- Existing lazy list rendering, search, filter, empty-state, transaction-detail and keyboard-safe quick-add patterns were preserved.
- No Supabase schema, authentication, RLS, finance calculations, shopping checkout logic, or data contracts were changed in this pass.
