import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/state/app_state.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/money/money.dart';
import '../../core/models/models.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/ring_progress.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../meeting/family_meeting_screen.dart';
import '../lists/lists_screen.dart';

/// Monthly report card (spec Module I1/I2) - one screen the family can
/// review together at the monthly Family Meeting.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _cycleOffset = 0;

  DateTime _cycleStart(AppState state, int offset) => DateTime(
        state.cycleStart.year,
        state.cycleStart.month - offset,
        state.monthStartDay,
      );

  String _periodLabel(BuildContext context, DateTime start, DateTime end) {
    final language = Localizations.localeOf(context).languageCode;
    final locale =
        const {'es', 'fr', 'pt'}.contains(language) ? language : 'en';
    return '${DateFormat.MMMd(locale).format(start)} – '
        '${DateFormat.yMMMd(locale).format(end.subtract(const Duration(days: 1)))}';
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final periodStart = _cycleStart(s, _cycleOffset);
    final periodEnd = _cycleStart(s, _cycleOffset - 1);
    final periodLabel = _periodLabel(context, periodStart, periodEnd);
    final transactions = s.txs
        .where((tx) =>
            !tx.when.isBefore(periodStart) && tx.when.isBefore(periodEnd))
        .toList();
    final savings = s.goalTxs
        .where(
            (tx) => !tx.at.isBefore(periodStart) && tx.at.isBefore(periodEnd))
        .toList();
    final previousStart = _cycleStart(s, _cycleOffset + 1);
    final previousTransactions = s.txs
        .where((tx) =>
            !tx.when.isBefore(previousStart) && tx.when.isBefore(periodStart))
        .toList();

    final displayCur = s.displayCurrency;
    final envelopeById = {for (final e in s.envelopes) e.id: e};
    final spentByEnvelope = <String, int>{};
    final spentUsdByEnvelope = <String, int>{};
    final allocationsByTx = <String, List<TxAllocation>>{};
    for (final allocation in s.txAllocations) {
      allocationsByTx.putIfAbsent(allocation.txId, () => []).add(allocation);
    }
    var incomeMinor = 0;
    var spentMinor = 0;
    var cashSpent = 0;
    for (final tx in transactions) {
      final inDisplay = tx.amount.inCurrency(displayCur, s.rate).minor;
      if (tx.type == TxType.income) {
        incomeMinor += inDisplay;
        continue;
      }
      spentMinor += inDisplay;
      if (tx.method == Method.cash) cashSpent += inDisplay;
      final allocations = allocationsByTx[tx.id] ?? const <TxAllocation>[];
      final categoryParts = allocations.isNotEmpty
          ? allocations
              .map((a) => (a.envelopeId, a.amount))
              .toList(growable: false)
          : [(tx.envelopeId, tx.amount)];
      for (final part in categoryParts) {
        final envelope = envelopeById[part.$1];
        if (envelope == null) continue;
        spentByEnvelope.update(
          envelope.id,
          (value) =>
              value + part.$2.inCurrency(envelope.limit.currency, s.rate).minor,
          ifAbsent: () =>
              part.$2.inCurrency(envelope.limit.currency, s.rate).minor,
        );
        spentUsdByEnvelope.update(
          envelope.id,
          (value) => value + part.$2.inCurrency(displayCur, s.rate).minor,
          ifAbsent: () => part.$2.inCurrency(displayCur, s.rate).minor,
        );
      }
    }
    final income = Money(incomeMinor, displayCur);
    final spent = Money(spentMinor, displayCur);
    final saved = Money(
      savings.fold(
          0, (sum, tx) => sum + tx.amount.inCurrency(displayCur, s.rate).minor),
      displayCur,
    );
    final cashLeakShare = spent.minor == 0 ? 0.0 : cashSpent / spent.minor;
    int totalFor(List<Tx> rows, TxType type) =>
        rows.where((tx) => tx.type == type).fold(0,
            (sum, tx) => sum + tx.amount.inCurrency(displayCur, s.rate).minor);
    final previousIncome =
        Money(totalFor(previousTransactions, TxType.income), displayCur);
    final previousSpent =
        Money(totalFor(previousTransactions, TxType.expense), displayCur);
    BudgetCyclePlan? selectedPlan;
    for (final plan in s.budgetPlans) {
      if (plan.cycleStart.year == periodStart.year &&
          plan.cycleStart.month == periodStart.month &&
          plan.cycleStart.day == periodStart.day) {
        selectedPlan = plan;
        break;
      }
    }
    final plannedMinor =
        selectedPlan?.allocations.entries.fold<int>(0, (sum, entry) {
              final envelope = envelopeById[entry.key];
              if (envelope == null) return sum;
              return sum +
                  Money(entry.value, envelope.limit.currency)
                      .inCurrency(displayCur, s.rate)
                      .minor;
            }) ??
            0;
    final planned = Money(plannedMinor, displayCur);

    final trackedEnvelopes = s.envelopes.where((e) => !e.isPersonal).toList();
    final onTrack = trackedEnvelopes
        .where((e) =>
            (spentByEnvelope[e.id] ?? 0) <=
            (_cycleOffset == 0 ? s.effectiveLimit(e) : e.limit).minor)
        .length;
    final envelopeHealth =
        trackedEnvelopes.isEmpty ? 1.0 : onTrack / trackedEnvelopes.length;
    final days = periodEnd.difference(periodStart).inDays;
    final historicDaily = days <= 0
        ? 0
        : ((income.minor - spent.minor - saved.minor) / days).floor();
    final safePerDay = _cycleOffset == 0
        ? s.safeToSpend
        : Money(historicDaily < 0 ? 0 : historicDaily, displayCur);

    return Scaffold(
      appBar: AppBar(
        title: Text(tStr(context, 'reportTitle')),
        actions: [
          PopupMenuButton<int>(
            tooltip: MaterialLocalizations.of(context).showMenuTooltip,
            icon: const Icon(Icons.calendar_month_outlined),
            initialValue: _cycleOffset,
            onSelected: (value) => setState(() => _cycleOffset = value),
            itemBuilder: (context) => [
              for (var offset = 0; offset < 3; offset++)
                PopupMenuItem<int>(
                  value: offset,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: offset == _cycleOffset
                            ? Icon(Icons.check,
                                size: 19, color: context.primary)
                            : null,
                      ),
                      Expanded(
                        child: Text(
                          _periodLabel(
                            context,
                            _cycleStart(s, offset),
                            _cycleStart(s, offset - 1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
            onRefresh: () => s.refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_month_outlined,
                            size: 17, color: context.primary),
                        const SizedBox(width: 7),
                        Text(
                          periodLabel,
                          style: TextStyle(
                            color: context.inkSoft,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ── Stat grid ────────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _stat(
                        context,
                        tStr(context, 'income'),
                        income.text,
                        context.incomeGreen,
                        Icons.trending_up,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _stat(
                        context,
                        tStr(context, 'spent'),
                        spent.text,
                        context.expenseRed,
                        Icons.trending_down,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _stat(
                        context,
                        tStr(context, 'saved'),
                        saved.text,
                        context.primary,
                        Icons.track_changes,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _stat(
                        context,
                        tStr(context, 'safePerDay'),
                        safePerDay.text,
                        context.ink,
                        Icons.wb_twilight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _CycleComparisonCard(
                  income: income,
                  spent: spent,
                  previousIncome: previousIncome,
                  previousSpent: previousSpent,
                ),
                const SizedBox(height: 12),
                _PlanVsActualCard(
                  plan: selectedPlan,
                  planned: planned,
                  spent: spent,
                ),
                const SizedBox(height: 12),
                _MonthEndSummaryCard(
                  income: income,
                  spent: spent,
                  saved: saved,
                  plan: selectedPlan,
                ),
                const SizedBox(height: 12),

                // ── Envelope health ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      RingProgress(
                        value: envelopeHealth,
                        size: 74,
                        stroke: 9,
                        color: envelopeHealth >= 0.7
                            ? context.primary
                            : context.accent,
                        child: Text(
                          '${(envelopeHealth * 100).round()}%',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: context.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tStr(context, 'envelopeHealth'),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: context.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppLocalizations.of(context)!.reachedMove(
                                onTrack,
                                trackedEnvelopes.length,
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: context.inkSoft,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Cash leak ────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tStr(context, 'cashLeak'),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: context.ink,
                              ),
                            ),
                          ),
                          Text(
                            AppLocalizations.of(context)!
                                .cashShare((cashLeakShare * 100).round()),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: context.accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: cashLeakShare,
                          minHeight: 8,
                          backgroundColor: context.track,
                          color: context.accent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)!.cashTrace,
                        style: TextStyle(
                            fontSize: 11.5,
                            color: context.inkSoft,
                            height: 1.35),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Top envelopes ────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.whereMoneyWent,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: context.ink,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _WhereItWent(
                        state: s,
                        spentUsdByEnvelope: spentUsdByEnvelope,
                      ),
                      const SizedBox(height: 14),
                      _TrendCard(state: s),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Shopping & List Tracking ─────────────────────────────────
                _ShoppingTrackingCard(
                  state: s,
                  transactions: transactions,
                  displayCurrency: displayCur,
                  envelopeById: envelopeById,
                ),
                const SizedBox(height: 12),
                _FamilyProgressCard(state: s, displayCurrency: displayCur),
                const SizedBox(height: 12),
                _CommitmentsCard(
                  state: s,
                  transactions: transactions,
                  displayCurrency: displayCur,
                ),
                const SizedBox(height: 16),

                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const FamilyMeetingScreen()),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.primary,
                    foregroundColor: context.onSolid,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: kBRadiusM),
                  ),
                  icon: const Icon(Icons.groups),
                  label: Text(
                    AppLocalizations.of(context)!.meetingCta,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final path = await AppScope.of(context).exportCsv();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          path == null
                              ? AppLocalizations.of(context)!.exportFailed
                              : AppLocalizations.of(context)!.csvSaved(path),
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.primary,
                    side: BorderSide(color: context.primary),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: kBRadiusM),
                  ),
                  icon: const Icon(Icons.table_view, size: 20),
                  label: Text(AppLocalizations.of(context)!.exportCsv),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    AppLocalizations.of(context)!.bringToMeeting,
                    style: TextStyle(fontSize: 11.5, color: context.inkSoft),
                  ),
                ),
              ],
            )),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value, Color color,
          IconData icon) =>
      Container(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.hairline)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: context.primary),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(fontSize: 11.5, color: context.inkSoft),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      );
}

class _CycleComparisonCard extends StatelessWidget {
  const _CycleComparisonCard({
    required this.income,
    required this.spent,
    required this.previousIncome,
    required this.previousSpent,
  });

  final Money income;
  final Money spent;
  final Money previousIncome;
  final Money previousSpent;

  String _change(int current, int previous) {
    if (previous == 0) return current == 0 ? 'No change' : 'New this cycle';
    final percent = ((current - previous) / previous * 100).round();
    if (percent == 0) return 'No change';
    return '${percent > 0 ? '+' : ''}$percent%';
  }

  @override
  Widget build(BuildContext context) => _ReportCard(
        title: 'Compared with last cycle',
        icon: Icons.compare_arrows_rounded,
        child: Row(children: [
          Expanded(
            child: _ComparisonMetric(
              label: 'Income',
              value: income.text,
              change: _change(income.minor, previousIncome.minor),
              positive: income.minor >= previousIncome.minor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ComparisonMetric(
              label: 'Spending',
              value: spent.text,
              change: _change(spent.minor, previousSpent.minor),
              positive: spent.minor <= previousSpent.minor,
            ),
          ),
        ]),
      );
}

class _ComparisonMetric extends StatelessWidget {
  const _ComparisonMetric({
    required this.label,
    required this.value,
    required this.change,
    required this.positive,
  });
  final String label;
  final String value;
  final String change;
  final bool positive;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: context.inkSoft)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: context.ink)),
          const SizedBox(height: 3),
          Text(change,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: positive ? context.incomeGreen : context.expenseRed)),
        ],
      );
}

