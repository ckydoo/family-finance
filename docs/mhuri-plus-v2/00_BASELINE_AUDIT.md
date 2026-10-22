# Mhuri Plus v2 — Baseline Audit

**Audit date:** 2026-10-22 (Africa/Harare)  
**Repository revision:** `ba072a33076c77d4350ae9d5d301419302286ba9` (`main`)  
**Scope:** Phase 0 read-only audit only. No application code, migration, billing flag, store product, or production data was changed.

## Executive summary

Mhuri is a substantial offline-first family finance application, not a scaffold that should be replaced. It already has a reusable transaction ledger, split allocations, payday-aligned budget cycles, recurring expense review, savings goals, debt tracking, shopping-to-expense checkout, role-aware family collaboration, SQLite persistence, an outbox/pull sync engine, and extensive tests.

The repository also contains a recent, mostly uncommitted Plus foundation: family entitlements, Google Play purchase plumbing, lifecycle Edge Functions, category comparisons, a historical cash-flow estimate, savings projections, polls, pins, and advanced chat search. The linked Supabase project currently has the entitlement and Plus chat database objects and both billing Edge Functions deployed. Billing remains disabled by default in Flutter, and no real Play purchase, renewal, cancellation, refund, restore, or secret/product configuration was verified in this audit.

The present Plus offer is not yet ready for a paid release. Its main financial value is based on historical extrapolation rather than planned commitments; no payday-to-payday planner or isolated what-if model exists; recurring rules are too limited to be the complete commitments model; automated period preparation only copies budget allocations; premium reports are category deltas rather than a coherent health review; savings projections infer future contributions from history; and debt scenarios do not exist. Plus chat tooling is present but incomplete in discovery, refresh, pagination, validation feedback, and some server authorization details.

The current working tree is heavily dirty and the test baseline is not green. Phase 1 should not start until the ownership and intended disposition of those changes is confirmed and the six existing Flutter test failures are triaged.

## Audit method and evidence limits

Inspected:

- Flutter entry points, navigation, state, models, screens, persistence, sync, notifications, billing, tests, Android configuration, and package configuration.
- The complete local migration inventory, consolidated schema, database smoke tests, RLS/RPC definitions, entitlement migration, and Plus chat migration.
- Local Supabase Edge Function source for purchase verification and Google Play RTDN.
- Current Git status/diff inventory.
- Linked Supabase catalog using read-only queries, plus the deployed Edge Function list.

Executed:

- `flutter analyze --fatal-infos`
- `flutter test`
- A focused rerun of `test/widget_screen_test.dart`
- Read-only linked catalog queries for migrations 047–048 objects, RLS state, RPC presence, and migration ledger presence.
- Read-only deployed Edge Function listing.

Not executed or independently proven:

- The SQL migration chain or `backend/tests/integrity_smoke.sql`: Docker, `psql`, and `pg_isready` are unavailable locally.
- A disposable Supabase database migration.
- A Google Play sandbox purchase or restore.
- Play Console product configuration, service-account permissions, RTDN delivery, Pub/Sub OIDC settings, or production secrets.
- Exact deployed Edge Function source equivalence to local files; deployment presence/version was verified, not source downloaded and diffed.
- End-to-end offline conflict tests for any proposed v2 entity, because those entities do not yet exist.

## 1. Existing functionality inventory

### Application architecture and navigation

- Flutter/Material 3 application with a central `ChangeNotifier` state container (`AppState`) exposed through `AppScope`: `app/lib/app.dart`, `app/lib/core/state/app_state.dart`.
- Authentication gate and role routing for owner, admin, adult, contributor, teen, kid, and viewer roles: `app/lib/app.dart`, `app/lib/core/models/models.dart`.
- Adult shell with Home, Budgets, global Quick Add, Savings, and Lists; Reports, Family, Tasks, Chat, Settings, and other flows are reached contextually: `app/lib/features/shell/adult_shell.dart`.
- Dedicated Teen Zone and sealed Kids Mode, with profile preview protections and PIN flows: `app/lib/features/teen/teen_zone.dart`, `app/lib/features/kids/kids_mode.dart`, `app/lib/core/auth/pin_store.dart`.
- Six localized UI bundles and responsive/accessibility work, though newer Plus copy is largely inline English: `app/lib/l10n/`, `app/lib/core/theme/app_theme.dart`.

