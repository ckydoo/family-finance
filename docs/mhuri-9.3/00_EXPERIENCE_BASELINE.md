# Mhuri 9.3 — Phase 0 Experience Baseline

**Date:** 2026-11-07  
**Target:** Mhuri 9.3 Experience Plan  
**Status:** Baseline Established & Instrumented

---

## 1. Baseline User Journeys

### 1.1 First-Run & Create-Family Journey
- **Pre-9.3 Baseline:**
  1. Step 1 (`create`): Enter preferred name, family name, optional photo.
  2. Step 2 (`currencies`): Select primary currency, optional secondary currency, and payday month start day (1–31).
  3. Step 3 (`spending`): Select starter templates and custom categories.
  4. Step 4 (`ready`): Summary screen before entering Home or adding income.
- **9.3 Target:**
  - Keep the initial create-family path to three core decisions: **your name**, **family name**, and **primary currency**, with sensible defaults for budget cycle and starter budgets and a concise edit option.
  - Defer secondary currency, profile photo, and advanced preferences until after the first useful journey.
  - Guide the household through: (1) Add money coming in, (2) Set or confirm one budget, (3) Record one expense.

### 1.2 Join-Family Journey
- **Flow:**
  - Invited users (via pending server invite, deep link `mhuri://join?c=...`, or manual code) enter their preferred name and invite code directly without being forced through family creation.

### 1.3 Repeat Expense Entry Journey
- **Pre-9.3 Baseline:**
  1. Tap central **+** FAB on `AdultShell`.
  2. Intermediate modal sheet (`Quick add`) opens with 4 options (Expense, Income, Shopping item, Task).
  3. Tap **Expense** to open `_QuickAddSheet`.
  4. Enter amount, open budget picker sheet to select a recent budget, expand "More details" to pick payment method, tap **Add expense**.
  5. Snackbar shows without an Undo action.
- **9.3 Target (<= 5s median):**
  1. Tap central **+** FAB on `AdultShell` &rarr; opens **Expense** directly with amount field focused and numeric keyboard presented.
  2. Defaults to signed-in member, space-scoped last-used currency, last-used payment method (visible), and recent budget chips (3–5 chips + **No budget**).
  3. Secondary actions (**Add something else**: Income, Shopping item, Task) are clearly labelled and one tap away.
  4. Saving shows a floating snackbar with an **Undo** action that performs a real reversible tombstone (`AppState.deleteTx`) that survives sync.

### 1.4 Home Dashboard Comprehension Journey
- **Pre-9.3 Baseline:**
  - Displays greeting, `_PoolCard`, `_CycleBoundaryNotice`, `_MonthlySummary`, `_NeedsAttention`, `_ComingUp`, `Tasks coming up` (2 rows), `_HomeBudgets` (all household budgets in horizontal scroll), `SmartCard`, and up to 6 recent transactions.
- **9.3 Target Hierarchy:**
  1. Greeting and family switcher
  2. Available-to-spend card
  3. Income / Spent / Remaining
  4. One personalised **Next best action** (prioritised queue with count / **Review all** route when others remain)
  5. Up to three important household budgets (ordered by urgency, then proximity to limit)
  6. Up to three recent transactions
  7. Clear **See all** destinations

---

## 2. Privacy-Safe Product Events (`MhuriAnalyticsEvents`)

Implemented in `app/lib/core/observability/reporter.dart`:

| Event Name | Allowed Fields | Redacted / Forbidden Fields |
|---|---|---|
| `quick_add_opened` | `entry_type`, `role`, `locale`, `source` | Amounts, notes, names, receipts |
| `quick_add_completed` | `entry_type`, `duration_ms`, `role`, `locale`, `used_recent_budget` | Amounts, notes, names, receipts |
| `transaction_saved` | `entry_type`, `duration_ms`, `role`, `locale`, `success` | Amounts, notes, names, receipts |
| `transaction_cancelled` | `entry_type`, `duration_ms`, `dirty`, `role`, `locale` | Amounts, notes, names, receipts |
| `transaction_undo_selected` | `entry_type`, `role`, `locale` | Amounts, notes, names, receipts |
| `onboarding_step_started` | `step`, `role`, `locale` | Family name, member name, email |
| `onboarding_step_completed` | `step`, `duration_ms`, `role`, `locale` | Family name, member name, email |
| `onboarding_step_abandoned` | `step`, `duration_ms`, `role`, `locale` | Family name, member name, email |
| `guided_first_journey_completed` | `role`, `locale` | Amounts, family name |
| `home_next_action_opened` | `action_kind`, `remaining_count`, `role`, `locale` | Amounts, notes, member names |
| `family_invite_opened` | `source`, `role`, `locale` | Invite code, email, family name |
| `family_invite_accepted` | `duration_ms`, `role`, `locale`, `success` | Invite code, email, family name |
| `family_invite_failed` | `error_category`, `role`, `locale` | Invite code, email, family name |
| `weekly_summary_viewed` | `has_sufficient_data`, `role`, `locale` | Amounts, notes, family name |
| `weekly_summary_shared` | `role`, `locale` | Amounts, notes, family name |
| `sync_recovery_opened` | `pending_count`, `role`, `locale` | Payload, row contents |

`redactFields` enforces redaction defensively at the reporter boundary so no sensitive field can ever leak to an analytics or crash backend.