class _PlanVsActualCard extends StatelessWidget {
  const _PlanVsActualCard({
    required this.plan,
    required this.planned,
    required this.spent,
  });
  final BudgetCyclePlan? plan;
  final Money planned;
  final Money spent;

  @override
  Widget build(BuildContext context) {
    if (plan == null) {
      return const _ReportCard(
        title: 'Plan vs actual',
        icon: Icons.fact_check_outlined,
        child: Text(
          'No saved plan for this cycle. Create one in Budgets to compare the family agreement with actual spending.',
        ),
      );
    }
    final ratio = planned.minor <= 0 ? 0.0 : spent.minor / planned.minor;
    final remaining = Money(planned.minor - spent.minor, planned.currency);
    return _ReportCard(
      title: 'Plan vs actual',
      icon: Icons.fact_check_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Planned ${planned.text}')),
          Text('Actual ${spent.text}',
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: ratio.clamp(0, 1),
            minHeight: 9,
            backgroundColor: context.track,
            color: ratio > 1 ? context.expenseRed : context.primary,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          remaining.minor >= 0
              ? '${remaining.text} remains in the plan'
              : '${Money(-remaining.minor, remaining.currency).text} over plan',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: remaining.minor >= 0
                  ? context.incomeGreen
                  : context.expenseRed),
        ),
        if (plan!.isClosed) ...[
          const SizedBox(height: 5),
          Text('Month closed', style: TextStyle(color: context.inkSoft)),
        ],
      ]),
    );
  }
}