### Core finance

- Integer-minor-unit `Money` values; supported records retain their currency. Currency conversion uses the family rate for display/calculation: `app/lib/core/money/money.dart`.
- Accounts with opening/tagged balances, income and expense transactions, transaction authors/subjects, payment methods, receipts, soft deletion, and split transaction allocations: `Account`, `Tx`, and `TxAllocation` in `app/lib/core/models/models.dart`; server tables `account`, `transaction`, `transaction_split`, and `envelope_tx`.
- Family pool calculation: opening account balances plus recorded income minus recorded expenses. Savings contributions remain part of total family money but reduce spendable cash: `poolCombined`, `totalSaved`, and `availableToSpend` in `app/lib/core/state/app_state.dart`.
- Envelopes/categories with limits, personal/shared flags, rollover modes, pace, spending totals, overspend warning/block behavior, and allocation transfers: `Envelope` and envelope methods in `app/lib/core/state/app_state.dart`; `app/lib/features/budgets/budgets_screen.dart`.
- Payday-aligned budget cycles use a configurable start day. Cycle plans store income mode (`knownMonthly` or `asEarned`), one expected-income amount, envelope allocation snapshots, close state, and copy provenance: `BudgetCyclePlan`; migration `020_budget_cycle_plans.sql`.
- Free “use last month” behavior copies the previous cycle's envelope limits and income mode/amount into the current cycle. It does not copy commitments, savings plans, shopping lists, expected-income events, or provide a preview/operation record.
- Reports already include recorded income versus expense, savings, plan versus actual, previous-cycle comparison, envelope health, cash share, top categories/members, and shopping/list tracking: `app/lib/features/reports/reports_screen.dart`.

### Bills and recurring expenses

- `RecurringRule` supports name, amount/currency, linked envelope, member, payment method, frequency (`weekly`, `monthly`, `term`), next due date, active state, and archive state: `app/lib/core/models/models.dart`.
- Rules surface for review; posting creates a real expense and advances the next due date, while skip advances without charging. Creation itself does not create an expense.
- Transactions can retain `recurring_rule_id`, allowing posted payments to be associated with a recurring rule: migration `028_bill_payment_links.sql`, local `tx.recurring_rule_id`.
- Device reminders include a bills category and due reminders: `app/lib/core/notifications/reminders.dart`.
- Gaps for v2: no one-time commitment entity, arbitrary recurrence, end date/pause semantics distinct from archive/active, multiple reminders, expected versus outstanding amount, installment/partial-payment allocation, direct association of an existing transaction, occurrence ledger, or planned-commitment forecast.

### Savings, debts, and contributions

- Savings goal CRUD, target amount, optional deadline, string-based auto-save label, contribution ledger, completion/archive, progress, and role checks: `Goal`, `GoalTx`, and savings methods/screens.
- Current Plus savings projection derives a monthly contribution rate from recent recorded contributions and estimates completion. It does not use a normalized contribution schedule, frequency-aware deterministic plan, or editable what-if scenarios.
- Family debt CRUD supports direction, principal/currency, counterparty, due date, status, repayment ledger, and remaining balance: `FamilyDebt`, `DebtRepayment`.
- A recorded debt repayment also creates an income/expense transaction so the ledger and debt balance move together. Idempotency is based on the supplied/generated payment ID.
- No interest terms are invented. No repayment schedule, payment-frequency plan, payoff forecast, or debt what-if scenario exists.
- Contribution campaigns, pledges, payments, and Mukando/ROSCA tracking already exist and should remain separate from bills and ordinary debt.

### Shopping and reusable workflows

