import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../money/money.dart';
import '../planning/commitments.dart';
import '../planning/financial_health.dart';
import '../planning/financial_planner.dart';
import '../planning/savings_debt_planner.dart';
import '../state/app_state.dart';
import '../utils/ids.dart';

/// Current schema version for typed Mhuri business operation contracts.
const int kBusinessOperationContractVersion = 1;

enum BusinessOperationKind {
  queryAvailableBalance,
  queryUpcomingCommitments,
  queryPaydayForecast,
  queryFinancialHealth,
  querySavingsProjection,
  recordExpenseTransaction,
  createFinancialCommitment,
  associateCommitmentPayment,
  prepareNextPeriod,
}

@immutable
class BusinessOperationAudit {
  const BusinessOperationAudit({
    required this.operationId,
    required this.kind,
    required this.schemaVersion,
    required this.actorMemberId,
    required this.actorRole,
    required this.familyId,
    required this.timestamp,
    required this.requiresPlus,
    required this.wasPreviewed,
  });

  final String operationId;
  final BusinessOperationKind kind;
  final int schemaVersion;
  final String actorMemberId;
  final Role actorRole;
  final String familyId;
  final DateTime timestamp;
  final bool requiresPlus;
  final bool wasPreviewed;

  Map<String, Object?> toJson() => {
        'operation_id': operationId,
        'kind': kind.name,
        'schema_version': schemaVersion,
        'actor_member_id': actorMemberId,
        'actor_role': actorRole.name,
        'family_id': familyId,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'requires_plus': requiresPlus,
        'was_previewed': wasPreviewed,
      };
}

@immutable
class BusinessOperationPreview {
  const BusinessOperationPreview({
    required this.operationId,
    required this.kind,
    required this.schemaVersion,
    required this.summary,
    required this.requiresConfirmation,
    required this.requiresPlus,
    required this.authorized,
    required this.entitled,
    this.denialReason,
    this.financialImpact,
    this.affectedEntities = const [],
    this.warnings = const [],
    this.payload = const {},
  });

  final String operationId;
  final BusinessOperationKind kind;
  final int schemaVersion;
  final String summary;
  final bool requiresConfirmation;
  final bool requiresPlus;
  final bool authorized;
  final bool entitled;
  final String? denialReason;
  final Money? financialImpact;
  final List<String> affectedEntities;
  final List<String> warnings;
  final Map<String, Object?> payload;

  bool get canProceed => authorized && entitled && denialReason == null;
}

@immutable
class BusinessOperationResult {
  const BusinessOperationResult({
    required this.operationId,
    required this.kind,
    required this.succeeded,
    required this.idempotentReplay,
    required this.audit,
    this.errorCode,
    this.errorMessage,
    this.createdEntityIds = const [],
    this.data = const {},
  });

  final String operationId;
  final BusinessOperationKind kind;
  final bool succeeded;
  final bool idempotentReplay;
  final BusinessOperationAudit audit;
  final String? errorCode;
  final String? errorMessage;
  final List<String> createdEntityIds;
  final Map<String, Object?> data;
}

/// Deterministic, permission-checked, preview-first gateway for UI and future
/// Mhuri Assistant invocations. Mutating operations cannot execute without a
/// validated preview and idempotency key.
class BusinessOperationDispatcher {
  BusinessOperationDispatcher(this.state);

  final AppState state;
  final Map<String, BusinessOperationPreview> _previews = {};
  final Map<String, BusinessOperationResult> _executed = {};

  String get _familyId => state.sync?.spaceId ?? state.space.name;

  bool _requiresPlus(BusinessOperationKind kind) => switch (kind) {
        BusinessOperationKind.queryAvailableBalance ||
        BusinessOperationKind.recordExpenseTransaction =>
          false,
        BusinessOperationKind.queryUpcomingCommitments ||
        BusinessOperationKind.createFinancialCommitment ||
        BusinessOperationKind.associateCommitmentPayment =>
          true,
        BusinessOperationKind.queryPaydayForecast => true,
        BusinessOperationKind.queryFinancialHealth => true,
        BusinessOperationKind.querySavingsProjection => true,
        BusinessOperationKind.prepareNextPeriod => true,
      };