class _FamilyProgressCard extends StatelessWidget {
  const _FamilyProgressCard(
      {required this.state, required this.displayCurrency});
  final AppState state;
  final Currency displayCurrency;

  @override
  Widget build(BuildContext context) {
    final goalTarget = state.goals.fold<int>(
        0,
        (sum, goal) =>
            sum + goal.target.inCurrency(displayCurrency, state.rate).minor);
    final goalSaved = state.goalTxs.fold<int>(
        0,
        (sum, tx) =>
            sum + tx.amount.inCurrency(displayCurrency, state.rate).minor);
    final campaignTarget = state.contributionCampaigns
        .where((campaign) => campaign.status == 'active')
        .fold<int>(
            0,
            (sum, campaign) =>
                sum +
                campaign.target.inCurrency(displayCurrency, state.rate).minor);
    final campaignCollected = state.contributionCampaigns
        .where((campaign) => campaign.status == 'active')
        .fold<int>(
            0,
            (sum, campaign) =>
                sum +
                state
                    .collectedFor(campaign)
                    .inCurrency(displayCurrency, state.rate)
                    .minor);
    return _ReportCard(
      title: 'Family progress',
      icon: Icons.flag_outlined,
      child: Column(children: [
        _ProgressRow(
          label: 'Savings goals',
          value: Money(goalSaved, displayCurrency),
          target: Money(goalTarget, displayCurrency),
        ),
        const SizedBox(height: 14),
        _ProgressRow(
          label: 'Contributions collected',
          value: Money(campaignCollected, displayCurrency),
          target: Money(campaignTarget, displayCurrency),
        ),
      ]),
    );
  }
}