- Shared shopping list items support estimated and actual unit prices, quantities, assignment/purchaser, state transitions, tombstones, and checkout status.
- Finish-shopping posts one expense with a selected envelope/payment method/purchaser; idempotency tests prevent repeat checkout.
- Purchased items can be reused. There is no multi-module period-preparation preview that proposes shopping-list reuse alongside budgets and commitments.

### Family collaboration

- Family chat supports text, photos, stickers, replies, edits/deletes, references to tasks/budgets/shopping, basic local text search, and periodic chat refresh.
- Family tasks, activity feed, family meeting, member/role management, invitations, push devices, and notification preferences exist.
- Poll tables and RPCs are present. The UI loads polls, creates/votes/closes, and exposes loading/error states. Poll creation is server-gated by `family_polls_pins` entitlement.
- Pin storage and RPCs are present, with a server limit of 20 and cleanup after message deletion. The Flutter UI only loads pin IDs to alter each message's action. There is no dedicated pinned-message area and pin refresh occurs only on screen initialization or a local pin/unpin action, not when another device changes pins.
- Advanced search supports text, sender, start/end dates, and message type via a family-scoped server RPC. The RPC accepts offset/limit, but Flutter always sends offset `0` and defaults to up to 250 results; the local “Load earlier” control only pages an already-fetched list.

## 2. Existing premium features and gates

### Entitlement model

- Client model: `FamilyEntitlement` contains family ID, status, feature keys, expiry, and verification time. Active, grace-period, and canceled-but-still-active states can grant Plus until expiry: `app/lib/core/billing/entitlement.dart`.
- Client gates use both an active entitlement and a matching feature key through `hasPlusFeature`.
- Family switching clears/guards entitlement state using the active family ID and a request version; a response for a prior family is rejected.
- The client fetches entitlement from the `verify-family-entitlement` Edge Function. A local store purchase event alone cannot grant access.
- No entitlement snapshot is persisted in SQLite or secure storage. Offline restart therefore has no bounded family-scoped Plus read cache. This confirms the prior audit finding.

### Current feature keys

The server currently grants the following bundle for an active subscription:

- `advanced_insights`
- `advanced_reports`
- `enhanced_reports`
- `cash_flow_forecast`
- `savings_projections`
- `family_polls_pins`
- `advanced_chat_search`

Observed UI gates:

- Category comparisons require `advanced_insights` and `advanced_reports`.
- Historical 30-day cash-flow estimate requires `cash_flow_forecast`.
- Goal projection requires `savings_projections`.
- Poll creation and new pins require `family_polls_pins`; voting and unpinning intentionally remain usable after downgrade.
- Advanced server search requires `advanced_chat_search`.

Free reports, CSV export, goals, debts, basic chat, basic local search, recurring expense review, and existing period-copy behavior remain available.

### Google Play integration

- `in_app_purchase` adapter loads store products and localized prices and supports purchase/restore: `app/lib/core/billing/google_play_billing_provider.dart`.
- Billing coordinator submits purchase tokens to the authenticated backend before completing store purchases: `app/lib/core/billing/billing_coordinator.dart`.
- Billing defaults off unless `MHURI_BILLING_ENABLED=true`. Product IDs are configurable build defines; default identifiers are not checkout prices.
- Plus screen shows store-returned plan titles/prices, family coverage, current status, restore/refresh, renewal/cancellation guidance, unavailable states, and an explicit disabled-build warning: `app/lib/features/settings/plus_screen.dart`.
- Missing or weak areas: no direct “manage subscription” deep link; pending transactions are shown but not durably reconciled; store product-period display is inferred from product ID rather than Play base-plan metadata; no verified launch configuration; inline feature promise is broader than the genuinely distinct premium value currently delivered.

## 3. Current financial calculation rules

### Money and currency

- Stored monetary amounts use integer minor units.
- `Money.inCurrency` uses the current family rate and rounding. Many aggregate views convert every record into the selected display currency, including historical data.
- No silent record mutation occurs during conversion, but reports do combine currencies using the current rate. The schema has `rate_snapshot`, yet the inspected Flutter report calculations do not use transaction-time/month-end rate snapshots. This is a financial-reporting risk and should be resolved explicitly before authoritative cross-currency forecasts.
- Commitment/planner v2 should calculate one currency at a time unless an explicit dated FX assumption is supplied and displayed.