  bool _hasRequiredEntitlement(BusinessOperationKind kind) => switch (kind) {
        BusinessOperationKind.queryAvailableBalance ||
        BusinessOperationKind.recordExpenseTransaction =>
          true,
        BusinessOperationKind.queryUpcomingCommitments =>
          state.hasPlusFeature('smart_commitments'),
        BusinessOperationKind.createFinancialCommitment ||
        BusinessOperationKind.associateCommitmentPayment =>
          state.canWritePlusFeature('smart_commitments'),
        BusinessOperationKind.queryPaydayForecast =>
          state.hasPlusFeature('cash_flow_forecast'),
        BusinessOperationKind.queryFinancialHealth =>
          state.hasPlusFeature('financial_health'),
        BusinessOperationKind.querySavingsProjection =>
          state.hasPlusFeature('savings_projections') ||
              state.hasPlusFeature('debt_planning'),
        BusinessOperationKind.prepareNextPeriod =>
          state.canWritePlusFeature('period_preparation'),
      };

  bool _hasRequiredPermission(BusinessOperationKind kind) => switch (kind) {
        BusinessOperationKind.queryAvailableBalance ||
        BusinessOperationKind.queryUpcomingCommitments ||
        BusinessOperationKind.queryPaydayForecast ||
        BusinessOperationKind.queryFinancialHealth ||
        BusinessOperationKind.querySavingsProjection =>
          state.canAuthorViewBudget || state.canAuthorViewWallet,
        BusinessOperationKind.recordExpenseTransaction ||
        BusinessOperationKind.createFinancialCommitment ||
        BusinessOperationKind.associateCommitmentPayment =>
          state.canAuthorTransact,
        BusinessOperationKind.prepareNextPeriod => state.canEditBudgets,
      };

  /// Generates a non-mutating preview of a requested operation and caches it by
  /// [operationId] so the user can review and confirm before execution.
  BusinessOperationPreview preview({
    required String operationId,
    required BusinessOperationKind kind,
    int schemaVersion = kBusinessOperationContractVersion,
    Map<String, Object?> params = const {},
  }) {
    if (operationId.trim().isEmpty) {
      throw ArgumentError('operationId must not be empty');
    }
    if (schemaVersion != kBusinessOperationContractVersion) {
      return BusinessOperationPreview(
        operationId: operationId,
        kind: kind,
        schemaVersion: schemaVersion,
        summary: 'Unsupported contract schema version $schemaVersion.',
        requiresConfirmation: true,
        requiresPlus: _requiresPlus(kind),
        authorized: false,
        entitled: false,
        denialReason: 'UNSUPPORTED_SCHEMA_VERSION',
      );
    }
    final existing = _previews[operationId];
    if (existing != null) return existing;

    final authorized = _hasRequiredPermission(kind);
    final entitled = _hasRequiredEntitlement(kind);
    final requiresPlus = _requiresPlus(kind);

    if (!authorized) {
      final denied = BusinessOperationPreview(
        operationId: operationId,
        kind: kind,
        schemaVersion: schemaVersion,
        summary: 'Permission denied for role ${state.authRole.name}.',
        requiresConfirmation: true,
        requiresPlus: requiresPlus,
        authorized: false,
        entitled: entitled,
        denialReason: 'PERMISSION_DENIED',
      );
      _previews[operationId] = denied;
      return denied;
    }

    if (!entitled) {
      final denied = BusinessOperationPreview(
        operationId: operationId,
        kind: kind,
        schemaVersion: schemaVersion,
        summary: 'Active Mhuri Plus entitlement required for ${kind.name}.',
        requiresConfirmation: true,
        requiresPlus: requiresPlus,
        authorized: true,
        entitled: false,
        denialReason: 'PLUS_ENTITLEMENT_REQUIRED',
      );
      _previews[operationId] = denied;
      return denied;
    }

    final built = switch (kind) {
      BusinessOperationKind.recordExpenseTransaction =>
        _previewExpense(operationId, schemaVersion, params),
      BusinessOperationKind.createFinancialCommitment =>
        _previewCommitment(operationId, schemaVersion, params),
      BusinessOperationKind.associateCommitmentPayment =>
        _previewCommitmentPayment(operationId, schemaVersion, params),
      BusinessOperationKind.prepareNextPeriod =>
        _previewPeriodPreparation(operationId, schemaVersion, params),
      _ => BusinessOperationPreview(
          operationId: operationId,
          kind: kind,
          schemaVersion: schemaVersion,
          summary: 'Read-only query ${kind.name}',
          requiresConfirmation: false,
          requiresPlus: requiresPlus,
          authorized: true,
          entitled: true,
          payload: params,
        ),
    };
    _previews[operationId] = built;
    return built;
  }