class _MonthEndSummaryCard extends StatelessWidget {
  const _MonthEndSummaryCard({
    required this.income,
    required this.spent,
    required this.saved,
    required this.plan,
  });
  final Money income;
  final Money spent;
  final Money saved;
  final BudgetCyclePlan? plan;

  @override
  Widget build(BuildContext context) {
    final result =
        Money(income.minor - spent.minor - saved.minor, income.currency);
    final positive = result.minor >= 0;
    final resultText = positive
        ? '${result.text} left after spending and saving.'
        : 'Spending and saving exceeded income by ${Money(-result.minor, result.currency).text}.';
    return _ReportCard(
      title: 'Month-end summary',
      icon: Icons.event_available_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(resultText,
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: positive ? context.incomeGreen : context.expenseRed)),
        const SizedBox(height: 7),
        Text('The family saved ${saved.text} during this cycle.'),
        const SizedBox(height: 7),
        Text(
          plan == null
              ? 'No agreed plan was saved for this cycle.'
              : plan!.isClosed
                  ? 'This month has been closed and preserved for comparison.'
                  : 'This month is still open. Close it from Budgets when the family has reviewed the figures.',
          style: TextStyle(color: context.inkSoft),
        ),
      ]),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow(
      {required this.label, required this.value, required this.target});
  final String label;
  final Money value;
  final Money target;

  @override
  Widget build(BuildContext context) {
    final ratio = target.minor <= 0 ? 0.0 : value.minor / target.minor;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w700))),
        Text('${value.text} / ${target.text}',
            style: TextStyle(fontSize: 11.5, color: context.inkSoft)),
      ]),
      const SizedBox(height: 7),
      ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          value: ratio.clamp(0, 1),
          minHeight: 8,
          backgroundColor: context.track,
          color: context.primary,
        ),
      ),
    ]);
  }
}

