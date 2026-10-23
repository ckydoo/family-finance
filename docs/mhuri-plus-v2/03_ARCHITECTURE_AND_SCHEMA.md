# Architecture and Schema — Mhuri Plus v2

**Date:** 2026-10-22  
**Branch:** `codex/mhuri-plus-v2`  
**Local SQLite Schema Version:** `25`  
**Forward-Only PostgreSQL Migrations Added:** `049_financial_commitments.sql`, `050_plus_chat_and_security_hardening.sql`

---

## 1. Layered Architecture Overview

Mhuri Plus v2 extends the existing offline-first Flutter + SQLite + Supabase architecture without replacing any Free workflows:

1. **Deterministic Domain & Planning Layer (`app/lib/core/planning/`):**
   - `financial_planner.dart`: Pure payday-to-payday forecast engine (`FinancialPlanner.forecast`) with confirmed opening balance enforcement, chronological tie-breaking, shortfall transition detection, non-destructive `ScenarioChange` overlays, and per-currency isolation.
   - `commitments.dart`: Pure commitment schedule (`FinancialCommitment`), occurrence generation (`CommitmentOccurrence`), partial/full transaction-linked payment associations (`CommitmentPayment`), and reminder derivation (`CommitmentReminder`).
   - `period_preparation.dart`: Preview-first, idempotent period preparation engine (`PeriodPreparationEngine`) with durable operation state (`PeriodPreparationOperation`) and conflict detection.
   - `financial_health.dart`: Evidence-backed `FinancialHealthEngine` computing income vs. expense, budget vs. actual (including split transaction `txAllocations` attribution), category deltas, upcoming commitments, savings progress, debt repayment progress, and evidence-linked recommendations.
   - `savings_debt_planner.dart`: Pure `SavingsDebtPlanner` for recurring contribution schedules, debt payoff schedules, target-date evaluation, and side-by-side what-if payment comparisons without inventing interest rates.
2. **Typed Business Operation Contract Layer (`app/lib/core/operations/business_operation_contract.dart`):**
   - `BusinessOperationDispatcher` providing a single validated boundary for UI and future Mhuri Assistant invocations with permission checks, Plus entitlement enforcement, preview-before-commit tokens, idempotency cache, and structured `BusinessOperationAudit` records.
3. **Persistence & Sync Layer (`app/lib/core/db/`, `app/lib/core/sync/`):**
   - `app_database.dart`: SQLite schema v25 with tracked async write barriers (`trackWrite` / `flushWrites()`).
   - `persistence.dart`: Typed CRUD for commitments, occurrences, payments, and durable `period_preparation` records.
   - `sync_mappers.dart` & `sync_service.dart`: Outbox serialization and ordered dependency pull (`financial_commitment` -> `commitment_occurrence` -> `commitment_payment`).
4. **Entitlement & Billing Layer (`app/lib/core/billing/`):**
   - `entitlement.dart`: `FamilyEntitlement` with 72-hour bounded offline cache (`maxOfflineCacheAge`), family + user binding, and `kPlusV2Features`.
   - `billing_service.dart`: Play Store product queries (`mhuri_plus_monthly`, `mhuri_plus_annual`), purchase stream handling, and server verification via `verify-family-entitlement`.

---

## 2. Local SQLite Schema Additions (v24 & v25)

### Schema v24 — Smart Bills & Commitments
- `financial_commitment`:
  - `id TEXT PRIMARY KEY`
  - `space_id TEXT`
  - `name TEXT NOT NULL`
  - `amount_minor INTEGER NOT NULL`
  - `currency TEXT NOT NULL`
  - `first_due_date TEXT NOT NULL`
  - `recurrence TEXT NOT NULL` (`oneTime`, `weekly`, `biweekly`, `monthly`, `quarterly`, `yearly`)
  - `status TEXT NOT NULL` (`active`, `paused`, `ended`, `archived`)
  - `end_date TEXT`
  - `envelope_id TEXT`
  - `payee TEXT NOT NULL DEFAULT ''`
  - `note TEXT NOT NULL DEFAULT ''`
  - `reminder_days_before TEXT NOT NULL DEFAULT '[]'` (JSON int array)
  - `created_by TEXT NOT NULL`
  - `created_at TEXT NOT NULL`
  - `updated_at TEXT NOT NULL`