  /// Executes a read-only query or a previously previewed mutation.
  /// Duplicate confirmations with the same [operationId] return the cached
  /// result without re-executing or duplicating records.
  BusinessOperationResult execute({
    required String operationId,
    bool userConfirmed = false,
  }) {
    final replay = _executed[operationId];
    if (replay != null) {
      return BusinessOperationResult(
        operationId: replay.operationId,
        kind: replay.kind,
        succeeded: replay.succeeded,
        idempotentReplay: true,
        audit: replay.audit,
        errorCode: replay.errorCode,
        errorMessage: replay.errorMessage,
        createdEntityIds: replay.createdEntityIds,
        data: replay.data,
      );
    }

    final previewed = _previews[operationId];
    if (previewed == null) {
      final audit = BusinessOperationAudit(
        operationId: operationId,
        kind: BusinessOperationKind.queryAvailableBalance,
        schemaVersion: kBusinessOperationContractVersion,
        actorMemberId: state.realUser.id,
        actorRole: state.authRole,
        familyId: _familyId,
        timestamp: state.now,
        requiresPlus: false,
        wasPreviewed: false,
      );
      return BusinessOperationResult(
        operationId: operationId,
        kind: BusinessOperationKind.queryAvailableBalance,
        succeeded: false,
        idempotentReplay: false,
        audit: audit,
        errorCode: 'PREVIEW_REQUIRED',
        errorMessage: 'Operation must be previewed before execution.',
      );
    }

    final audit = BusinessOperationAudit(
      operationId: operationId,
      kind: previewed.kind,
      schemaVersion: previewed.schemaVersion,
      actorMemberId: state.realUser.id,
      actorRole: state.authRole,
      familyId: _familyId,
      timestamp: state.now,
      requiresPlus: previewed.requiresPlus,
      wasPreviewed: true,
    );

    if (!previewed.canProceed) {
      return BusinessOperationResult(
        operationId: operationId,
        kind: previewed.kind,
        succeeded: false,
        idempotentReplay: false,
        audit: audit,
        errorCode: previewed.denialReason ?? 'INVALID_PREVIEW',
        errorMessage: previewed.summary,
      );
    }

    if (previewed.requiresConfirmation && !userConfirmed) {
      return BusinessOperationResult(
        operationId: operationId,
        kind: previewed.kind,
        succeeded: false,
        idempotentReplay: false,
        audit: audit,
        errorCode: 'USER_CONFIRMATION_REQUIRED',
        errorMessage: 'Mutating operations require explicit user confirmation.',
      );
    }

    final result = switch (previewed.kind) {
      BusinessOperationKind.queryAvailableBalance =>
        _execQueryAvailableBalance(previewed, audit),
      BusinessOperationKind.queryUpcomingCommitments =>
        _execQueryUpcomingCommitments(previewed, audit),
      BusinessOperationKind.queryPaydayForecast =>
        _execQueryPaydayForecast(previewed, audit),
      BusinessOperationKind.queryFinancialHealth =>
        _execQueryFinancialHealth(previewed, audit),
      BusinessOperationKind.querySavingsProjection =>
        _execQuerySavingsProjection(previewed, audit),
      BusinessOperationKind.recordExpenseTransaction =>
        _execRecordExpense(previewed, audit),
      BusinessOperationKind.createFinancialCommitment =>
        _execCreateCommitment(previewed, audit),
      BusinessOperationKind.associateCommitmentPayment =>
        _execAssociateCommitmentPayment(previewed, audit),
      BusinessOperationKind.prepareNextPeriod =>
        _execPrepareNextPeriod(previewed, audit),
    };

    if (result.succeeded) {
      _executed[operationId] = result;
    }
    return result;
  }

  BusinessOperationPreview _previewExpense(
    String operationId,
    int schemaVersion,
    Map<String, Object?> params,
  ) {
    final amount = params['amount'];
    final note = params['note']?.toString().trim() ?? '';
    if (amount is! Money || amount.minor <= 0 || note.isEmpty) {
      return BusinessOperationPreview(
        operationId: operationId,
        kind: BusinessOperationKind.recordExpenseTransaction,
        schemaVersion: schemaVersion,
        summary: 'Expense requires a positive Money amount and non-empty note.',
        requiresConfirmation: true,
        requiresPlus: false,
        authorized: true,
        entitled: true,
        denialReason: 'INVALID_PARAMETERS',
      );
    }
    return BusinessOperationPreview(
      operationId: operationId,
      kind: BusinessOperationKind.recordExpenseTransaction,
      schemaVersion: schemaVersion,
      summary: 'Record expense "$note" for ${amount.text}.',
      requiresConfirmation: true,
      requiresPlus: false,
      authorized: true,
      entitled: true,
      financialImpact: amount,
      affectedEntities: const ['transaction'],
      payload: params,
    );
  }

