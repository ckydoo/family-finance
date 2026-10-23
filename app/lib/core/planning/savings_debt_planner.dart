import '../money/money.dart';

enum ContributionFrequency { weekly, fortnightly, monthly }

extension ContributionFrequencyDays on ContributionFrequency {
  int get approximateDays => switch (this) {
        ContributionFrequency.weekly => 7,
        ContributionFrequency.fortnightly => 14,
        ContributionFrequency.monthly => 30,
      };
}

class SavingsPlanInput {
  const SavingsPlanInput({
    required this.currentAmount,
    required this.targetAmount,
    required this.contributionAmount,
    required this.frequency,
    required this.startDate,
    this.targetDate,
  });
  final Money currentAmount;
  final Money targetAmount;
  final Money contributionAmount;
  final ContributionFrequency frequency;
  final DateTime startDate;
  final DateTime? targetDate;
}

class DebtPlanInput {
  const DebtPlanInput({
    required this.recordedBalance,
    required this.paymentAmount,
    required this.frequency,
    required this.startDate,
  });
  final Money recordedBalance;
  final Money paymentAmount;
  final ContributionFrequency frequency;
  final DateTime startDate;
}

class PlanProjection {
  const PlanProjection({
    required this.completionDate,
    required this.paymentCount,
    required this.finalPayment,
    required this.meetsTargetDate,
    required this.assumptions,
  });
  final DateTime completionDate;
  final int paymentCount;
  final Money finalPayment;
  final bool? meetsTargetDate;
  final List<String> assumptions;
}

class SavingsDebtPlanner {
  const SavingsDebtPlanner();

  PlanProjection projectSavings(SavingsPlanInput input) => _project(
        balance: input.targetAmount.minor - input.currentAmount.minor,
        currency: _sameCurrency([
          input.currentAmount,
          input.targetAmount,
          input.contributionAmount,
        ]),
        payment: input.contributionAmount,
        frequency: input.frequency,
        startDate: input.startDate,
        targetDate: input.targetDate,
        assumptions: const [
          'No interest or investment return is assumed.',
          'Only the entered contribution schedule is projected.',
        ],
      );

  PlanProjection projectDebt(DebtPlanInput input) => _project(
        balance: input.recordedBalance.minor,
        currency: _sameCurrency([
          input.recordedBalance,
          input.paymentAmount,
        ]),
        payment: input.paymentAmount,
        frequency: input.frequency,
        startDate: input.startDate,
        assumptions: const [
          'No interest or fees are included because they are not recorded.',
          'Payments are simulations and are never posted to the ledger.',
        ],
      );

  PlanProjection _project({
    required int balance,
    required Currency currency,
    required Money payment,
    required ContributionFrequency frequency,
    required DateTime startDate,
    DateTime? targetDate,
    required List<String> assumptions,
  }) {
    if (balance <= 0) {
      return PlanProjection(
        completionDate: startDate,
        paymentCount: 0,
        finalPayment: Money(0, currency),
        meetsTargetDate: targetDate == null || !startDate.isAfter(targetDate),
        assumptions: assumptions,
      );
    }
    if (payment.minor <= 0) {
      throw ArgumentError('The recurring amount must be positive.');
    }
    final count = (balance / payment.minor).ceil();
    final finalPayment = balance - payment.minor * (count - 1);
    final completion = _atPayment(startDate, frequency, count);
    return PlanProjection(
      completionDate: completion,
      paymentCount: count,
      finalPayment: Money(finalPayment, currency),
      meetsTargetDate:
          targetDate == null ? null : !completion.isAfter(targetDate),
      assumptions: assumptions,
    );
  }

  Currency _sameCurrency(List<Money> values) {
    final currency = values.first.currency;
    if (values.any((value) => value.currency != currency)) {
      throw ArgumentError('Planning values must use one currency.');
    }
    return currency;
  }

  DateTime _atPayment(
    DateTime start,
    ContributionFrequency frequency,
    int count,
  ) =>
      switch (frequency) {
        ContributionFrequency.weekly =>
          start.add(Duration(days: 7 * (count - 1))),
        ContributionFrequency.fortnightly =>
          start.add(Duration(days: 14 * (count - 1))),
        ContributionFrequency.monthly => _addMonths(start, count - 1),
      };

  DateTime _addMonths(DateTime value, int count) {
    final total = value.year * 12 + value.month - 1 + count;
    final year = total ~/ 12;
    final month = total % 12 + 1;
    final day = value.day.clamp(1, DateTime(year, month + 1, 0).day);
    return DateTime(year, month, day, value.hour, value.minute);
  }
}
