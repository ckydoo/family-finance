# Phase A — Baseline Stabilization

**Date:** 2026-10-22  
**Branch:** `codex/mhuri-plus-v2`  
**Starting revision:** `ba072a33076c77d4350ae9d5d301419302286ba9`

## 1. Preservation & Workspace Isolation

The existing dirty working tree (~67 modified tracked files plus untracked work) was preserved and moved intact onto the dedicated local branch `codex/mhuri-plus-v2`. No file was discarded, reset, stashed, or force-overwritten. Production data, live Supabase migrations, deployed Edge Functions, credentials, billing flags (`MHURI_BILLING_ENABLED` remains `false`), and Google Play Store configuration were not changed.

## 2. Stabilization Changes

1. **Exchange-rate persistence on secondary currency toggle:** Restored persistence of a user-configured exchange rate when a secondary currency is temporarily disabled (`app/lib/core/state/app_state.dart`).
2. **Deleted-message tombstones vs. search filtering:** Restored deleted-message tombstones in the ordinary chat timeline while keeping soft-deleted messages out of search results (`app/lib/features/family_chat/family_chat_screen.dart`).
3. **Teen Zone preview banner:** Restored the visible, escapable Teen Zone preview banner (`app/lib/features/home/home_shell.dart`).
4. **Chat attachment accessibility test:** Updated the chat attachment test to match the current accessible tooltip (`app/test/chat_attachment_flow_test.dart`).
5. **Sync payload-shape assertion:** Restricted the table-upsert payload assertion to table-upsert requests rather than unrelated RPC POST bodies (`app/test/sync_service_test.dart`).
6. **Timezone-safe chat timestamp test:** Made the chat timestamp test compare instants rather than machine-local representations (`app/test/family_chat_screen_test.dart`).
7. **Analyzer clean-up:** Resolved all `flutter analyze --fatal-infos` findings across the codebase.
8. **Asynchronous SQLite teardown lifecycle fix:** Added `AppDatabase.trackWrite` / `flushWrites()` (`app/lib/core/db/app_database.dart`) and `AppState.flushWrites()` (`app/lib/core/state/app_state.dart`) and updated SQLite-backed tests to await pending persistence futures before closing in-memory databases, eliminating the asynchronous `error DatabaseException(database_closed)` teardown warnings without suppressing database errors.

## 3. Baseline Verification

- `flutter analyze --fatal-infos`: **PASS — No issues found**.
- Baseline 408 Flutter tests: **PASS — 0 failures, 0 async SQLite teardown warnings**.
- Extended Mhuri Plus v2 test suite: **PASS** (see `07_TEST_EVIDENCE.md`).
- SQL migration chain: **Prepared as forward-only migrations (`049`, `050`); NOT applied to live production** (Docker and local PostgreSQL client tools are unavailable on this machine; live schema changes require explicit approval).

## 4. Object-by-Object Live Migration Reconciliation Proposal

Read-only catalog inspection from the Phase 0 audit confirmed that entitlement and Plus chat objects from local migrations `047`–`048` exist in the live Supabase database with RLS enabled, and that `verify-family-entitlement` and `google-play-rtdn` Edge Functions are deployed and active, while `supabase_migrations.schema_migrations` is empty/absent.

**We do not mark migration history as repaired merely because live objects exist.** Before any production migration apply or repair:

1. **Obtain trusted deployment provenance:** Retrieve the historical deployment log from the project owner.
2. **Canonical catalog diff across `000`–`048`:** Export live `pg_catalog` definitions for tables, columns, check constraints, unique indexes, RLS policies, `SECURITY DEFINER` routines, triggers, grants, and storage policies, and diff against a clean scratch run of `000`–`048`.
3. **Resolve known schema drift via forward-only migrations:**
   - Missing `envelope_space_name_unique` index: now included idempotently in `backend/migrations/050_plus_chat_and_security_hardening.sql`.
   - Remote-only `rls_auto_enable` event trigger: preserve and codify in baseline reconciliation script.
   - Remote-only `on_activity_log_created_push` trigger: replace hardcoded bearer token with Supabase Vault secret lookup before codifying.
4. **Rehearse in disposable staging:** Run `000`–`050` from zero on a disposable Supabase/PostgreSQL instance, then rehearse applying `049` and `050` plus `schema_migrations` ledger backfill against a production schema clone.
5. **Explicit approval gate:** Require database backup verification and explicit owner sign-off (documented in `RELEASE_APPROVALS_REQUIRED.md`).

## 5. Security & Credential Hygiene

- The hardcoded bearer credential reported in the live `on_activity_log_created_push` trigger is treated as exposed; its secret value was never queried, printed, or written to repository files.
- RLS hardening for `profile_read`, `personal_account`, `transaction_item`, `transaction_allocation`, and Plus chat RPCs is authored in `backend/migrations/050_plus_chat_and_security_hardening.sql` (detailed in `04_SECURITY_RLS_MATRIX.md`).
- Public billing remains disabled by default (`MHURI_BILLING_ENABLED = false`).