class _CommitmentsCard extends StatelessWidget {
  const _CommitmentsCard({
    required this.state,
    required this.transactions,
    required this.displayCurrency,
  });
  final AppState state;
  final List<Tx> transactions;
  final Currency displayCurrency;

  @override
  Widget build(BuildContext context) {
    final today = DateTime(state.now.year, state.now.month, state.now.day);
    final overdue = state.recurring
        .where((rule) =>
            rule.active &&
            DateTime(rule.nextDue.year, rule.nextDue.month, rule.nextDue.day)
                .isBefore(today))
        .length;
    final upcoming = state.recurring
        .where((rule) =>
            rule.active &&
            !DateTime(rule.nextDue.year, rule.nextDue.month, rule.nextDue.day)
                .isBefore(today))
        .length;
    final paid = transactions
        .where((tx) => tx.recurringRuleId != null && tx.type == TxType.expense)
        .length;
    final debtRemaining = state.familyDebts.fold<int>(
        0,
        (sum, debt) =>
            sum +
            state
                .remainingOnDebt(debt)
                .inCurrency(displayCurrency, state.rate)
                .minor);
    return _ReportCard(
      title: 'Bills and debts',
      icon: Icons.receipt_long_outlined,
      child: Column(children: [
        _SummaryLine(label: 'Bills paid in this period', value: '$paid'),
        _SummaryLine(label: 'Upcoming bills', value: '$upcoming'),
        _SummaryLine(
          label: 'Overdue bills',
          value: '$overdue',
          danger: overdue > 0,
        ),
        _SummaryLine(
          label: 'Debt still outstanding',
          value: Money(debtRemaining, displayCurrency).text,
        ),
      ]),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine(
      {required this.label, required this.value, this.danger = false});
  final String label;
  final String value;
  final bool danger;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(
              child: Text(label, style: TextStyle(color: context.inkSoft))),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: danger ? context.expenseRed : context.ink)),
        ]),
      );
}

class _ReportCard extends StatelessWidget {
  const _ReportCard(
      {required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 20, color: context.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: context.ink)),
            ),
          ]),
          const SizedBox(height: 14),
          DefaultTextStyle(
            style: TextStyle(fontSize: 12.5, color: context.ink, height: 1.35),
            child: child,
          ),
        ]),
      );
}

