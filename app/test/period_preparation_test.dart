import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/billing/entitlement.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/planning/commitments.dart';
import 'package:mhuri_money/core/planning/period_preparation.dart';
import 'package:mhuri_money/core/state/app_state.dart';

void unlock(AppState state) {
  state.familyEntitlement = FamilyEntitlement(
    familyId: 'family',
    status: EntitlementStatus.active,
    features: const {'period_preparation', 'smart_commitments'},
    expiresAt: DateTime.now().add(const Duration(days: 30)),
  );
}

void main() {
  test('preview is durable JSON and contains plans but no ledger records', () {
    final state = AppState(clock: () => DateTime(2026, 10, 22));
    unlock(state);
    state.envelopes.add(Envelope(
      id: 'food',
      name: 'Food',
      emoji: 'restaurant',
      limit: const Money(10000, Currency.usd),
    ));
    state.budgetPlans.add(BudgetCyclePlan(
      id: 'september',
      cycleStart: DateTime(2026, 9),
      incomeMode: IncomePlanMode.knownMonthly,
      expectedIncome: const Money(80000, Currency.usd),
      allocations: const {'food': 12000},
      isClosed: true,
    ));
    state.goalTxs.add(GoalTx(
      id: 'saving',
      goalId: 'emergency',
      byMemberId: 'me',
      amount: const Money(5000, Currency.usd),
      at: DateTime(2026, 9, 10),
    ));
    state.items.add(ListItem(
      id: 'old-rice',
      name: 'Rice',
      qty: 2,
      est: const Money(300, Currency.usd),
      addedById: 'me',
      state: ItemState.done,
    ));
    state.txs.add(Tx(
      id: 'historical-expense',
      memberId: 'me',
      type: TxType.expense,
      amount: const Money(300, Currency.usd),
      method: Method.cash,
      note: 'Historical expense',
      when: DateTime(2026, 9, 10),
    ));
    state.familyDebts.add(FamilyDebt(
      id: 'debt',
      name: 'Loan',
      direction: DebtDirection.iOwe,
      principal: const Money(100000, Currency.usd),
      createdById: 'me',
    ));

    final preview = state.previewAdvancedPeriodPreparation(
      operationId: 'prepare-october',
    )!;
    final decoded = PeriodPreparation.decode(preview.encode());
    expect(decoded.allocations['food']!.minor, 12000);
    expect(decoded.expectedIncome!.minor, 80000);
    expect(decoded.savings.single.amount.minor, 5000);
    expect(decoded.shoppingItems.single.name, 'Rice');
    expect(state.txs, hasLength(1));
    expect(state.familyDebts, hasLength(1));
  });

  test('apply is idempotent and never recreates expenses or savings history',
      () {
    final state = AppState(clock: () => DateTime(2026, 10, 22));
    unlock(state);
    state.envelopes.add(Envelope(
      id: 'food',
      name: 'Food',
      emoji: 'restaurant',
      limit: const Money(10000, Currency.usd),
    ));
    state.budgetPlans.add(BudgetCyclePlan(
      id: 'september',
      cycleStart: DateTime(2026, 9),
      incomeMode: IncomePlanMode.asEarned,
      allocations: const {'food': 12000},
      isClosed: true,
    ));
    state.items.add(ListItem(
      id: 'old-rice',
      name: 'Rice',
      qty: 2,
      est: const Money(300, Currency.usd),
      addedById: 'me',
      state: ItemState.done,
    ));
    state.addFinancialCommitment(FinancialCommitment(
      id: 'rent',
      name: 'Rent',
      amount: const Money(30000, Currency.usd),
      firstDueDate: DateTime(2026, 10, 25),
      recurrence: CommitmentRecurrence.monthly,
      createdById: 'me',
    ));
    state.previewAdvancedPeriodPreparation(operationId: 'prepare-october');

    expect(state.applyAdvancedPeriodPreparation('prepare-october'), isTrue);
    expect(state.applyAdvancedPeriodPreparation('prepare-october'), isTrue);
    expect(state.currentBudgetPlan, isNotNull);
    expect(state.envelope('food')!.limit.minor, 12000);
    expect(state.items.where((item) => item.name == 'Rice'), hasLength(2));
    expect(state.commitmentOccurrences, hasLength(1));
    expect(state.txs, isEmpty);
    expect(state.goalTxs, isEmpty);
    expect(state.periodPreparations.single.status, PreparationStatus.applied);
  });

  test('existing target period is not overwritten', () {
    final state = AppState(clock: () => DateTime(2026, 10, 22));
    unlock(state);
    state.envelopes.add(Envelope(
      id: 'food',
      name: 'Food',
      emoji: 'restaurant',
      limit: const Money(10000, Currency.usd),
    ));
    state.budgetPlans.add(BudgetCyclePlan(
      id: 'september',
      cycleStart: DateTime(2026, 9),
      incomeMode: IncomePlanMode.asEarned,
      allocations: const {'food': 12000},
    ));
    state.previewAdvancedPeriodPreparation(operationId: 'operation');
    state.budgetPlans.add(BudgetCyclePlan(
      id: 'existing',
      cycleStart: DateTime(2026, 10),
      incomeMode: IncomePlanMode.asEarned,
      allocations: const {'food': 9000},
    ));

    expect(state.applyAdvancedPeriodPreparation('operation'), isFalse);
    expect(state.envelope('food')!.limit.minor, 10000);
    expect(state.periodPreparations.single.status, PreparationStatus.failed);
  });
}