  BusinessOperationPreview _previewCommitment(
    String operationId,
    int schemaVersion,
    Map<String, Object?> params,
  ) {
    final name = params['name']?.toString().trim() ?? '';
    final amount = params['amount'];
    final firstDueDate = params['firstDueDate'];
    final recurrence = params['recurrence'] as CommitmentRecurrence? ??
        CommitmentRecurrence.monthly;
    if (name.isEmpty ||
        amount is! Money ||
        amount.minor <= 0 ||
        firstDueDate is! DateTime) {
      return BusinessOperationPreview(
        operationId: operationId,
        kind: BusinessOperationKind.createFinancialCommitment,
        schemaVersion: schemaVersion,
        summary:
            'Commitment requires a name, positive Money amount, and due date.',
        requiresConfirmation: true,
        requiresPlus: true,
        authorized: true,
        entitled: true,
        denialReason: 'INVALID_PARAMETERS',
      );
    }
    return BusinessOperationPreview(
      operationId: operationId,
      kind: BusinessOperationKind.createFinancialCommitment,
      schemaVersion: schemaVersion,
      summary:
          'Schedule ${recurrence.name} commitment "$name" for ${amount.text} (does not record an expense).',
      requiresConfirmation: true,
      requiresPlus: true,
      authorized: true,
      entitled: true,
      financialImpact: amount,
      affectedEntities: const ['financial_commitment', 'commitment_occurrence'],
      warnings: const [
        'Creating a commitment schedules future obligations only; no expense is posted until paid.',
      ],
      payload: params,
    );
  }

  BusinessOperationPreview _previewCommitmentPayment(
    String operationId,
    int schemaVersion,
    Map<String, Object?> params,
  ) {
    final occurrenceId = params['occurrenceId']?.toString() ?? '';
    final transactionId = params['transactionId']?.toString() ?? '';
    final amount = params['amount'];
    if (occurrenceId.isEmpty ||
        transactionId.isEmpty ||
        amount is! Money ||
        amount.minor <= 0) {
      return BusinessOperationPreview(
        operationId: operationId,
        kind: BusinessOperationKind.associateCommitmentPayment,
        schemaVersion: schemaVersion,
        summary:
            'Commitment payment requires occurrenceId, transactionId, and positive Money.',
        requiresConfirmation: true,
        requiresPlus: true,
        authorized: true,
        entitled: true,
        denialReason: 'INVALID_PARAMETERS',
      );
    }
    return BusinessOperationPreview(
      operationId: operationId,
      kind: BusinessOperationKind.associateCommitmentPayment,
      schemaVersion: schemaVersion,
      summary:
          'Link ${amount.text} from expense $transactionId to commitment occurrence $occurrenceId.',
      requiresConfirmation: true,
      requiresPlus: true,
      authorized: true,
      entitled: true,
      financialImpact: amount,
      affectedEntities: const ['commitment_payment', 'commitment_occurrence'],
      payload: params,
    );
  }

  BusinessOperationPreview _previewPeriodPreparation(
    String operationId,
    int schemaVersion,
    Map<String, Object?> params,
  ) {
    final targetCycle = params['targetCycle'] as DateTime?;
    final prep = state.previewAdvancedPeriodPreparation(
      operationId: operationId,
      targetCycle: targetCycle,
    );
    if (prep == null) {
      return BusinessOperationPreview(
        operationId: operationId,
        kind: BusinessOperationKind.prepareNextPeriod,
        schemaVersion: schemaVersion,
        summary: 'No previous budget cycle plan available to prepare from.',
        requiresConfirmation: true,
        requiresPlus: true,
        authorized: true,
        entitled: true,
        denialReason: 'SOURCE_CYCLE_MISSING',
      );
    }
    return BusinessOperationPreview(
      operationId: operationId,
      kind: BusinessOperationKind.prepareNextPeriod,
      schemaVersion: schemaVersion,
      summary:
          'Prepare ${prep.allocations.length} budget allocations, ${prep.commitmentIds.length} commitments, and ${prep.shoppingItems.length} reusable shopping items.',
      requiresConfirmation: true,
      requiresPlus: true,
      authorized: true,
      entitled: true,
      affectedEntities: const [
        'envelope',
        'budget_cycle_plan',
        'commitment_occurrence',
        'list_item',
      ],
      warnings: const [
        'Historical completed expenses and debt repayments are never copied.',
      ],
      payload: params,
    );
  }

