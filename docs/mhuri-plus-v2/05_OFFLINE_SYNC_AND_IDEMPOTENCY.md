# Offline Sync & Idempotency — Mhuri Plus v2

**Date:** 2026-10-22  
**Branch:** `codex/mhuri-plus-v2`

---

## 1. Offline-First Persistence & Outbox Architecture

Mhuri Plus v2 integrates cleanly into the existing SQLite (`AppDatabase` v25 + `LocalStore`) and Supabase outbox (`SyncService` + `SyncAdapter`) architecture:

1. **Local SQLite Durability First:**
   - Every user action mutates `AppState` only after validating invariants, persists immediately to SQLite via `LocalStore` (tracked by `AppDatabase.trackWrite` so tests and shutdown hooks can await `flushWrites()`), and enqueues an outbox mutation (`_queue(entity, model)`).
2. **Dependency-Ordered Synchronization (`app/lib/core/sync/sync_service.dart`):**
   - Outbox pushes and incremental pulls respect referential dependencies:
     - `financial_commitment` -> `commitment_occurrence` -> `commitment_payment`
     - `budget_plan` / `envelope` / `shopping_item`
3. **Account & Family Cache Isolation:**
   - `AppState.resetForAccount`, `AppState.syncIdentityChanged`, and the persistence cache reset clear `financial_commitment`, `commitment_occurrence`, `commitment_payment`, `period_preparation`, and the cached `family_entitlement_v1` snapshot whenever a user signs out, switches accounts, or switches families.

---

## 2. Idempotency & Duplicate Prevention Guarantees

### A. Smart Bills & Commitments (`app/lib/core/planning/commitments.dart`)
- **Occurrence Generation (`generateCommitmentOccurrences`):**
  - Each occurrence has a canonical `occurrenceKey` (`YYYY-MM-DD`) and a deterministic UUID (`uuidFromSeed('commitment-occurrence:${commitment.id}:$occurrenceKey')`).
  - Re-running occurrence generation across app restarts, period preparation, or multiple devices produces the exact same `id` and `(commitment_id, occurrence_key)` pair.
  - Enforced at three layers: in-memory deduplication, SQLite `UNIQUE(commitment_id, occurrence_key)`, and PostgreSQL `UNIQUE (commitment_id, occurrence_key)` (`049_financial_commitments.sql`).
- **Commitment Payment Association (`associateCommitmentPayment`):**
  - Payment IDs are deterministic or caller-supplied UUIDs (`payment:${occurrence.id}:$txId:...`).
  - Rejects duplicate payment IDs, non-existent or soft-deleted transactions, non-expense transactions, currency mismatches, amounts exceeding `commitmentOutstanding(occurrence)`, and amounts exceeding `transactionUnallocatedForCommitments(tx)`.
  - Creating a commitment or occurrence never creates an expense transaction.

### B. Automated Period Preparation (`app/lib/core/planning/period_preparation.dart`)
- **Preview-First Durable Operation (`PeriodPreparationOperation`):**
  - Every preview creates a deterministic `operationId` stored in SQLite table `period_preparation` with status `preview`.
- **Crash-Resilient & Retry-Safe Application (`applyPeriodPreparation`):**
  - Before writing records, status transitions to `applying` and is persisted to SQLite.
  - Deterministic target record IDs:
    - Budget plan ID: `uuidFromSeed('period-prep-plan:${operation.operationId}:${allocation.envelopeId}')`
    - Shopping item ID: `uuidFromSeed('period-prep-shop:${operation.operationId}:${item.id}')`
    - Commitment occurrence IDs: `uuidFromSeed('commitment-occurrence:${commitment.id}:$occurrenceKey')`
  - If an operation is already `applied`, re-applying is a no-op that returns `PeriodPreparationOutcome.alreadyApplied`.
  - If the app restarts mid-apply (`status == applying`), re-invocation safely completes any missing deterministic records and transitions to `applied`.
  - If the target period already has unrelated budget plans from another source, application fails closed (`PeriodPreparationOutcome.conflict`) without overwriting existing plans.
  - Historical completed expenses, debt principal, debt repayments, and posted savings contributions are **never** copied.

### C. Offline Entitlement Cache (`app/lib/core/billing/entitlement.dart`)
- **Bounded 72-Hour Offline Grace:**
  - Verified server responses from `verify-family-entitlement` are persisted to `kv_store['family_entitlement_v1']` with `familyId`, `userId`, `verifiedAt`, `expiresAt`, `status`, and `features`.
  - On cold start offline, `AppState._restoreOfflineEntitlement` restores the snapshot (`isOfflineSnapshot = true`) **only if**:
    1. `snapshot.familyId == currentSpaceId`
    2. `snapshot.userId == currentAuthUserId`
    3. `now.difference(snapshot.verifiedAt) <= FamilyEntitlement.maxOfflineCacheAge` (72 hours)
    4. `snapshot.expiresAt == null || snapshot.expiresAt.isAfter(now)`
    5. `snapshot.status` is `active` or `grace`
  - Once 72 hours elapse without server re-verification, `isActiveAt(now)` returns `false` and Plus features fail closed until online refresh succeeds.

