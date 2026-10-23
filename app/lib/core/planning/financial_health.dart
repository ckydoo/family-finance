import '../models/models.dart';
import '../money/money.dart';
import 'commitments.dart';

enum HealthInsightKind {
  incomeVsExpenses,
  budgetVsActual,
  spendingChange,
  upcomingCommitments,
  savingsProgress,
  debtProgress,
  suggestedAction,
}

class HealthInsight {
  const HealthInsight({
    required this.id,
    required this.kind,
    required this.title,
    required this.detail,
    required this.periodStart,
    required this.periodEnd,
    required this.calculation,
    required this.sourceIds,
    required this.limitations,
    this.amount,
  });

  final String id;
  final HealthInsightKind kind;
  final String title;
  final String detail;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String calculation;
  final List<String> sourceIds;
  final List<String> limitations;
  final Money? amount;
}

class FinancialHealthReview {
  const FinancialHealthReview({
    required this.currency,
    required this.periodStart,
    required this.periodEnd,
    required this.insights,
  });
  final Currency currency;
  final DateTime periodStart;
  final DateTime periodEnd;
  final List<HealthInsight> insights;
}

class FinancialHealthEngine {
  const FinancialHealthEngine();

  FinancialHealthReview review({
    required Currency currency,
    required DateTime periodStart,
    required DateTime periodEnd,
    required Iterable<Tx> transactions,
    required Iterable<Envelope> envelopes,
    required Iterable<FinancialCommitment> commitments,
    required Iterable<CommitmentOccurrence> occurrences,
    required Iterable<CommitmentPayment> commitmentPayments,
    required Iterable<Goal> goals,
    required Iterable<GoalTx> goalTransactions,
    required Iterable<FamilyDebt> debts,
    required Iterable<DebtRepayment> debtRepayments,
    Iterable<TxAllocation> txAllocations = const [],
  }) {
    if (!periodEnd.isAfter(periodStart)) {
      throw ArgumentError('The review period must end after it starts.');
    }
    final periodTx = transactions
        .where((value) =>
            value.deletedAt == null &&
            value.amount.currency == currency &&
            !value.when.isBefore(periodStart) &&
            value.when.isBefore(periodEnd))
        .toList();
    final income = periodTx
        .where((value) => value.type == TxType.income)
        .fold<int>(0, (sum, value) => sum + value.amount.minor);
    final expenses = periodTx
        .where((value) => value.type == TxType.expense)
        .fold<int>(0, (sum, value) => sum + value.amount.minor);
    final insights = <HealthInsight>[
      HealthInsight(
        id: 'income-expenses',
        kind: HealthInsightKind.incomeVsExpenses,
        title: income >= expenses
            ? 'Income covered recorded spending'
            : 'Recorded spending exceeded income',
        detail: 'Income ${Money(income, currency).text}; expenses ${Money(expenses, currency).text}.',
        periodStart: periodStart,
        periodEnd: periodEnd,
        calculation: '$income - $expenses = ${income - expenses} minor units',
        sourceIds: periodTx.map((value) => value.id).toList(growable: false),
        limitations: const [
          'Only recorded transactions in the selected currency are included.',
          'Transfers and unrecorded cash are not inferred.',
        ],
        amount: Money(income - expenses, currency),
      ),
    ];

    final allocationsByTx = <String, List<TxAllocation>>{};
    for (final alloc in txAllocations) {
      if (alloc.amount.currency == currency) {
        allocationsByTx.putIfAbsent(alloc.txId, () => []).add(alloc);
      }
    }
    final envelopeById = {
      for (final value in envelopes)
        if (value.limit.currency == currency) value.id: value
    };
    final expenseByEnvelope = <String, int>{};
    final attributedTxIds = <String>{};
    for (final tx in periodTx.where((value) => value.type == TxType.expense)) {
      final splits = allocationsByTx[tx.id];
      if (splits != null && splits.isNotEmpty) {
        for (final split in splits) {
          if (envelopeById.containsKey(split.envelopeId)) {
            expenseByEnvelope[split.envelopeId] =
                (expenseByEnvelope[split.envelopeId] ?? 0) + split.amount.minor;
            attributedTxIds.add(tx.id);
          }
        }
      } else {
        final id = tx.envelopeId;
        if (id != null && envelopeById.containsKey(id)) {
          expenseByEnvelope[id] =
              (expenseByEnvelope[id] ?? 0) + tx.amount.minor;
          attributedTxIds.add(tx.id);
        }
      }
    }
    final budget = envelopeById.values
        .fold<int>(0, (sum, value) => sum + value.limit.minor);
    final budgetActual = expenseByEnvelope.values.fold<int>(0, (a, b) => a + b);
    insights.add(HealthInsight(
      id: 'budget-actual',
      kind: HealthInsightKind.budgetVsActual,
      title: 'Budget versus recorded actual',
      detail: '${Money(budgetActual, currency).text} of ${Money(budget, currency).text} allocated.',
      periodStart: periodStart,
      periodEnd: periodEnd,
      calculation: '$budgetActual / $budget minor units',
      sourceIds: [
        ...envelopeById.keys,
        ...attributedTxIds,
      ],
      limitations: const [
        'Only expenses assigned to same-currency envelopes are included.',
      ],
      amount: Money(budget - budgetActual, currency),
    ));

    final duration = periodEnd.difference(periodStart);
    final previousStart = periodStart.subtract(duration);
    final previousExpenses = transactions
        .where((value) =>
            value.deletedAt == null &&
            value.type == TxType.expense &&
            value.amount.currency == currency &&
            !value.when.isBefore(previousStart) &&
            value.when.isBefore(periodStart))
        .toList();
    final currentByEnvelope = _sumByEnvelope(periodTx, allocationsByTx);
    final previousByEnvelope = _sumByEnvelope(previousExpenses, allocationsByTx);
    final changedIds = {...currentByEnvelope.keys, ...previousByEnvelope.keys};
    if (changedIds.isNotEmpty) {
      final biggest = changedIds.reduce((a, b) =>
          ((currentByEnvelope[a] ?? 0) - (previousByEnvelope[a] ?? 0)).abs() >=
                  ((currentByEnvelope[b] ?? 0) - (previousByEnvelope[b] ?? 0)).abs()
              ? a
              : b);
      final delta = (currentByEnvelope[biggest] ?? 0) -
          (previousByEnvelope[biggest] ?? 0);
      insights.add(HealthInsight(
        id: 'spending-change:$biggest',
        kind: HealthInsightKind.spendingChange,
        title: '${envelopeById[biggest]?.name ?? 'Unassigned'} spending ${delta >= 0 ? 'increased' : 'decreased'}',
        detail: '${Money(delta.abs(), currency).text} versus the preceding equal-length period.',
        periodStart: periodStart,
        periodEnd: periodEnd,
        calculation:
            '${currentByEnvelope[biggest] ?? 0} - ${previousByEnvelope[biggest] ?? 0} = $delta minor units',
        sourceIds: [
          ...periodTx.where((value) => (value.envelopeId ?? 'unassigned') == biggest).map((value) => value.id),
          ...previousExpenses.where((value) => (value.envelopeId ?? 'unassigned') == biggest).map((value) => value.id),
        ],
        limitations: const [
          'Category changes depend on consistent envelope assignment.',
        ],
        amount: Money(delta, currency),
      ));
    }

    final commitmentById = {for (final value in commitments) value.id: value};
    final upcomingEnd = periodEnd.add(const Duration(days: 30));
    final upcoming = occurrences.where((value) =>
        value.amount.currency == currency &&
        !value.dueDate.isBefore(periodEnd) &&
        value.dueDate.isBefore(upcomingEnd));
    var upcomingTotal = 0;
    final upcomingIds = <String>[];
    for (final occurrence in upcoming) {
      if (commitmentById[occurrence.commitmentId]?.status !=
          CommitmentStatus.active) {
        continue;
      }
      final remaining = const CommitmentSchedule()
          .outstanding(occurrence, commitmentPayments);
      upcomingTotal += remaining.minor;
      upcomingIds.add(occurrence.id);
    }
    insights.add(HealthInsight(
      id: 'upcoming-commitments',
      kind: HealthInsightKind.upcomingCommitments,
      title: 'Upcoming commitments',
      detail: '${Money(upcomingTotal, currency).text} due in the following 30 days.',
      periodStart: periodEnd,
      periodEnd: upcomingEnd,
      calculation: 'Sum of outstanding generated occurrences = $upcomingTotal minor units',
      sourceIds: upcomingIds,
      limitations: const ['Only generated active commitment occurrences are included.'],
      amount: Money(upcomingTotal, currency),
    ));

    final matchingGoals = goals.where((value) => value.target.currency == currency);
    final goalIds = matchingGoals.map((value) => value.id).toSet();
    final saved = goalTransactions
        .where((value) => goalIds.contains(value.goalId) && value.amount.currency == currency)
        .fold<int>(0, (sum, value) => sum + value.amount.minor);
    final target = matchingGoals.fold<int>(0, (sum, value) => sum + value.target.minor);
    insights.add(HealthInsight(
      id: 'savings-progress',
      kind: HealthInsightKind.savingsProgress,
      title: 'Savings progress',
      detail: '${Money(saved, currency).text} saved toward ${Money(target, currency).text}.',
      periodStart: periodStart,
      periodEnd: periodEnd,
      calculation: '$saved / $target minor units',
      sourceIds: [
        ...goalIds,
        ...goalTransactions.where((value) => goalIds.contains(value.goalId)).map((value) => value.id).whereType<String>(),
      ],
      limitations: const ['Contributions are cumulative and may predate this review period.'],
      amount: Money(saved, currency),
    ));

    final matchingDebts = debts.where((value) =>
        value.principal.currency == currency && value.status != 'archived');
    final debtIds = matchingDebts.map((value) => value.id).toSet();
    final principal = matchingDebts.fold<int>(0, (sum, value) => sum + value.principal.minor);
    final repaid = debtRepayments
        .where((value) => debtIds.contains(value.debtId) && value.amount.currency == currency)
        .fold<int>(0, (sum, value) => sum + value.amount.minor);
    insights.add(HealthInsight(
      id: 'debt-progress',
      kind: HealthInsightKind.debtProgress,
      title: 'Debt repayment progress',
      detail: '${Money(repaid, currency).text} recorded against ${Money(principal, currency).text} principal.',
      periodStart: periodStart,
      periodEnd: periodEnd,
      calculation: '$principal - $repaid = ${(principal - repaid).clamp(0, principal)} minor units',
      sourceIds: [
        ...debtIds,
        ...debtRepayments.where((value) => debtIds.contains(value.debtId)).map((value) => value.id),
      ],
      limitations: const ['Interest, fees, and lender statements are not inferred.'],
      amount: Money((principal - repaid).clamp(0, principal), currency),
    ));

    if (expenses > income) {
      insights.add(HealthInsight(
        id: 'action-negative-cashflow',
        kind: HealthInsightKind.suggestedAction,
        title: 'Review the largest recorded spending changes',
        detail: 'Recorded expenses exceeded income by ${Money(expenses - income, currency).text}.',
        periodStart: periodStart,
        periodEnd: periodEnd,
        calculation: '$expenses - $income = ${expenses - income} minor units',
        sourceIds: periodTx.map((value) => value.id).toList(growable: false),
        limitations: const ['This is a prompt to review records, not financial advice.'],
      ));
    }
    return FinancialHealthReview(
      currency: currency,
      periodStart: periodStart,
      periodEnd: periodEnd,
      insights: List.unmodifiable(insights),
    );
  }

  Map<String, int> _sumByEnvelope(
    Iterable<Tx> values,
    Map<String, List<TxAllocation>> allocationsByTx,
  ) {
    final result = <String, int>{};
    for (final value in values.where((tx) => tx.type == TxType.expense)) {
      final splits = allocationsByTx[value.id];
      if (splits != null && splits.isNotEmpty) {
        for (final split in splits) {
          result[split.envelopeId] =
              (result[split.envelopeId] ?? 0) + split.amount.minor;
        }
      } else {
        final key = value.envelopeId ?? 'unassigned';
        result[key] = (result[key] ?? 0) + value.amount.minor;
      }
    }
    return result;
  }
}