  BusinessOperationResult _execQueryAvailableBalance(
    BusinessOperationPreview previewed,
    BusinessOperationAudit audit,
  ) {
    final currency =
        previewed.payload['currency'] as Currency? ?? state.primaryCurrency;
    final available = state.availableToSpend(currency);
    final pool = state.poolCombined(currency);
    final saved = state.totalSaved(currency);
    return BusinessOperationResult(
      operationId: previewed.operationId,
      kind: previewed.kind,
      succeeded: true,
      idempotentReplay: false,
      audit: audit,
      data: {
        'currency': currency.code,
        'available_to_spend': available,
        'pool_combined': pool,
        'total_saved': saved,
      },
    );
  }

  BusinessOperationResult _execQueryUpcomingCommitments(
    BusinessOperationPreview previewed,
    BusinessOperationAudit audit,
  ) {
    final upcoming = state.upcomingCommitments();
    final overdue = state.overdueCommitments();
    return BusinessOperationResult(
      operationId: previewed.operationId,
      kind: previewed.kind,
      succeeded: true,
      idempotentReplay: false,
      audit: audit,
      data: {
        'upcoming_count': upcoming.length,
        'overdue_count': overdue.length,
        'upcoming': upcoming,
        'overdue': overdue,
      },
    );
  }

  BusinessOperationResult _execQueryPaydayForecast(
    BusinessOperationPreview previewed,
    BusinessOperationAudit audit,
  ) {
    final opening = previewed.payload['openingBalance'] as Money?;
    final confirmed = previewed.payload['openingBalanceConfirmed'] == true;
    final days = previewed.payload['days'] as int? ?? 30;
    if (opening == null || !confirmed) {
      return BusinessOperationResult(
        operationId: previewed.operationId,
        kind: previewed.kind,
        succeeded: false,
        idempotentReplay: false,
        audit: audit,
        errorCode: 'UNCONFIRMED_OPENING_BALANCE',
        errorMessage:
            'Opening balance must be provided and explicitly confirmed.',
      );
    }
    final start = state.now;
    final end = start.add(Duration(days: days));
    final entries = const CommitmentSchedule()
        .toPlanningEntries(
          commitments: state.financialCommitments,
          occurrences: state.commitmentOccurrences,
          payments: state.commitmentPayments,
          periodStart: start,
          periodEnd: end,
        )
        .where((e) => e.amount.currency == opening.currency)
        .toList(growable: false);
    final forecast = const FinancialPlanner().forecast(
      periodStart: start,
      periodEnd: end,
      openingBalance: opening,
      openingBalanceConfirmed: true,
      entries: entries,
    );
    return BusinessOperationResult(
      operationId: previewed.operationId,
      kind: previewed.kind,
      succeeded: true,
      idempotentReplay: false,
      audit: audit,
      data: {'forecast': forecast},
    );
  }

  BusinessOperationResult _execQueryFinancialHealth(
    BusinessOperationPreview previewed,
    BusinessOperationAudit audit,
  ) {
    final currency =
        previewed.payload['currency'] as Currency? ?? state.primaryCurrency;
    final review = const FinancialHealthEngine().review(
      currency: currency,
      periodStart: state.cycleStart,
      periodEnd: state.nextCycleStart,
      transactions: state.txs,
      envelopes: state.envelopes,
      commitments: state.financialCommitments,
      occurrences: state.commitmentOccurrences,
      commitmentPayments: state.commitmentPayments,
      goals: state.goals,
      goalTransactions: state.goalTxs,
      debts: state.familyDebts,
      debtRepayments: state.debtRepayments,
      txAllocations: state.txAllocations,
    );
    return BusinessOperationResult(
      operationId: previewed.operationId,
      kind: previewed.kind,
      succeeded: true,
      idempotentReplay: false,
      audit: audit,
      data: {'review': review},
    );
  }