### Balances and budgets

- Family pool = sum(accounts converted to requested currency) + recorded income − recorded expense.
- Available to spend = family pool − all recorded savings contributions.
- Allocated = sum of current envelope limits; allocations are not added to cash.
- Current-cycle envelope spend uses transaction splits when present, otherwise the transaction's envelope link. This avoids counting a split transaction again via its header envelope.
- Remaining envelope amount = effective limit − current-cycle spend.
- Safe-to-spend-today = max(0, (available cash − positive unspent envelope reserves) / days left in cycle).
- Rollover `roll` carries one previous cycle's positive remainder. `accumulate` approximates all-time entitlement as base limit multiplied by up to 24 cycles minus historical spend; the code itself identifies this as a simplification.

### Existing Plus estimates

- Cash-flow estimate looks at recorded transactions in the last 90 days. With at least 30 observed days, it scales recorded income and expenses to 30 days and shows projected net. It does not include upcoming commitments, dated expected income, planned essentials, savings plans, or late-income scenarios.
- Category insight totals recorded expense allocations for current and previous cycles and shows up to four categories with percentage deltas. It is a comparison card, not a complete premium financial-health review.
- Savings projection estimates future progress from recent contributions. Historical behavior is labeled as an estimate, but it is not the required contribution-plan engine.
- Debt remaining = max(0, principal − converted repayment total). No scheduled repayment forecast exists.

## 4. Offline persistence, synchronization, and conflicts

### Local storage

- SQLite schema and hand-written persistence cover accounts, envelopes, transactions, transaction allocations, goals/contributions, shopping, chores/requests, recurring rules, budget plans, chat, family tasks, contributions, debts/repayments, outbox, and key/value settings: `app/lib/core/db/app_database.dart`, `app/lib/core/db/persistence.dart`.
- Writes are asynchronous and tracked; manual refresh waits for pending writes. Errors are surfaced through debug logging rather than crashing.
- Current entitlement state, polls, votes, and pins are not part of local persistent domain storage.

### Sync

- Mutations are encoded to server-shaped JSON and queued in an SQLite outbox. Push uses deterministic IDs/upserts where supported; pull applies server rows through entity adapters: `app/lib/core/sync/outbox.dart`, `sync_mappers.dart`, `sync_engine.dart`.
- Sync has backoff, retry, pending counts, soft refresh, family bootstrap/restore, and a “needs review” conflict state.
- Some concurrent edits use last-writer-wins, with tests specifically covering simultaneous budget edits and multi-device transaction/list/goal convergence.
- The proposed planner/commitment/period-preparation writes must use this outbox rather than a separate online-only mutation path. Stable operation IDs and database-enforced unique keys are needed for occurrence creation, payment association, and multi-record plan application.

### Known reliability observations

- The full test run emits multiple “database already closed” persistence warnings from asynchronous writes in tests. They did not account for the six failures but indicate teardown/write lifecycle debt.
- The current full test suite contains a premium-entity sync failure caused by a map/list response mismatch.
- Advanced search, polls, and pins are online RPC/read paths with no useful offline cache.

## 5. Supabase data model, RLS, and live state

### Reusable database objects

- Family/identity: `family_space`, `membership`, `user_profile`, role/permission helper functions.
- Finance: `account`, `category`, `transaction`, `transaction_split`, `envelope`, `envelope_tx`, `rate_snapshot`.
- Planning: `recurring_rule`, `budget_cycle_plan`.
- Savings/debt: `goal`, `goal_tx`, `family_debt`, `debt_repayment`, contribution and Mukando tables.
- Collaboration: shopping tables, chat, tasks, activity log, polls/votes/pins, push devices.
- Billing: `family_entitlement`, `billing_purchase_verification`.

### Live verification on 2026-10-22

Read-only linked queries confirmed:

- `family_entitlement` and `billing_purchase_verification` exist live.
- `family_chat_poll`, `family_chat_poll_vote`, and `family_chat_pin` exist live.
- `search_family_chat_messages(...)` and all five related poll/pin RPCs exist live as `SECURITY DEFINER` functions.
- RLS is enabled on all five new tables. Entitlements and each chat table have one read policy; purchase verification has zero client policies and is service-role-only by grants/design.
- `supabase_migrations.schema_migrations` is still absent. Deployment ordering/history cannot be proven or safely repaired from object presence alone.
- Deployed Edge Functions include active `verify-family-entitlement` version 5 (`verify_jwt=true`) and active `google-play-rtdn` version 5 (`verify_jwt=false`). The latter relies on its own Google Pub/Sub OIDC verification.

This supersedes the older checked-in live audit's statement that migration 047 was not yet live. Both 047 and 048 object sets are now present, but the missing migration ledger remains unresolved.

### Security observations

Strengths:

- Entitlement lookup authenticates the user and checks active family membership server-side.
- Purchase tokens are verified with Google Play and stored only as SHA-256 hashes.
- A purchase token cannot be claimed by a second family; a family is also prevented from silently claiming another unrelated purchase record.
- RTDN authenticates Pub/Sub OIDC and re-queries Google Play rather than trusting event payload state.
- Poll creation, new pins, and advanced search are checked server-side against family entitlement.
- Family-scoped SQL functions check membership rather than trusting the supplied family ID alone.

Risks requiring correction or explicit acceptance:

- `set_family_chat_pin` allows any current family member to unpin any message. The product requirement calls for authorized unpin behavior; define whether pin owner, message author, adults/admins, or all members may unpin, then enforce it server-side.
- `close_family_chat_poll` uses `is_adult`, whose current migrations map primarily to owner/admin semantics rather than every adult-like role. This may be intended but needs a named policy decision and tests.
- `vote_family_chat_poll` uses `ON CONFLICT DO NOTHING`, so a user cannot change a vote despite the UI maintaining selectable state; the error map references `ALREADY_VOTED`, but that error is not raised by the SQL.
- Poll SQL rejects blank options but does not reject duplicate normalized options server-side. Client duplicate validation silently disables creation and provides no clear message.
- The advanced-search SQL escapes `%` and `_` but does not declare an explicit `ESCAPE` clause; test literal wildcard behavior.
- Offset pagination exists in SQL, but Flutter never exposes it. Offset paging is also vulnerable to shifting results during concurrent chat activity; cursor paging on `(created_at,id)` is preferable.
- No server-side premium-write path may accept a cached offline entitlement. Future Plus writes must remain RPC/server authorized.
- Existing checked-in live audit reports a remote-only RLS event trigger and an extra activity push trigger containing an embedded webhook credential, plus a missing active-envelope uniqueness index. Those findings were not re-queried in this pass and remain open until remediated and reverified.
- Existing `profile_read` and private-account/transaction visibility concerns listed in `backend/README.md` remain launch-security work.

## 6. What can be reused

- `Money`, transaction/split semantics, cycle boundary functions, and test fixtures as the base of a single deterministic planning engine.
- Accounts plus explicit user-confirmed opening balance as planner inputs. Do not treat envelope allocation as cash.
- `RecurringRule` data and posted `recurring_rule_id` links as migration inputs for commitments, while preserving the free recurring-bill flow.
- `budget_cycle_plan` as the period header/snapshot, extended or complemented rather than replaced.
- Goals, goal contributions, debts, debt repayments, and shopping reuse primitives.
- Existing outbox, adapters, family bootstrap, conflict states, and deterministic UUID helpers.
- Membership/role helpers, audit triggers, and activity feed patterns.
- Family entitlement tables and server-verification boundary, after lifecycle hardening.
- Current chat storage and RPC layer; no new chat system is needed.
- Existing reminder planner/notifier, extended to schedule commitment occurrence reminders.

## 7. What must be improved versus newly implemented

### Improve existing

