import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/planning/financial_planner.dart';

void main() {
  const planner = FinancialPlanner();
  final start = DateTime(2026, 10, 22);
  final end = DateTime(2026, 11, 22);

  PlanningEntry entry(
    String id,
    int minor,
    DateTime date, {
    Currency currency = Currency.usd,
    PlanningValueKind kind = PlanningValueKind.commitment,
    PlanningDirection direction = PlanningDirection.outflow,
  }) =>
      PlanningEntry(
        id: id,
        date: date,
        amount: Money(minor, currency),
        kind: kind,
        direction: direction,
        evidence: PlanningEvidence(
          sourceType: kind.name,
          sourceId: id,
          label: id,
          isEstimate: kind == PlanningValueKind.estimate,
        ),
      );

  test('example forecast explains dated income, bills, essentials and savings',
      () {
    final result = planner.forecast(
      periodStart: start,
      periodEnd: end,
      openingBalance: const Money(50000, Currency.usd),
      openingBalanceConfirmed: true,
      entries: [
        entry('income', 30000, start.add(const Duration(days: 2)),
            kind: PlanningValueKind.expectedIncome,
            direction: PlanningDirection.inflow),
        entry('bills', 25000, start.add(const Duration(days: 4))),
        entry('groceries', 12000, start.add(const Duration(days: 5)),
            kind: PlanningValueKind.plannedEssential),
        entry('savings', 5000, start.add(const Duration(days: 6)),
            kind: PlanningValueKind.savingsAllocation),
      ],
    );

    expect(result.closingBalance.minor, 38000);
    expect(result.closingBalance.currency, Currency.usd);
    expect(result.includedEvidence.map((e) => e.sourceId),
        ['income', 'bills', 'groceries', 'savings']);
    expect(result.hasShortfall, isFalse);
  });

  test('budget allocations are not implicit planner inputs', () {
    final result = planner.forecast(
      periodStart: start,
      periodEnd: end,
      openingBalance: const Money(50000, Currency.usd),
      openingBalanceConfirmed: true,
      entries: const [],
    );
    expect(result.closingBalance.minor, 50000);
  });

  test('requires explicit opening balance confirmation', () {
    expect(
      () => planner.forecast(
        periodStart: start,
        periodEnd: end,
        openingBalance: const Money(0, Currency.usd),
        openingBalanceConfirmed: false,
        entries: const [],
      ),
      throwsA(isA<FinancialPlanningException>()
          .having((e) => e.code, 'code', 'OPENING_BALANCE_UNCONFIRMED')),
    );
  });

  test('detects first transition below zero and tightest balance', () {
    final result = planner.forecast(
      periodStart: start,
      periodEnd: end,
      openingBalance: const Money(10000, Currency.usd),
      openingBalanceConfirmed: true,
      entries: [
        entry('rent', 12000, start.add(const Duration(days: 1))),
        entry('food', 3000, start.add(const Duration(days: 2))),
      ],
    );
    expect(result.shortfalls, hasLength(1));
    expect(result.shortfalls.single.triggerEntryId, 'rent');
    expect(result.lowestBalance.minor, -5000);
  });

  test('late income scenario changes sequence without mutating source', () {
    final income = entry('income', 10000, start.add(const Duration(days: 1)),
        kind: PlanningValueKind.expectedIncome,
        direction: PlanningDirection.inflow);
    final bill = entry('bill', 8000, start.add(const Duration(days: 2)));
    final result = planner.forecast(
      periodStart: start,
      periodEnd: end,
      openingBalance: const Money(2000, Currency.usd),
      openingBalanceConfirmed: true,
      entries: [income, bill],
      scenario: const [
        ScenarioChange(
            id: 'late', targetEntryId: 'income', dateShift: Duration(days: 5)),
      ],
    );
    expect(result.hasShortfall, isTrue);
    expect(income.date, start.add(const Duration(days: 1)));
  });

  test('planned purchase scenario remains isolated', () {
    final entries = [entry('bill', 10000, start.add(const Duration(days: 2)))];
    final result = planner.forecast(
      periodStart: start,
      periodEnd: end,
      openingBalance: const Money(30000, Currency.usd),
      openingBalanceConfirmed: true,
      entries: entries,
      scenario: [
        ScenarioChange(
          id: 'purchase-change',
          additionalEntry: entry(
            'scenario-purchase',
            15000,
            start.add(const Duration(days: 3)),
            kind: PlanningValueKind.scenarioAdjustment,
          ),
        ),
      ],
    );
    expect(result.closingBalance.minor, 5000);
    expect(entries, hasLength(1));
  });

  test('replacement adjustment supports higher groceries', () {
    final result = planner.forecast(
      periodStart: start,
      periodEnd: end,
      openingBalance: const Money(20000, Currency.usd),
      openingBalanceConfirmed: true,
      entries: [entry('food', 5000, start)],
      scenario: const [
        ScenarioChange(
          id: 'food-up',
          targetEntryId: 'food',
          replacementAmount: Money(8000, Currency.usd),
        ),
      ],
    );
    expect(result.closingBalance.minor, 12000);
  });

  test('entries outside the half-open period are excluded', () {
    final result = planner.forecast(
      periodStart: start,
      periodEnd: end,
      openingBalance: const Money(10000, Currency.usd),
      openingBalanceConfirmed: true,
      entries: [entry('at-end', 5000, end)],
    );
    expect(result.points, isEmpty);
  });

  test('same-day ordering is deterministic by stable ID', () {
    final result = planner.forecast(
      periodStart: start,
      periodEnd: end,
      openingBalance: const Money(0, Currency.usd),
      openingBalanceConfirmed: true,
      entries: [
        entry('b-out', 500, start),
        entry('a-in', 1000, start,
            direction: PlanningDirection.inflow,
            kind: PlanningValueKind.expectedIncome),
      ],
    );
    expect(result.points.map((p) => p.entry.id), ['a-in', 'b-out']);
  });

  test('silently combining currencies is rejected', () {
    expect(
      () => planner.forecast(
        periodStart: start,
        periodEnd: end,
        openingBalance: const Money(10000, Currency.usd),
        openingBalanceConfirmed: true,
        entries: [entry('zar-bill', 100, start, currency: Currency.zar)],
      ),
      throwsA(isA<FinancialPlanningException>()
          .having((e) => e.code, 'code', 'CURRENCY_MISMATCH')),
    );
  });

  test('multi-currency convenience returns separate forecasts', () {
    final results = planner.forecastByCurrency(
      periodStart: start,
      periodEnd: end,
      openingBalances: const {
        Currency.usd: Money(10000, Currency.usd),
        Currency.zar: Money(20000, Currency.zar),
      },
      confirmedCurrencies: const {Currency.usd, Currency.zar},
      entries: [
        entry('usd', 1000, start),
        entry('zar', 2000, start, currency: Currency.zar),
      ],
    );
    expect(results[Currency.usd]!.closingBalance.minor, 9000);
    expect(results[Currency.zar]!.closingBalance.minor, 18000);
  });

  test('duplicate source IDs are rejected to prevent double counting', () {
    expect(
      () => planner.forecast(
        periodStart: start,
        periodEnd: end,
        openingBalance: const Money(10000, Currency.usd),
        openingBalanceConfirmed: true,
        entries: [entry('same', 100, start), entry('same', 100, start)],
      ),
      throwsA(isA<FinancialPlanningException>()
          .having((e) => e.code, 'code', 'DUPLICATE_ENTRY')),
    );
  });

  test('invalid periods and negative magnitudes fail closed', () {
    expect(
      () => planner.forecast(
        periodStart: end,
        periodEnd: start,
        openingBalance: const Money(0, Currency.usd),
        openingBalanceConfirmed: true,
        entries: const [],
      ),
      throwsA(isA<FinancialPlanningException>()),
    );
    expect(
      () => planner.forecast(
        periodStart: start,
        periodEnd: end,
        openingBalance: const Money(0, Currency.usd),
        openingBalanceConfirmed: true,
        entries: [entry('negative', -1, start)],
      ),
      throwsA(isA<FinancialPlanningException>()
          .having((e) => e.code, 'code', 'NEGATIVE_AMOUNT')),
    );
  });
}
