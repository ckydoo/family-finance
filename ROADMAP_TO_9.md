# ROADMAP TO 9.0 — exact gaps (2026-09-22)

Supersedes ROADMAP_TO_8.md. Server state: migrations 000–008 all applied by the
user (confirmed). Backend integrity is proven on real Postgres (CI + smoke test).
This file lists ONLY what is still missing, per the agreed 9/10 plan, tagged
**(F)** = Flutter frontend, **(B)** = backend/migration, **(B+F)** = both.

## Phase 1 leftovers (blockers on the 6.5 floor)

| # | Gap | Where | Notes |
|---|-----|-------|-------|
| 1 | **Password recovery completion** | **(F+B)** | ✅ DONE 2026-09-22: deep link `mhuri://reset-callback` (Android intent-filter + iOS scheme, app_links), recovery-session adoption on link open AND resume-on-restart (`pw_reset_pending`), create-new-password screen with strength checklist + inline errors, expired/single-use link state with resend, PKCE-code link → honest expired state. Tests: recovery_link_test + recovery_password_test. USER ACTION: allow-list `mhuri://reset-callback` in Auth → URL Configuration. |
| 2 | **Shopping-list sync** | **(B+F)** | ✅ DONE 2026-09-22: header is a synced entity (adapter, local table, db v5), `create_space` returns `default_list_id` (creating device) and joiners learn it from the header pull — fixed the latent `list_id: null` push bug; `deleted_at` tombstones on list + items (migration 009 + backfill for pre-008 families), deleteItem + ✕ affordance in the list UI. Two-offline-device convergence proven in the backend smoke suite (9 checks green). |
| 3 | **RLS verified per synced table + roles tested against real Supabase** | **(B)** | Local smoke test proves profile scoping on stubs. Still to run: the 10 two-device scenarios against the real project (roles as anon/authenticated). Mostly a runbook + execution task, little code. |
| 4 | Tests on device (`flutter analyze/test` green incl. the 4 new suites) | (F) | User-machine run; nothing to build here until results come back. |

## Phase 2 — Complete family experience (the big block to 7.5)

| # | Gap | Where | Notes |
|---|-----|-------|-------|
| 5 | **Real invitations** | **(B+F)** | ✅ DONE 2026-09-22: `family_invite` (role-bound adult/co_parent/teen/kid/viewer, optional email bind, 7-day expiry, revoke, single-use, max 5 open), `create_invite`/`revoke_invite`/`join_invite` (one INVALID_CODE for every dead-code reason — no probing), Invite screen with QR + share + pending list + revoke, `mhuri://join?c=` deep link prefills the join step, optional email Edge Function (`supabase/functions/invite-email`). Static family code still works in parallel. |
| 6 | **3-level role enforcement** | **(B+F)** | ✅ DONE 2026-09-22: `role_perm()` makes RLS read the switches at query time (transaction writes, budget/wallet visibility; defaults mirror the onboarding map); engine pulls settings → AppState getters; Teen Zone peek honours the switch. 6 new smoke checks prove each flip. Server = the boundary. |
| 7 | **Ownership transfer** | **(B+F)** | ✅ DONE 2026-09-22: `transfer_ownership` swaps roles, MOVES the family's static invite code with the crown (unique-index detail), writes an audit row; "Make owner" with confirmation in the member popup. Deletion loop (008) now completable. |
| 8 | **Two-device sync reliability** | **(F mostly)** | ✅ DONE 2026-09-22: 401→refresh→retry-once (engine retryAuth), parked-changes UI on Sync & data with per-item retry/confirmed discard, reinstall reconciliation (`restore_my_space` RPC + restoreFamily — setup skipped, full pull, no duplicates), conflict rules documented per entity (backend/SYNC_CONFLICTS.md). Tombstones: live for list_item/shopping_list (+ tx server-side); pattern documented for future delete UIs. |
| 9 | **Audit completion** | **(B)** | ✅ DONE 2026-09-22: triggers append `tx.create`, `goal.contribute`, `request.approve`, `request.decline` (actor = decided_by); create/join/leave/invite/transfer from 008+010. Append-only; hash chain still out (no tamper-evidence claim). |
| 10 | Account-deletion UX completion | (F) | ✅ DONE 2026-09-22: what-happens sheet (owner vs member wording, sessions line) → typed DELETE → non-dismissible progress with the four server phases. |