/// ── G4: interactive spend donut ─────────────────────────────────────────────
class _WhereItWent extends StatefulWidget {
  final AppState state;
  final Map<String, int> spentUsdByEnvelope;

  const _WhereItWent({
    required this.state,
    required this.spentUsdByEnvelope,
  });

  @override
  State<_WhereItWent> createState() => _WhereItWentState();
}

class _WhereItWentState extends State<_WhereItWent> {
  int _sel = 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final palette = [
      context.primary,
      context.accent,
      context.incomeGreen,
      context.expenseRed,
      context.primaryDark,
      const Color(0xFF7EC8F2),
      const Color(0xFFFF6B6B),
    ];

    final spent = <MapEntry<String, (double, Color)>>[
      for (var i = 0; i < s.envelopes.length; i++)
        if (!s.envelopes[i].isPersonal &&
            (widget.spentUsdByEnvelope[s.envelopes[i].id] ?? 0) > 0)
          MapEntry(
            s.envelopes[i].name,
            (
              (widget.spentUsdByEnvelope[s.envelopes[i].id] ?? 0) / 100.0,
              palette[i % palette.length],
            ),
          ),
    ]..sort((a, b) => b.value.$1.compareTo(a.value.$1));

    if (spent.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          AppLocalizations.of(context)!.donutEmpty,
          style: TextStyle(fontSize: 12.5, color: context.inkSoft, height: 1.4),
        ),
      );
    }

    // Top 6 slices, rest folded into "Other".
    var rows = spent.take(6).toList();
    final restTotal = spent.skip(6).fold<double>(0, (a, e) => a + e.value.$1);
    if (restTotal > 0) {
      rows = [
        ...rows,
        MapEntry('Other', (restTotal, context.track)),
      ];
    }
    final total = rows.fold<double>(0, (a, e) => a + e.value.$1);
    if (_sel >= rows.length) _sel = 0;

    final selName = rows[_sel].key;
    final selAmount = rows[_sel].value.$1;
    final selShare = total > 0 ? (selAmount / total * 100).round() : 0;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Semantics(
              label: AppLocalizations.of(context)!.donutA11y(selName, selShare),
              child: DonutChart(
                segments: [
                  for (final r in rows) (r.key, r.value.$1, r.value.$2),
                ],
                selected: _sel,
                onTap: (i) => setState(() => _sel = i),
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selName,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$selShare%',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: context.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _sel = i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: rows[i].value.$2,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                rows[i].key,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: i == _sel
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: context.ink,
                                ),
                              ),
                            ),
                            Text(
                              '${(rows[i].value.$1 / total * 100).round()}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: context.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// ── G4: six-month net trend ─────────────────────────────────────────────────
class _TrendCard extends StatelessWidget {
  final AppState state;

  const _TrendCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final s = state;
    final now = DateTime.now();
    final firstMonth = DateTime(now.year, now.month - 5, 1);
    final afterLastMonth = DateTime(now.year, now.month + 1, 1);
    final totals = <int, double>{};
    for (final tx in s.txs) {
      if (tx.when.isBefore(firstMonth) || !tx.when.isBefore(afterLastMonth)) {
        continue;
      }
      final key = tx.when.year * 12 + tx.when.month;
      final amt = tx.amount.inCurrency(s.displayCurrency, s.rate).minor / 100.0;
      totals.update(
        key,
        (value) => value + (tx.type == TxType.income ? amt : -amt),
        ifAbsent: () => tx.type == TxType.income ? amt : -amt,
      );
    }
    final bars = <(String, double)>[];
    for (var i = 5; i >= 0; i--) {
      final start = DateTime(now.year, now.month - i, 1);
      final key = start.year * 12 + start.month;
      bars.add((DateFormat('MMM').format(start), totals[key] ?? 0));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.sixMonthNet,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: context.ink,
          ),
        ),
        const SizedBox(height: 10),
        TrendBars(
          bars: bars,
          positive: context.incomeGreen,
          negative: context.expenseRed,
          track: context.track,
          labelColor: context.inkSoft,
        ),
      ],
    );
  }
}