- Recurring rules: preserve free create/review/post/skip, but normalize recurrence and relate them to commitment occurrences/payments.
- Budget-cycle copy: add preview, selective multi-module reuse, adjustments, idempotent confirmation, and partial-target handling.
- Reports: replace scattered locked cards with one coherent Plus review, calculation explanations, currency boundaries, drill-down links, and actionable next steps.
- Savings/debt: model explicit contribution/repayment plans and scenario-only calculations.
- Polls: visible validation, normalized duplicate checks on client and server, accurate vote/update semantics, permission tests.
- Pins: dedicated area, original-message navigation, deleted-state behavior, cross-device refresh, explicit unpin authority.
- Search: true incremental/cursor pagination, clear empty/error/loading states, family-scoped tests.
- Billing: persisted bounded entitlement snapshot for offline read-only use, manage-subscription entry, pending/retry observability, family join/switch refresh, and lifecycle tests.
- Test reliability: fix the current baseline failures and async database teardown warnings.

### Newly implement

- First-class commitments and generated occurrences, including one-time and recurring commitments, outstanding/partial-payment state, pause/end, reminders, and safe links to existing transactions.
- Dated expected-income records separate from received transactions.
- Planning periods and explicit opening-balance confirmation.
- Pure deterministic forecast timeline with typed inputs: recorded balance, expected income, commitment occurrence, planned essential, savings allocation, estimate, and scenario adjustment.
- Ephemeral what-if scenarios that cannot mutate real records until separately confirmed.
- Idempotent period-preparation operation/preview spanning budgets, commitments, savings plans, and optional shopping reuse.
- Financial-health insight definitions with calculation evidence and drill-down targets.
- Explicit savings contribution plans and debt repayment plans/scenarios.
- A lightweight versioned business-operation contract only where it directly supports these workflows and future Assistant tooling; no autonomous AI or external model call.

## 8. Proposed database changes

Exact names and columns require Phase 1 design review. The smallest coherent forward-only direction is:

1. **Commitments**
   - `financial_commitment`: family, name, amount/currency, category/envelope link, recurrence definition, start/end/pause state, reminder policy, creator/audit fields.
   - `commitment_occurrence`: commitment, due date, amount/currency, state, stable recurrence key, optional skipped/canceled metadata; unique `(commitment_id, occurrence_key)`.
   - `commitment_payment`: occurrence, transaction, applied amount/currency, creator/time; unique transaction/occurrence association rules preventing duplicate application.
   - Prefer associations to existing `transaction`; never create an expense merely by creating a commitment.

2. **Planning**
   - `financial_plan` or an additive extension around `budget_cycle_plan`: explicit start/end, opening balance and confirmation metadata, currency, status/version.
   - `expected_income`: plan/family, expected date, amount/currency, confidence/status, optional eventual transaction association.
   - `planned_expense`: plan, type (`essential`, `savings_allocation`, `estimate`), date/window, amount/currency, category, source reference.
   - Scenario data should normally remain local/ephemeral; persist only named scenarios if product need is approved.

3. **Automated preparation**
   - `plan_preparation_operation`: stable operation ID, source/target periods, preview payload hash/version, actor, status, timestamps.
   - Unique keys on generated target records so retries return the same result rather than duplicate data.

4. **Savings/debt plans**
   - Normalized optional `savings_contribution_plan` and `debt_repayment_plan` with amount, currency, frequency, start/end, and active state. Plans do not mutate balances.

5. **Entitlement snapshot metadata**
   - Prefer encrypted/local family-and-user-scoped cache first; no database change is needed unless server returns a revocation/version token and explicit offline policy fields.

Every new table needs RLS, immutable family scope, guarded actor fields, indexes for family/date/status queries, audit events where financially relevant, and tests for removed/suspended members and cross-family IDs. Migrations must be forward-only and tested from zero. Do not apply production migrations until the missing migration ledger is reconciled.

## 9. Proposed implementation sequence

