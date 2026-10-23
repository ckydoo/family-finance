import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/planning/savings_debt_planner.dart';

void main() {
  const planner = SavingsDebtPlanner();

  test('savings plan projects contribution count and target-date outcome', () {
    final input = SavingsPlanInput(
      currentAmount: const Money(25000, Currency.usd),
      targetAmount: const Money(100000, Currency.usd),
      contributionAmount: const Money(10000, Currency.usd),
      frequency: ContributionFrequency.monthly,
      startDate: DateTime(2026, 1, 31),
      targetDate: DateTime(2026, 8, 31),
    );
    final projection = planner.projectSavings(input);
    expect(projection.paymentCount, 8);
    expect(projection.finalPayment.minor, 5000);
    expect(projection.completionDate, DateTime(2026, 8, 31));
    expect(projection.meetsTargetDate, isTrue);

    final alternative = planner.projectSavings(SavingsPlanInput(
      currentAmount: input.currentAmount,
      targetAmount: input.targetAmount,
      contributionAmount: const Money(15000, Currency.usd),
      frequency: input.frequency,
      startDate: input.startDate,
      targetDate: input.targetDate,
    ));
    expect(alternative.paymentCount, 5);
    expect(alternative.completionDate.isBefore(projection.completionDate),
        isTrue);
    expect(input.contributionAmount.minor, 10000);
  });

  test('debt payoff uses recorded balance and assumes no unrecorded interest',
      () {
    final projection = planner.projectDebt(DebtPlanInput(
      recordedBalance: const Money(90000, Currency.usd),
      paymentAmount: const Money(20000, Currency.usd),
      frequency: ContributionFrequency.fortnightly,
      startDate: DateTime(2026, 1, 1),
    ));
    expect(projection.paymentCount, 5);
    expect(projection.finalPayment.minor, 10000);
    expect(projection.assumptions.join(' '), contains('No interest'));
  });

  test('currency mismatch and non-positive schedules fail closed', () {
    expect(
      () => planner.projectDebt(DebtPlanInput(
        recordedBalance: const Money(1000, Currency.usd),
        paymentAmount: const Money(100, Currency.zwg),
        frequency: ContributionFrequency.weekly,
        startDate: DateTime(2026),
      )),
      throwsArgumentError,
    );
    expect(
      () => planner.projectSavings(SavingsPlanInput(
        currentAmount: const Money(0, Currency.usd),
        targetAmount: const Money(1000, Currency.usd),
        contributionAmount: const Money(0, Currency.usd),
        frequency: ContributionFrequency.weekly,
        startDate: DateTime(2026),
      )),
      throwsArgumentError,
    );
  });
}
