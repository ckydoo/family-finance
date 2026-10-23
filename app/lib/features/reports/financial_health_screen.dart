import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/money/money.dart';
import '../../core/planning/financial_health.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';

class FinancialHealthScreen extends StatelessWidget {
  const FinancialHealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final start = state.cycleStart;
    final end = state.nextCycleStart;
    final review = const FinancialHealthEngine().review(
      currency: state.displayCurrency,
      periodStart: start,
      periodEnd: end,
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
    final hasRecordedData = state.txs.any((value) =>
        value.amount.currency == review.currency &&
        !value.when.isBefore(start) &&
        value.when.isBefore(end));
    return Scaffold(
      appBar: AppBar(title: const Text('Financial health check')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${DateFormat.yMMMd().format(start)} – ${DateFormat.yMMMd().format(end.subtract(const Duration(days: 1)))}',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            '${review.currency.short} only · recorded evidence, not financial advice',
            style: TextStyle(color: context.inkSoft),
          ),
          if (!hasRecordedData)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No same-currency transactions are recorded for this period. The review shows zeroes and explicitly available planning records only.',
                    style: TextStyle(color: context.inkSoft),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          for (final insight in review.insights)
            Card(
              child: ExpansionTile(
                leading: Icon(_icon(insight.kind), color: context.primary),
                title: Text(insight.title),
                subtitle: Text(insight.detail),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Calculation',
                      style: Theme.of(context).textTheme.labelLarge),
                  Text(insight.calculation),
                  const SizedBox(height: 10),
                  Text('Source records (${insight.sourceIds.length})',
                      style: Theme.of(context).textTheme.labelLarge),
                  SelectableText(insight.sourceIds.isEmpty
                      ? 'No qualifying source records.'
                      : insight.sourceIds
                          .map((id) => _describeSource(state, id))
                          .join('\n')),
                  const SizedBox(height: 10),
                  Text('Limitations',
                      style: Theme.of(context).textTheme.labelLarge),
                  for (final limitation in insight.limitations)
                    Text('• $limitation'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _describeSource(AppState state, String id) {
    for (final tx in state.txs) {
      if (tx.id == id) {
        final label = tx.note.isEmpty ? tx.type.name : tx.note;
        return '$label · ${tx.amount.text} ($id)';
      }
    }
    for (final env in state.envelopes) {
      if (env.id == id) {
        return 'Budget: ${env.name} · ${env.limit.text} ($id)';
      }
    }
    for (final occ in state.commitmentOccurrences) {
      if (occ.id == id) {
        return 'Commitment due ${occ.occurrenceKey} · ${occ.amount.text} ($id)';
      }
    }
    for (final goal in state.goals) {
      if (goal.id == id) {
        return 'Goal: ${goal.name} · ${goal.target.text} ($id)';
      }
    }
    for (final debt in state.familyDebts) {
      if (debt.id == id) {
        return 'Debt: ${debt.name} · ${debt.principal.text} ($id)';
      }
    }
    return id;
  }

  IconData _icon(HealthInsightKind kind) => switch (kind) {
        HealthInsightKind.incomeVsExpenses => Icons.balance_outlined,
        HealthInsightKind.budgetVsActual => Icons.pie_chart_outline,
        HealthInsightKind.spendingChange => Icons.trending_up,
        HealthInsightKind.upcomingCommitments => Icons.event_repeat_outlined,
        HealthInsightKind.savingsProgress => Icons.savings_outlined,
        HealthInsightKind.debtProgress => Icons.account_balance_outlined,
        HealthInsightKind.suggestedAction => Icons.lightbulb_outline,
      };
}
