import '../models/models.dart';
import '../money/money.dart';
import '../state/app_state.dart';
import 'commitments.dart';

class WeeklyBudgetHighlight {
  final Envelope envelope;
  final Money spentThisWeek;
  final Money spentThisCycle;
  final Money effectiveLimit;
  final Money remainingThisCycle;
  final Pace pace;

  const WeeklyBudgetHighlight({
    required this.envelope,
    required this.spentThisWeek,
    required this.spentThisCycle,
    required this.effectiveLimit,
    required this.remainingThisCycle,
    required this.pace,
  });

  bool get isOverBudget => pace == Pace.over;
  bool get isNearLimit => pace == Pace.watch || pace == Pace.reached;
}

class WeeklyFamilySummary {
  final DateTime windowStart;
  final DateTime windowEnd;
  final Money totalSpent;
  final Money totalIncome;
  final int expenseCount;
  final int incomeCount;
  final WeeklyBudgetHighlight? budgetHighlight;
  final int upcomingBillsCount;
  final String? nextBillTitle;
  final int openTasksCount;
  final Money savedThisWeek;
  final Money debtRepaidThisWeek;
  final String supportiveHeadline;
  final String supportiveNextStep;

  const WeeklyFamilySummary({
    required this.windowStart,
    required this.windowEnd,
    required this.totalSpent,
    required this.totalIncome,
    required this.expenseCount,
    required this.incomeCount,
    required this.budgetHighlight,
    required this.upcomingBillsCount,
    required this.nextBillTitle,
    required this.openTasksCount,
    required this.savedThisWeek,
    required this.debtRepaidThisWeek,
    required this.supportiveHeadline,
    required this.supportiveNextStep,
  });

  bool get hasActivity =>
      expenseCount > 0 ||
      incomeCount > 0 ||
      savedThisWeek.minor > 0 ||
      debtRepaidThisWeek.minor > 0 ||
      upcomingBillsCount > 0 ||
      (budgetHighlight != null && budgetHighlight!.spentThisCycle.minor > 0);

  String formatShareText({
    required String familyName,
    required bool maskAmounts,
  }) {
    String fmt(Money m) => maskAmounts ? '${m.currency.symbol} ••••' : m.text;
    final buffer = StringBuffer()
      ..writeln('$familyName · Weekly Mhuri Summary')
      ..writeln(supportiveHeadline)
      ..writeln('• Spent this week: ${fmt(totalSpent)} ($expenseCount ${expenseCount == 1 ? 'expense' : 'expenses'})');
    if (totalIncome.minor > 0) {
      buffer.writeln('• Income this week: ${fmt(totalIncome)}');
    }
    if (budgetHighlight != null) {
      final b = budgetHighlight!;
      if (b.effectiveLimit.minor > 0) {
        if (b.isOverBudget) {
          final over = Money(b.remainingThisCycle.minor.abs(), b.remainingThisCycle.currency);
          buffer.writeln('• Budget focus: ${b.envelope.name} (${fmt(over)} over plan)');
        } else {
          buffer.writeln('• Budget focus: ${b.envelope.name} (${fmt(b.remainingThisCycle)} left)');
        }
      } else {
        buffer.writeln('• Most active budget: ${b.envelope.name} (${fmt(b.spentThisWeek)} this week)');
      }
    }
    if (savedThisWeek.minor > 0) {
      buffer.writeln('• Saved toward goals: ${fmt(savedThisWeek)}');
    }
    if (debtRepaidThisWeek.minor > 0) {
      buffer.writeln('• Debt repaid: ${fmt(debtRepaidThisWeek)}');
    }
    if (upcomingBillsCount > 0) {
      buffer.writeln(
        '• Upcoming bills (next 7 days): $upcomingBillsCount${nextBillTitle != null ? ' (next: $nextBillTitle)' : ''}',
      );
    }
    buffer.writeln('Next step: $supportiveNextStep');
    return buffer.toString().trimRight();
  }
}

class WeeklySummaryPlanner {
  const WeeklySummaryPlanner._();