- `commitment_occurrence`:
  - `id TEXT PRIMARY KEY`
  - `space_id TEXT`
  - `commitment_id TEXT NOT NULL`
  - `occurrence_key TEXT NOT NULL` (`YYYY-MM-DD`)
  - `due_date TEXT NOT NULL`
  - `amount_minor INTEGER NOT NULL`
  - `currency TEXT NOT NULL`
  - `status TEXT NOT NULL` (`upcoming`, `partiallyPaid`, `paid`, `skipped`, `canceled`)
  - `UNIQUE(commitment_id, occurrence_key)`
- `commitment_payment`:
  - `id TEXT PRIMARY KEY`
  - `space_id TEXT`
  - `occurrence_id TEXT NOT NULL`
  - `transaction_id TEXT NOT NULL`
  - `amount_minor INTEGER NOT NULL`
  - `currency TEXT NOT NULL`
  - `created_by TEXT NOT NULL`
  - `created_at TEXT NOT NULL`

### Schema v25 — Durable Period Preparation Operations
- `period_preparation`:
  - `operation_id TEXT PRIMARY KEY`
  - `space_id TEXT`
  - `target_period_key TEXT NOT NULL`
  - `status TEXT NOT NULL` (`preview`, `applying`, `applied`, `failed`)
  - `payload_json TEXT NOT NULL`
  - `updated_at TEXT NOT NULL`

---

## 3. PostgreSQL Migrations Prepared (Not Applied to Live Production)

### `backend/migrations/049_financial_commitments.sql`
- Creates `public.financial_commitment`, `public.commitment_occurrence`, and `public.commitment_payment`.
- Enforces currency codes (`USD`, `ZWG`, `ZAR`, `GBP`, `EUR`, `BWP`, `ZMW`, `MZN`, `AUD`, `CAD`), positive integer `amount_minor`, and valid recurrence/status enums.
- Triggers:
  - `validate_commitment_occurrence_row()`: verifies parent commitment exists, currency matches, and `space_id` is inherited from parent.
  - `validate_commitment_payment_row()`: verifies occurrence and expense transaction exist in the same family `space_id` and currency, rejects non-expense or soft-deleted transactions, prevents overpayment beyond occurrence amount, prevents over-allocation beyond transaction amount, and updates `commitment_occurrence.status` (`upcoming` / `partiallyPaid` / `paid`).
- Enables RLS with `is_space_member(space_id)` read policies and non-viewer (`role <> 'viewer'`) write policies.

### `backend/migrations/050_plus_chat_and_security_hardening.sql`
- **Plus Chat RPC Hardening:**
  - `create_family_poll`: trims options, rejects empty/blank options, rejects case-insensitive duplicate options (`lower(btrim(opt))`), and requires at least 2 distinct options (`22023`).
  - `vote_family_poll`: verifies poll is open (`closed_at IS NULL` and not expired) before allowing atomic vote insertion or replacement (`ON CONFLICT (poll_id, user_id) DO UPDATE`).
  - `close_family_poll`: restricts closing a poll to the poll creator (`created_by = auth.uid()`) or family `owner`/`adult`.
  - `unpin_family_message`: restricts unpinning to the member who pinned the message (`pinned_by = auth.uid()`) or family `owner`/`adult`.
  - `search_family_messages`: escapes `LIKE` wildcards (`\`, `%`, `_`) and uses explicit `ESCAPE '\'` with bounded limit `[1, 100]` and offset `>= 0`.
- **RLS & Schema Drift Hardening:**
  - Replaces overly permissive `profile_read` (`USING (true)`) with self-or-shared-space membership check.
  - Tightens `personal_account`, `transaction_item`, and `transaction_allocation` policies so private (`visibility = 'private'` or `personal_account_id IS NOT NULL`) records are restricted to `created_by = auth.uid()` (or personal account owner).
  - Adds missing `envelope_space_name_unique` index safely with a pre-check for duplicate names.

