# Future Mhuri Assistant Compatibility — Typed Business Operation Contract

**Date:** 2026-10-22  
**Contract Version:** `kBusinessOperationContractVersion = 1`  
**Implementation:** `app/lib/core/operations/business_operation_contract.dart`  
**Verification Suite:** `app/test/business_operation_contract_test.dart`

---

## 1. Architectural Purpose

Section 17 requires that Mhuri Plus v2 be structured so a future Mhuri Assistant can invoke deterministic, auditable, permission-checked business operations without directly mutating database tables or bypassing financial invariants.

No LLM, chat bot UI, or external AI service is enabled in Mhuri Plus v2. Instead, `BusinessOperationDispatcher` provides a pure, versioned, strongly-typed operation boundary on top of `AppState` and the Phase B–G calculation engines.

---

## 2. Supported Operations (`BusinessOperationKind`)

### Read / Query Operations (No Side Effects)
1. `queryAvailableBalance` (`AvailableBalanceQuery` -> `AvailableBalanceView`)
   - Computes recorded ledger inflow minus outflow for an explicit `Currency` and reports whether an opening balance is confirmed or derived from ledger activity.
2. `queryUpcomingCommitments` (`UpcomingCommitmentsQuery` -> `UpcomingCommitmentsView`)
   - Requires Plus feature `smart_commitments`. Returns upcoming and overdue occurrences in the requested currency and horizon, with outstanding minor-unit amounts and total outstanding balance.
3. `queryPaydayForecast` (`PaydayForecastQuery` -> `PaydayForecast`)
   - Requires Plus feature `cash_flow_forecast` and explicit `openingBalanceConfirmed: true`. Delegates to `FinancialPlanner.forecast`.
4. `queryFinancialHealth` (`FinancialHealthQuery` -> `FinancialHealthReport`)
   - Requires Plus feature `advanced_insights`. Delegates to `FinancialHealthEngine.evaluate`.
5. `querySavingsProjection` (`SavingsProjectionQuery` -> `PlanProjection`)
   - Requires Plus feature `savings_projections`. Delegates to `SavingsDebtPlanner.projectSavingsGoal`.

### Mutating Operations (Require Preview Token + Explicit User Confirmation)
6. `recordExpenseTransaction` (`RecordExpenseInput` -> `Tx`)
   - Validates positive minor units, non-empty category/note, and `state.canAuthorTransact`.
7. `createFinancialCommitment` (`CreateCommitmentInput` -> `FinancialCommitment`)
   - Requires Plus feature `smart_commitments` and `state.canAuthorTransact`. Validates positive minor units and recurrence schedule. Never creates an expense transaction.
8. `associateCommitmentPayment` (`AssociateCommitmentPaymentInput` -> `CommitmentPayment`)
   - Requires Plus feature `smart_commitments` and `state.canAuthorTransact`. Enforces currency match, occurrence outstanding limit, and transaction unallocated limit.
9. `prepareNextPeriod` (`PrepareNextPeriodInput` -> `PeriodPreparationApplyResult`)
   - Requires Plus feature `period_preparation` and `state.canAuthorTransact`. Wraps `state.createPeriodPreparationPreview` and `state.applyPeriodPreparation`.

---

## 3. Safety Guarantees Enforced by `BusinessOperationDispatcher`

1. **Mandatory Preview-Before-Commit (`preview` -> `execute`):**
   - Every mutating operation must first call `preview*`, which validates permissions, Plus entitlements, and domain invariants without mutating state, and issues a single-use `confirmationToken` bound to `operationId`.
   - Calling `execute*` with `userConfirmed: false` or a mismatched `confirmationToken` fails closed with `BusinessOperationStatus.confirmationRequired` (`CONFIRMATION_REQUIRED`).
2. **Idempotent Execution Replay:**
   - `BusinessOperationDispatcher` caches completed mutating `operationId` results (`_completedResults`). Re-submitting the same `operationId` returns the original result with `replayedFromIdempotencyCache: true` without duplicating transactions, commitments, payments, or period plans.
3. **Role & Entitlement Enforcement:**
   - Read-only family roles (`Role.viewer` / `Role.child` where `canAuthorTransact == false`) are rejected with `BusinessOperationStatus.permissionDenied` (`PERMISSION_DENIED`).
   - Unentitled families calling Plus operations are rejected with `BusinessOperationStatus.entitlementRequired` (`PLUS_ENTITLEMENT_REQUIRED`).
4. **Structured Audit Log (`BusinessOperationAudit`):**
   - Every preview, query, rejection, and execution records an immutable `BusinessOperationAudit` entry containing `contractVersion`, `operationId`, `kind`, `actorMemberId`, `spaceId`, `timestamp`, `previewGenerated`, `userConfirmed`, `status`, and `summary`.