  static WeeklyFamilySummary compute(AppState s, {DateTime? nowOverride}) {
    final current = nowOverride ?? s.now;
    final today = DateTime(current.year, current.month, current.day);
    final windowStart = today.subtract(const Duration(days: 6));
    final windowEnd = DateTime(today.year, today.month, today.day, 23, 59, 59, 999);
    final displayCur = s.displayCurrency;
    final rate = s.rate;

    bool inWindow(DateTime d) => !d.isBefore(windowStart) && !d.isAfter(windowEnd);

    var spentMinor = 0;
    var incomeMinor = 0;
    var expenseCount = 0;
    var incomeCount = 0;
    final weeklyEnvelopeSpendMinor = <String, int>{};

    // Only familyTransactions (never private accounts or deleted tombstones).
    for (final tx in s.familyTransactions) {
      if (!inWindow(tx.when)) continue;
      final inDisplay = tx.amount.inCurrency(displayCur, rate).minor;
      if (tx.type == TxType.expense) {
        spentMinor += inDisplay;
        expenseCount++;
        final splits = s.txAllocations.where((a) => a.txId == tx.id).toList();
        if (splits.isNotEmpty) {
          for (final split in splits) {
            final env = s.envelope(split.envelopeId);
            if (env == null || env.isPersonal || env.isArchived) continue;
            final amt = split.amount.inCurrency(env.limit.currency, rate).minor;
            weeklyEnvelopeSpendMinor[env.id] =
                (weeklyEnvelopeSpendMinor[env.id] ?? 0) + amt;
          }
        } else if (tx.envelopeId != null) {
          final env = s.envelope(tx.envelopeId);
          if (env != null && !env.isPersonal && !env.isArchived) {
            final amt = tx.amount.inCurrency(env.limit.currency, rate).minor;
            weeklyEnvelopeSpendMinor[env.id] =
                (weeklyEnvelopeSpendMinor[env.id] ?? 0) + amt;
          }
        }
      } else {
        incomeMinor += inDisplay;
        incomeCount++;
      }
    }

    final sharedEnvelopes = s.envelopes
        .where((e) => !e.isPersonal && !e.isArchived)
        .toList(growable: false);

    WeeklyBudgetHighlight? budgetHighlight;
    if (sharedEnvelopes.isNotEmpty) {
      final highlights = [
        for (final env in sharedEnvelopes)
          WeeklyBudgetHighlight(
            envelope: env,
            spentThisWeek: Money(
              weeklyEnvelopeSpendMinor[env.id] ?? 0,
              env.limit.currency,
            ),
            spentThisCycle: s.spentOn(env),
            effectiveLimit: s.effectiveLimit(env),
            remainingThisCycle: s.remainingOn(env),
            pace: s.paceOf(env),
          ),
      ];

      int urgencyRank(WeeklyBudgetHighlight h) => switch (h.pace) {
            Pace.over => 0,
            Pace.reached => 1,
            Pace.watch => 2,
            Pace.onTrack => 3,
          };

      highlights.sort((a, b) {
        final byRank = urgencyRank(a).compareTo(urgencyRank(b));
        if (byRank != 0) return byRank;
        final aWeekDisp = a.spentThisWeek.inCurrency(displayCur, rate).minor;
        final bWeekDisp = b.spentThisWeek.inCurrency(displayCur, rate).minor;
        if (aWeekDisp != bWeekDisp) return bWeekDisp.compareTo(aWeekDisp);
        final aCycleDisp = a.spentThisCycle.inCurrency(displayCur, rate).minor;
        final bCycleDisp = b.spentThisCycle.inCurrency(displayCur, rate).minor;
        return bCycleDisp.compareTo(aCycleDisp);
      });

      budgetHighlight = highlights.first;
    }

    var savedMinor = 0;
    for (final gtx in s.goalTxs) {
      if (inWindow(gtx.at)) {
        savedMinor += gtx.amount.inCurrency(displayCur, rate).minor;
      }
    }

    var debtRepaidMinor = 0;
    for (final rep in s.debtRepayments) {
      if (inWindow(rep.paidAt)) {
        debtRepaidMinor += rep.amount.inCurrency(displayCur, rate).minor;
      }
    }

    // Upcoming bills within 7 days.
    final horizon = today.add(const Duration(days: 7));
    final upcomingBills = <({DateTime due, String title})>[];
    for (final rule in s.recurring) {
      if (!rule.active || rule.isArchived) continue;
      final due = DateTime(rule.nextDue.year, rule.nextDue.month, rule.nextDue.day);
      if (!due.isAfter(horizon)) {
        upcomingBills.add((due: due, title: rule.name));
      }
    }
    final commitmentsById = {
      for (final c in s.financialCommitments)
        if (c.status == CommitmentStatus.active) c.id: c,
    };
    const schedule = CommitmentSchedule();
    for (final occ in s.commitmentOccurrences) {
      final commitment = commitmentsById[occ.commitmentId];
      if (commitment == null ||
          occ.status == CommitmentOccurrenceStatus.paid ||
          occ.status == CommitmentOccurrenceStatus.skipped ||
          occ.status == CommitmentOccurrenceStatus.canceled) {
        continue;
      }
      if (schedule.outstanding(occ, s.commitmentPayments).isZero) continue;
      final due = DateTime(occ.dueDate.year, occ.dueDate.month, occ.dueDate.day);
      if (!due.isAfter(horizon)) {
        upcomingBills.add((due: due, title: commitment.name));
      }
    }
    upcomingBills.sort((a, b) => a.due.compareTo(b.due));

    final openTasksCount = s.familyTasks
        .where((t) => !t.isArchived && !t.isComplete)
        .length;

    final totalSpent = Money(spentMinor, displayCur);
    final totalIncome = Money(incomeMinor, displayCur);
    final savedThisWeek = Money(savedMinor, displayCur);
    final debtRepaidThisWeek = Money(debtRepaidMinor, displayCur);

    String headline;
    String nextStep;

    if (budgetHighlight != null && budgetHighlight.isOverBudget) {
      final over = Money(
        budgetHighlight.remainingThisCycle.minor.abs(),
        budgetHighlight.remainingThisCycle.currency,
      );
      headline =
          'Steady week together — ${budgetHighlight.envelope.name} needs a quick adjustment.';
      nextStep =
          '${budgetHighlight.envelope.name} is ${over.text} above its plan — review together or move money from another budget.';
    } else if (budgetHighlight != null && budgetHighlight.isNearLimit) {
      headline =
          'Good progress this week — ${budgetHighlight.envelope.name} is getting close to its limit.';
      nextStep =
          '${budgetHighlight.envelope.name} has ${budgetHighlight.remainingThisCycle.text} left for the rest of the cycle.';
    } else if (upcomingBills.isNotEmpty) {
      headline =
          'Your household is on track this week with ${upcomingBills.length} upcoming ${upcomingBills.length == 1 ? 'bill' : 'bills'}.';
      nextStep =
          'Keep ${upcomingBills.first.title} in mind for the coming days.';
    } else if (expenseCount > 0 || savedMinor > 0 || debtRepaidMinor > 0) {
      headline =
          'Calm, steady week — your household finances are organised and up to date.';
      nextStep = savedMinor > 0
          ? 'You added ${savedThisWeek.text} to savings this week — keep the momentum going.'
          : 'Continue logging daily expenses so everyone sees the same clear picture.';
    } else {
      headline = 'Ready for a fresh week together.';
      nextStep =
          'Log your first expense or income of the week to keep the household plan current.';
    }

    return WeeklyFamilySummary(
      windowStart: windowStart,
      windowEnd: windowEnd,
      totalSpent: totalSpent,
      totalIncome: totalIncome,
      expenseCount: expenseCount,
      incomeCount: incomeCount,
      budgetHighlight: budgetHighlight,
      upcomingBillsCount: upcomingBills.length,
      nextBillTitle: upcomingBills.firstOrNull?.title,
      openTasksCount: openTasksCount,
      savedThisWeek: savedThisWeek,
      debtRepaidThisWeek: debtRepaidThisWeek,
      supportiveHeadline: headline,
      supportiveNextStep: nextStep,
    );
  }
}