/// ── Shopping & List Tracking in Reports ─────────────────────────────────────
class _ShoppingTrackingCard extends StatelessWidget {
  final AppState state;
  final List<Tx> transactions;
  final Currency displayCurrency;
  final Map<String, Envelope> envelopeById;

  const _ShoppingTrackingCard({
    required this.state,
    required this.transactions,
    required this.displayCurrency,
    required this.envelopeById,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Identify shopping/grocery transactions in the selected period
    final shoppingTxs = transactions.where((tx) {
      if (tx.type != TxType.expense) return false;
      final env = envelopeById[tx.envelopeId];
      final isGroceries =
          env != null && env.name.toLowerCase().contains('grocer');
      final note = tx.note.toLowerCase();
      final isShoppingNote = note.contains('grocer') ||
          note.contains('shop') ||
          note.contains('freshmart') ||
          note.contains('market') ||
          note.contains('supermarket');
      return isGroceries || isShoppingNote;
    }).toList();

    final shoppingSpentMinor = shoppingTxs.fold<int>(
      0,
      (sum, tx) =>
          sum + tx.amount.inCurrency(displayCurrency, state.rate).minor,
    );
    final shoppingSpent = Money(shoppingSpentMinor, displayCurrency);

    // 2. Shopping list items tracking
    final totalItems = state.items.length;
    final doneItems =
        state.items.where((i) => i.state == ItemState.done).toList();
    final toBuyItems =
        state.items.where((i) => i.state == ItemState.tobuy).toList();
    final inCartItems =
        state.items.where((i) => i.state == ItemState.incart).toList();
    final estNeeded = state.estFor(displayCurrency);

    final completionRatio =
        totalItems == 0 ? 0.0 : doneItems.length / totalItems;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shopping_cart_outlined,
                  size: 20, color: context.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Shopping & Lists Tracking',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: context.ink,
                  ),
                ),
              ),
              if (totalItems > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.primarySoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${doneItems.length}/$totalItems bought',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: context.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Two-column stat grid
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.track,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Period grocery spend',
                        style:
                            TextStyle(fontSize: 11.5, color: context.inkSoft),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          shoppingSpent.text,
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: context.ink,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${shoppingTxs.length} shopping trip${shoppingTxs.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: context.inkSoft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.track,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Est. items to buy',
                        style:
                            TextStyle(fontSize: 11.5, color: context.inkSoft),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          estNeeded.text,
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: context.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${toBuyItems.length + inCartItems.length} item${(toBuyItems.length + inCartItems.length) == 1 ? '' : 's'} remaining',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: context.inkSoft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Completion progress bar
          if (totalItems > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: completionRatio,
                minHeight: 6,
                backgroundColor: context.track,
                color: context.primary,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Preview of items
          if (state.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'No shopping items on the list yet. Items added by family members will be tracked here.',
                style: TextStyle(
                    fontSize: 12, color: context.inkSoft, height: 1.4),
              ),
            )
          else ...[
            Text(
              'Tracked items',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: context.inkSoft,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in state.items.take(8))
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.state == ItemState.done
                          ? context.successSoft
                          : context.track,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.state == ItemState.done
                              ? Icons.check_circle_outline
                              : Icons.radio_button_unchecked,
                          size: 13,
                          color: item.state == ItemState.done
                              ? context.primaryDark
                              : context.inkSoft,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${item.name} (${item.qty})',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: item.state == ItemState.done
                                ? context.primaryDark
                                : context.ink,
                            decoration: item.state == ItemState.done
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (state.items.length > 8)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.track,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+${state.items.length - 8} more',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: context.inkSoft,
                      ),
                    ),
                  ),
              ],
            ),
          ],

          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const ListsScreen(standalone: true)),
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('View full shopping list'),
              style: TextButton.styleFrom(
                foregroundColor: context.primary,
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