  BusinessOperationResult _execQuerySavingsProjection(
    BusinessOperationPreview previewed,
    BusinessOperationAudit audit,
  ) {
    final goal = previewed.payload['goal'] as Goal?;
    final contribution = previewed.payload['contribution'] as Money?;
    if (goal == null || contribution == null || contribution.minor <= 0) {
      return BusinessOperationResult(
        operationId: previewed.operationId,
        kind: previewed.kind,
        succeeded: false,
        idempotentReplay: false,
        audit: audit,
        errorCode: 'INVALID_PARAMETERS',
        errorMessage: 'Goal and positive contribution Money are required.',
      );
    }
    final projection = const SavingsDebtPlanner().projectSavings(
      SavingsPlanInput(
        currentAmount: state.savedOn(goal),
        targetAmount: goal.target,
        contributionAmount: contribution,
        frequency: ContributionFrequency.monthly,
        startDate: state.now,
        targetDate: goal.deadline,
      ),
    );
    return BusinessOperationResult(
      operationId: previewed.operationId,
      kind: previewed.kind,
      succeeded: true,
      idempotentReplay: false,
      audit: audit,
      data: {'projection': projection},
    );
  }

  BusinessOperationResult _execRecordExpense(
    BusinessOperationPreview previewed,
    BusinessOperationAudit audit,
  ) {
    final amount = previewed.payload['amount'] as Money;
    final note = previewed.payload['note'].toString().trim();
    final envelopeId = previewed.payload['envelopeId'] as String?;
    final method = previewed.payload['method'] as Method? ?? Method.cash;
    final txId = uuidFromSeed('op-tx:${previewed.operationId}');
    final ok = state.addTx(
      id: txId,
      type: TxType.expense,
      amount: amount,
      memberId: state.realUser.id,
      method: method,
      note: note,
      envelopeId: envelopeId,
    );
    return BusinessOperationResult(
      operationId: previewed.operationId,
      kind: previewed.kind,
      succeeded: ok,
      idempotentReplay: false,
      audit: audit,
      errorCode: ok ? null : 'TX_REJECTED',
      errorMessage: ok
          ? null
          : 'Transaction was rejected by validation or overspend policy.',
      createdEntityIds: ok ? [txId] : const [],
    );
  }

  BusinessOperationResult _execCreateCommitment(
    BusinessOperationPreview previewed,
    BusinessOperationAudit audit,
  ) {
    final commitmentId = uuidFromSeed('op-commitment:${previewed.operationId}');
    final name = previewed.payload['name'].toString().trim();
    final amount = previewed.payload['amount'] as Money;
    final firstDueDate = previewed.payload['firstDueDate'] as DateTime;
    final recurrence =
        previewed.payload['recurrence'] as CommitmentRecurrence? ??
            CommitmentRecurrence.monthly;
    final commitment = FinancialCommitment(
      id: commitmentId,
      name: name,
      amount: amount,
      firstDueDate: firstDueDate,
      recurrence: recurrence,
      createdById: state.realUser.id,
    );
    final ok = state.addFinancialCommitment(commitment);
    return BusinessOperationResult(
      operationId: previewed.operationId,
      kind: previewed.kind,
      succeeded: ok,
      idempotentReplay: false,
      audit: audit,
      errorCode: ok ? null : 'COMMITMENT_REJECTED',
      createdEntityIds: ok ? [commitmentId] : const [],
    );
  }

  BusinessOperationResult _execAssociateCommitmentPayment(
    BusinessOperationPreview previewed,
    BusinessOperationAudit audit,
  ) {
    final paymentId = uuidFromSeed('op-cpay:${previewed.operationId}');
    final occurrenceId = previewed.payload['occurrenceId'].toString();
    final transactionId = previewed.payload['transactionId'].toString();
    final amount = previewed.payload['amount'] as Money;
    final ok = state.associateCommitmentPayment(
      id: paymentId,
      occurrenceId: occurrenceId,
      transactionId: transactionId,
      amount: amount,
    );
    return BusinessOperationResult(
      operationId: previewed.operationId,
      kind: previewed.kind,
      succeeded: ok,
      idempotentReplay: false,
      audit: audit,
      errorCode: ok ? null : 'PAYMENT_LINK_REJECTED',
      createdEntityIds: ok ? [paymentId] : const [],
    );
  }

  BusinessOperationResult _execPrepareNextPeriod(
    BusinessOperationPreview previewed,
    BusinessOperationAudit audit,
  ) {
    final ok = state.applyAdvancedPeriodPreparation(previewed.operationId);
    return BusinessOperationResult(
      operationId: previewed.operationId,
      kind: previewed.kind,
      succeeded: ok,
      idempotentReplay: false,
      audit: audit,
      errorCode: ok ? null : 'PREPARATION_FAILED',
      createdEntityIds: ok ? [previewed.operationId] : const [],
    );
  }
}