1. **Baseline stabilization before Phase 1:** agree how to preserve/split the large dirty worktree; fix or formally baseline the six Flutter failures; rerun migration chain in CI/disposable PostgreSQL; reconcile live migration history.
2. **Financial semantics ADR:** approve commitment/payment identity, currency policy, opening-balance authority, recurrence/time-zone rules, partial payments, and offline entitlement duration.
3. **Pure calculation package:** typed forecast inputs/results, no Flutter/database dependency, exhaustive unit tests including scenario isolation and multi-currency refusal/segmentation.
4. **Commitment foundation:** additive schema/RLS/adapters/local SQLite/outbox, occurrence generation and transaction association, then basic free CRUD.
5. **Payday planner:** explicit balance, expected income, commitments, essentials, savings allocation, timeline/shortfalls, and local what-if scenarios.
6. **Automated preparation:** preview and idempotent multi-module confirmation, preserving existing free allocation copy.
7. **Health/savings/debt:** coherent review and explicit plan-based projections.
8. **Chat completion:** polls, pinned hub, and paginated search hardening.
9. **Subscription UX/offline policy:** only advertise delivered features; lifecycle and sandbox verification.
10. **Release candidate:** full regression/security/financial suite, performance, migration rehearsal, recovery plan, and explicit launch approval.

## 10. Complexity and risk register

| Area | Complexity | Principal risk | Mitigation |
|---|---:|---|---|
| Commitments/occurrences/payments | High | Duplicate expenses or double-applied payments | Separate commitment from transaction; stable occurrence IDs; unique links; reconciliation tests |
| Payday forecast | High | Treating plans/allocations as cash or combining currencies | Typed inputs, explicit opening balance, per-currency timelines, pure tested engine |
| Offline sync for new entities | High | Retry duplicates, stale family data, partial multi-record writes | Existing outbox, idempotency keys, guarded family scope, operation status/recovery |
| Period preparation | High | Duplicating history or overwriting target records | Preview-first, target uniqueness, resumable operation record, no completed-expense copy |
| Entitlement/billing | High | Incorrect grants/revocations or unhandled Play state | Server-only writes, RTDN re-query, bounded cache, sandbox lifecycle matrix |
| Live migrations | Critical | No migration ledger; schema drift | Reconcile trusted history before any apply/repair; disposable full-chain test |
| Cross-currency reports | High | Misleading historical/current values | Snapshot/declared FX policy; never silently combine |
| Health insights | Medium–High | Plausible but unsupported claims | Evidence object per insight; period/source labels; drill-down |
| Chat Plus hardening | Medium | Stale pins, truncated results, ambiguous permissions | Realtime/event refresh, cursor paging, server authorization tests |
| Dirty worktree | High | Overwriting or misattributing existing work | Preserve all changes; isolate Phase 1 branch/commit only after owner decision |

## 11. Test results and required test coverage

### Current results

- `flutter analyze --fatal-infos`: **failed**, 2 info-level `prefer_const_declarations` findings in `test/theme_contrast_test.dart` lines 43 and 57.
- `flutter test`: **failed**, **402 passed / 6 failed**.
- Failures:
  1. `premium_pass_test.dart`: custom rate did not persist (`16.4` expected, `15.27` actual).
  2. `sync_test.dart`: premium entity push test cast a map response as a list.
  3. `budget_cycle_plan_test.dart`: chat adapter date round-trip differed by two hours (UTC/local-time expectation).
  4. `widget_screen_test.dart`: Family Chat task action finder could not locate the expected control.
  5. `widget_screen_test.dart`: edited/deleted own message did not show expected “Message was deleted”.
  6. `widget_screen_test.dart`: teen preview did not show expected “Previewing as Myla”.
- Focused `widget_screen_test.dart`: **23 passed / 3 failed**, confirming the three failures above.
- Database migration/smoke tests: **not run locally** because Docker/PostgreSQL clients are unavailable.
- Billing unit tests exist for fail-closed status parsing, expiry, feature keys, default-disabled flag, server-before-complete, and verification failure. No tests were found for Play product loading, restore completion timing, RTDN, polls/pins/search RPC SQL, or offline entitlement snapshots.