## Phase 3 — Premium interface (7.5 → 8.5)

| # | Gap | Where | Notes |
|---|-----|-------|-------|
| 11 | **Shared component system** | (F) | ✅ DONE 2026-09-22: `lib/core/widgets/ui.dart` — MhuriCard, SectionHeader, PrimaryButton, EmptyHint, confirmDialog. Adopted: Sync & data, Settings headers, both discard-guard dialogs. Remaining screens migrate opportunistically under the "new code MUST use the kit" rule (no mass rewrites of working screens). |
| 12 | **Full l10n sweep** | (F) | ✅ DONE 2026-09-22: zero ARB keys without generated code (the last 10 stragglers generated); family_setup_screen fully localized (537 keys ×6, generated ×7, full parity). Remaining for 8.5 polish: plurals/dates systematization + sn/nd fluent review + fr/pt overflow check on device. |
| 13 | Forms hardening | (F) | ✅ DONE 2026-09-22: unsaved-changes guards (setup PopScope + envelope sheet, warn-only-with-data), persistent labels + inline errors + currency keyboards + double-submit locks verified everywhere. |
| 14 | Motion + haptics + reduced-motion | (F) | ✅ VERIFIED 2026-09-22: reduced-motion already honoured (disableAnimationsOf in motion.dart/celebrate/rings), selective 150–250ms durations, haptics on key actions. |
| 15 | Structural accessibility | (F) | ✅ AUDITED 2026-09-22: zero icon-only buttons without tooltips, 44×44+ targets, largeText scaler, labeled nav. Device-session item: WCAG AA contrast render check both themes. |
| 16 | Progressive disclosure + prototype sweep | (F) | ✅ DONE 2026-09-22: fake QR removed (real mhuri://join QR in setup), zero placeholder/demo/coming-soon UI strings. |

## Phase 4 — Production hardening (8.5 → 9.0)

| # | Gap | Where | Notes |
|---|-----|-------|-------|
| 17 | Environments dev/staging/prod | **(B)** | One Supabase project today. Second (staging) project + env config; never destructive-test prod. |
| 18 | CI completion | (B) | Have: migration chain + analyze/test. Add: `flutter format` gate, secret scanning, android/ios build jobs, Actions enabled on GitHub + branch protection. |
| 19 | Observability | (B+F) | `SyncEngine.reportError` hook → debugPrint only. Wire Sentry/crashlytics, sync-health events, correlation IDs, deletion audit trail; never log secrets/amounts. |
| 20 | Backups + restore drill | (B) | Supabase PITR/exports enabled; DOCUMENTED restore drill executed once. |
| 21 | Privacy docs + store QA | (F/docs) | Privacy policy (data collected: email, avatars, financial rows — family-scoped RLS), data-safety forms, store listing screenshots. |

## Critical path (recommended build order)

1. **#1 Password recovery** — users can lock themselves out today. Deep-link infra lands here and is reused by invitations.
2. **#2 Shopping-list sync + tombstones** — closes Phase 1.
3. ✅ **#5 Invitations + #7 ownership transfer** — DONE 2026-09-22.
4. ✅ **#6 Role enforcement + #9 audit** — DONE 2026-09-22.
5. ✅ **#8 Sync reliability** — DONE 2026-09-22. **Phase 2 core complete** (#5 invitations, #6 roles, #7 transfer, #8 sync, #9 audit). Remaining from Phase 2: #10 deletion UX polish + the 10 real-device scenarios.
6. ✅ **Phase 3 (#10–#16)** — DONE 2026-09-22 (device-session leftovers: AA render check, sn/nd fluent review, fr/pt overflow).
7. **#17–#21 Phase 4** release engineering.

Rough sizing in sandbox sessions: #1 ≈1, #2 ≈1, #5+#7 ≈2, #6+#9 ≈1, #8 ≈1–2, Phase 3 ≈3–4, Phase 4 ≈2. Each round ships with migrations called out for your SQL-editor run + a PAT push at the end, as usual.
