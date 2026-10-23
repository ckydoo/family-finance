import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/planning/commitments.dart';
import 'package:mhuri_money/core/planning/financial_health.dart';

void main() {
  test('health review exposes calculations, sources, periods and limitations',
      () {
    final start = DateTime(2026, 10);
    final end = DateTime(2026, 11);
    final review = const FinancialHealthEngine().review(
      currency: Currency.usd,
      periodStart: start,
      periodEnd: end,
      transactions: [
        Tx(
          id: 'income',
          memberId: 'me',
          type: TxType.income,
          amount: const Money(100000, Currency.usd),
          method: Method.bankTransfer,
          note: 'Income',
          when: DateTime(2026, 10, 2),
        ),
        Tx(
          id: 'food-current',
          envelopeId: 'food',
          memberId: 'me',
          type: TxType.expense,
          amount: const Money(120000, Currency.usd),
          method: Method.cash,
          note: 'Food',
          when: DateTime(2026, 10, 3),
        ),
        Tx(
          id: 'food-previous',
          envelopeId: 'food',
          memberId: 'me',
          type: TxType.expense,
          amount: const Money(30000, Currency.usd),
          method: Method.cash,
          note: 'Food',
          when: DateTime(2026, 9, 3),
        ),
        Tx(
          id: 'other-currency',
          memberId: 'me',
          type: TxType.expense,
          amount: const Money(999999, Currency.zwg),
          method: Method.cash,
          note: 'Excluded',
          when: DateTime(2026, 10, 3),
        ),
      ],
      envelopes: [
        Envelope(
          id: 'food',
          name: 'Food',
          emoji: 'restaurant',
          limit: const Money(150000, Currency.usd),
        ),
      ],
      commitments: [
        FinancialCommitment(
          id: 'rent',
          name: 'Rent',
          amount: const Money(50000, Currency.usd),
          firstDueDate: DateTime(2026, 11, 5),
          recurrence: CommitmentRecurrence.monthly,
          createdById: 'me',
        ),
      ],
      occurrences: [
        CommitmentOccurrence(
          id: 'rent-november',
          commitmentId: 'rent',
          occurrenceKey: '2026-11-05',
          dueDate: DateTime(2026, 11, 5),
          amount: const Money(50000, Currency.usd),
        ),
      ],
      commitmentPayments: const [],
      goals: [
        const Goal(
          id: 'reserve',
          name: 'Reserve',
          emoji: 'savings',
          target: Money(200000, Currency.usd),
        ),
      ],
      goalTransactions: [
        GoalTx(
          id: 'saved',
          goalId: 'reserve',
          byMemberId: 'me',
          amount: const Money(50000, Currency.usd),
          at: DateTime(2026, 10, 4),
        ),
      ],
      debts: [
        FamilyDebt(
          id: 'loan',
          name: 'Loan',
          direction: DebtDirection.iOwe,
          principal: const Money(300000, Currency.usd),
          createdById: 'me',
        ),
      ],
      debtRepayments: [
        DebtRepayment(
          id: 'repayment',
          debtId: 'loan',
          memberId: 'me',
          amount: const Money(100000, Currency.usd),
          paidAt: DateTime(2026, 10, 5),
        ),
      ],
    );

    expect(review.insights, hasLength(7));
    expect(review.insights.every((value) => value.calculation.isNotEmpty),
        isTrue);
    expect(review.insights.every((value) => value.limitations.isNotEmpty),
        isTrue);
    expect(
      review.insights
          .firstWhere((value) => value.id == 'income-expenses')
          .amount!
          .minor,
      -20000,
    );
    expect(
      review.insights
          .firstWhere((value) => value.id == 'upcoming-commitments')
          .sourceIds,
      contains('rent-november'),
    );
    expect(
      review.insights
          .firstWhere((value) => value.id == 'debt-progress')
          .amount!
          .minor,
      200000,
    );
    expect(review.insights.expand((value) => value.sourceIds),
        isNot(contains('other-currency')));
  });

  test('invalid period fails closed', () {
    expect(
      () => const FinancialHealthEngine().review(
        currency: Currency.usd,
        periodStart: DateTime(2026, 2),
        periodEnd: DateTime(2026, 1),
        transactions: const [],
        envelopes: const [],
        commitments: const [],
        occurrences: const [],
        commitmentPayments: const [],
        goals: const [],
        goalTransactions: const [],
        debts: const [],
        debtRepayments: const [],
      ),
      throwsArgumentError,
    );
  });

  test('health review attributes split transaction allocations once per category',
      () {
    final start = DateTime(2026, 10);
    final end = DateTime(2026, 11);
    final review = const FinancialHealthEngine().review(
      currency: Currency.usd,
      periodStart: start,
      periodEnd: end,
      transactions: [
        Tx(
          id: 'split-tx',
          memberId: 'me',
          type: TxType.expense,
          amount: const Money(10000, Currency.usd),
          method: Method.cash,
          note: 'Supermarket split',
          when: DateTime(2026, 10, 10),
        ),
      ],
      txAllocations: const [
        TxAllocation(
          id: 'alloc-food',
          txId: 'split-tx',
          envelopeId: 'food',
          amount: Money(6000, Currency.usd),
        ),
        TxAllocation(
          id: 'alloc-home',
          txId: 'split-tx',
          envelopeId: 'home',
          amount: Money(4000, Currency.usd),
        ),
      ],
      envelopes: [
        Envelope(
          id: 'food',
          name: 'Food',
          emoji: 'restaurant',
          limit: const Money(10000, Currency.usd),
        ),
        Envelope(
          id: 'home',
          name: 'Home',
          emoji: 'home',
          limit: const Money(5000, Currency.usd),
        ),
      ],
      commitments: const [],
      occurrences: const [],
      commitmentPayments: const [],
      goals: const [],
      goalTransactions: const [],
      debts: const [],
      debtRepayments: const [],
    );

    final budgetInsight = review.insights
        .firstWhere((item) => item.kind == HealthInsightKind.budgetVsActual);
    // Total budget = 15000, total split actual = 10000 -> remaining = 5000
    expect(budgetInsight.amount?.minor, 5000);
    expect(budgetInsight.sourceIds, contains('split-tx'));
  });
}