### Required additions

- Pure financial tests listed in the master prompt, especially missing balance, irregular/late income, same-commitment deduplication, partial payments, existing transaction association, period boundaries, scenario isolation, and currency separation.
- Property/invariant tests: a commitment never changes cash; scenario calculations never mutate repositories; each payment is applied at most once; preparation retry is idempotent.
- SQLite migration and restart tests for every new entity.
- Two-device offline conflict and family-switch tests for commitments/plans.
- SQL/RLS tests for every role, inactive membership, cross-family IDs, entitlement expiry, and premium RPC denial.
- Edge Function tests with mocked Google Publisher responses for active, pending, grace, canceled-active, expired, revoked/refunded, replayed, and out-of-order events.
- Real Google Play sandbox purchase/restore/lifecycle verification before release.
- Regression suite for authentication, onboarding, all existing finance modules, shopping, chat, tasks, notifications, reports, and sync.

## 12. Dirty worktree and unrelated changes

At audit start, Git reported **67 modified tracked files** with approximately **4,555 insertions and 1,676 deletions**, plus many untracked files. Changes span most of the Flutter app and tests, `backend/schema.sql`, backend docs, and chat migration 022.

Relevant untracked additions include:

- `app/lib/core/billing/`
- `app/lib/features/settings/plus_screen.dart`
- `app/lib/features/family_chat/family_polls_sheet.dart`
- billing tests under `app/test/core/billing/`
- migrations `042` through `048`
- Supabase billing Edge Functions and config
- live-schema/billing proposal documents

Apparently unrelated untracked artifacts include `tmp/pdfs/` and a PrimeTestLab report. No existing changes or artifacts were modified or deleted during this audit.

Before Phase 1, decide whether the current tree should be committed as a baseline, split into reviewed commits, or preserved on a dedicated branch. Do not mix v2 schema work into it without that decision.

## 13. Decisions requiring approval

Phase 1 should not begin until the owner approves or answers:

1. **Dirty baseline:** preserve and adopt the current uncommitted Plus/billing/chat work as the starting baseline, or first split/review it?
2. **Migration history:** who owns the trusted deployment history, and may the team reconcile/repair the absent Supabase migration ledger after object-by-object verification?
3. **Commitment model:** should existing recurring rules be migrated into a generalized commitment model while keeping the current free workflow?
4. **Partial payments:** may one transaction pay multiple commitment occurrences and may one occurrence link multiple transactions? Recommended: support both through an allocation table, same currency only unless explicit conversion metadata exists.
5. **Opening balance:** recommended policy is user-confirmed per planner/currency, prefilled from recorded accounts/ledger with timestamp and explanation, never silently assumed authoritative.
6. **Currency policy:** recommended v2 policy is separate forecasts per currency; defer conversion-based consolidated forecasts until historical/assumption FX rules are approved.
7. **Recurrence/time zone:** approve supported patterns, end conditions, due-date clamping (for example the 31st), and Africa/Harare versus family-configurable time zone semantics.
8. **Offline Plus:** approve a bounded family+user-scoped read-only cache duration. Recommended initial maximum: 72 hours after server verification, with no cached authorization for premium writes.
9. **Roles:** define who may create/edit commitments, confirm plan preparation, close polls, pin/unpin, and manage subscriptions. Current client/server use of “adult” is not uniform enough to infer safely.
10. **Feature packaging:** confirm that basic commitments stay Free while advanced recurrence/reminders/forecast integration are Plus, and that existing free reports/copy flows remain free.
11. **Billing:** keep public billing disabled until all premium features advertised on the Plus page exist, migration history is reconciled, secrets/products/RTDN are verified, and sandbox lifecycle tests pass.
12. **Test gate:** approve fixing the six pre-existing test failures and two analysis infos as baseline stabilization before feature implementation.

## Approval gate

Phase 0 is complete. **Stop here.** No Phase 1 implementation, migration creation/application, pricing change, or billing enablement should proceed without explicit approval.
