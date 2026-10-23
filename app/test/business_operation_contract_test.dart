import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/billing/entitlement.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/operations/business_operation_contract.dart';
import 'package:mhuri_money/core/planning/commitments.dart';
import 'package:mhuri_money/core/state/app_state.dart';

void main() {
  test('BusinessOperationDispatcher enforces preview-first, permissions, Plus gating, and idempotency',
      () {
    final now = DateTime(2026, 10, 22, 10);
    final state = AppState(clock: () => now);
    state.setRealUser(
      const Member(id: 'u1', name: 'Owner', emoji: 'person', role: Role.owner),
    );
    final dispatcher = BusinessOperationDispatcher(state);

    // 1. Executing without preview fails closed
    final unpreviewed = dispatcher.execute(
      operationId: 'op-missing',
      userConfirmed: true,
    );
    expect(unpreviewed.succeeded, isFalse);
    expect(unpreviewed.errorCode, 'PREVIEW_REQUIRED');

    // 2. Plus operation fails closed when family is on Free tier
    final blockedPlusPreview = dispatcher.preview(
      operationId: 'op-commitment-free',
      kind: BusinessOperationKind.createFinancialCommitment,
      params: {
        'name': 'School Fees',
        'amount': const Money(30000, Currency.usd),
        'firstDueDate': DateTime(2026, 11, 1),
      },
    );
    expect(blockedPlusPreview.canProceed, isFalse);
    expect(blockedPlusPreview.denialReason, 'PLUS_ENTITLEMENT_REQUIRED');

    // 3. Free expense mutation requires userConfirmed = true and is idempotent
    final txPreview = dispatcher.preview(
      operationId: 'op-expense-1',
      kind: BusinessOperationKind.recordExpenseTransaction,
      params: {
        'amount': const Money(2500, Currency.usd),
        'note': 'Bread and milk',
      },
    );
    expect(txPreview.canProceed, isTrue);

    final unconfirmed = dispatcher.execute(
      operationId: 'op-expense-1',
      userConfirmed: false,
    );
    expect(unconfirmed.succeeded, isFalse);
    expect(unconfirmed.errorCode, 'USER_CONFIRMATION_REQUIRED');
    expect(state.txs, isEmpty);

    final confirmed = dispatcher.execute(
      operationId: 'op-expense-1',
      userConfirmed: true,
    );
    expect(confirmed.succeeded, isTrue);
    expect(confirmed.idempotentReplay, isFalse);
    expect(state.txs, hasLength(1));

    // Replaying same operationId returns cached result and does not duplicate tx
    final replay = dispatcher.execute(
      operationId: 'op-expense-1',
      userConfirmed: true,
    );
    expect(replay.succeeded, isTrue);
    expect(replay.idempotentReplay, isTrue);
    expect(state.txs, hasLength(1));

    // 4. Activate Plus and create commitment via contract
    state.familyEntitlement = const FamilyEntitlement(
      familyId: 'fam-1',
      status: EntitlementStatus.active,
      features: kPlusV2Features,
    );
    final commitPreview = dispatcher.preview(
      operationId: 'op-commitment-plus',
      kind: BusinessOperationKind.createFinancialCommitment,
      params: {
        'name': 'School Fees',
        'amount': const Money(30000, Currency.usd),
        'firstDueDate': DateTime(2026, 11, 1),
        'recurrence': CommitmentRecurrence.monthly,
      },
    );
    expect(commitPreview.canProceed, isTrue);
    final commitResult = dispatcher.execute(
      operationId: 'op-commitment-plus',
      userConfirmed: true,
    );
    expect(commitResult.succeeded, isTrue);
    expect(state.financialCommitments, hasLength(1));
    // Creating a commitment never creates an expense transaction
    expect(state.txs, hasLength(1));

    // 5. Viewer role is denied write operations
    state.setRealUser(
      const Member(id: 'u2', name: 'Viewer', emoji: 'person', role: Role.viewer),
    );
    final viewerPreview = dispatcher.preview(
      operationId: 'op-viewer-tx',
      kind: BusinessOperationKind.recordExpenseTransaction,
      params: {
        'amount': const Money(1000, Currency.usd),
        'note': 'Blocked',
      },
    );
    expect(viewerPreview.canProceed, isFalse);
    expect(viewerPreview.denialReason, 'PERMISSION_DENIED');

    state.dispose();
  });
}

