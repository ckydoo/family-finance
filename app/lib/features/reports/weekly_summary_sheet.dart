import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/models.dart';
import '../../core/money/money.dart';
import '../../core/observability/reporter.dart';
import '../../core/planning/weekly_summary.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ids.dart';
import '../../core/widgets/ui.dart';

Future<void> showWeeklySummarySheet(BuildContext context) {
  final s = AppScope.of(context);
  mhuriEvent(
    MhuriAnalyticsEvents.weeklySummaryViewed,
    {
      'has_activity': s.weeklySummary.hasActivity,
      'role': s.authRole.name,
      'locale': s.localeCode,
    },
  );
  return showMhuriSheet<void>(
    context: context,
    builder: (_) => const MhuriSheetShell(
      title: 'Weekly Mhuri summary',
      subtitle: 'Last 7 days · household snapshot',
      child: _WeeklySummarySheetBody(),
    ),
  );
}

class WeeklySummaryPreviewCard extends StatelessWidget {
  final VoidCallback? onTap;

  const WeeklySummaryPreviewCard({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final summary = s.weeklySummary;
    if (!summary.hasActivity) return const SizedBox.shrink();

    String fmt(Money m) =>
        s.hideAmounts ? '${m.currency.symbol} ••••' : m.text;

    return Semantics(
      button: true,
      label: 'Weekly Mhuri summary',
      child: Material(
        color: context.card,
        borderRadius: kBRadiusL,
        child: InkWell(
          key: const ValueKey('weekly_summary_card'),
          borderRadius: kBRadiusL,
          onTap: onTap ?? () => showWeeklySummarySheet(context),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: kBRadiusL,
              border: Border.all(color: context.hairline),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: context.primarySoft,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    Icons.insights_rounded,
                    size: 20,
                    color: context.primaryDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Weekly Mhuri summary',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: context.ink,
                              ),
                            ),
                          ),
                          Text(
                            fmt(summary.totalSpent),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.primaryDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        summary.supportiveHeadline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.inkSoft,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, color: context.inkSoft),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeeklySummarySheetBody extends StatelessWidget {
  const _WeeklySummarySheetBody();

  Future<void> _confirmAndShare(
    BuildContext context,
    AppState s,
    WeeklyFamilySummary summary,
  ) async {
    var maskAmounts = s.hideAmounts;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) {
          final preview = summary.formatShareText(
            familyName: s.space.name,
            maskAmounts: maskAmounts,
          );
          return AlertDialog(
            title: const Text('Share weekly summary?'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Private accounts are excluded. Review what will be shared:',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: dialogContext.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: dialogContext.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: dialogContext.hairline),
                    ),
                    child: Text(
                      preview,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: dialogContext.ink,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    key: const ValueKey('weekly_summary_mask_amounts_toggle'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: maskAmounts,
                    onChanged: (v) => setDialog(() => maskAmounts = v ?? false),
                    title: const Text('Hide exact currency amounts'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const ValueKey('weekly_summary_confirm_share'),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Confirm & share'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final text = summary.formatShareText(
      familyName: s.space.name,
      maskAmounts: maskAmounts,
    );
    await Clipboard.setData(ClipboardData(text: text));
    s.addChatMessage(
      FamilyChatMessage(
        id: newUuid(),
        familyId: s.sync?.spaceId ?? s.space.name,
        senderId: s.realUser.id,
        senderName: s.realUser.name,
        text: text,
        createdAt: s.now,
        status: ChatMessageStatus.sent,
      ),
    );
    mhuriEvent(
      MhuriAnalyticsEvents.weeklySummaryShared,
      {
        'masked': maskAmounts,
        'role': s.authRole.name,
        'locale': s.localeCode,
      },
    );
    if (!context.mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Weekly summary copied and ready to share.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final summary = s.weeklySummary;
    String fmt(Money m) =>
        s.hideAmounts ? '${m.currency.symbol} ••••' : m.text;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.primarySoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                summary.supportiveHeadline,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.primaryDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                summary.supportiveNextStep,
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.ink,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Spent (7 days)',
                value: fmt(summary.totalSpent),
                caption:
                    '${summary.expenseCount} ${summary.expenseCount == 1 ? 'expense' : 'expenses'}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(
                label: 'Income (7 days)',
                value: fmt(summary.totalIncome),
                caption:
                    '${summary.incomeCount} ${summary.incomeCount == 1 ? 'entry' : 'entries'}',
              ),
            ),
          ],
        ),
        if (summary.budgetHighlight != null) ...[
          const SizedBox(height: 10),
          Builder(
            builder: (context) {
              final b = summary.budgetHighlight!;
              final statusText = b.effectiveLimit.minor <= 0
                  ? '${fmt(b.spentThisWeek)} spent this week'
                  : b.isOverBudget
                      ? '${fmt(Money(b.remainingThisCycle.minor.abs(), b.remainingThisCycle.currency))} over plan this cycle'
                      : '${fmt(b.remainingThisCycle)} left this cycle';
              return _MetricTile(
                label: 'Focus budget · ${b.envelope.name}',
                value: statusText,
                caption:
                    '${fmt(b.spentThisWeek)} spent in the last 7 days',
              );
            },
          ),
        ],
        if (summary.savedThisWeek.minor > 0 ||
            summary.debtRepaidThisWeek.minor > 0) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              if (summary.savedThisWeek.minor > 0)
                Expanded(
                  child: _MetricTile(
                    label: 'Saved this week',
                    value: fmt(summary.savedThisWeek),
                    caption: 'Added to family goals',
                  ),
                ),
              if (summary.savedThisWeek.minor > 0 &&
                  summary.debtRepaidThisWeek.minor > 0)
                const SizedBox(width: 10),
              if (summary.debtRepaidThisWeek.minor > 0)
                Expanded(
                  child: _MetricTile(
                    label: 'Debt repaid',
                    value: fmt(summary.debtRepaidThisWeek),
                    caption: 'Recorded this week',
                  ),
                ),
            ],
          ),
        ],
        if (summary.upcomingBillsCount > 0 || summary.openTasksCount > 0) ...[
          const SizedBox(height: 10),
          _MetricTile(
            label: 'Coming up next',
            value: summary.upcomingBillsCount > 0
                ? '${summary.upcomingBillsCount} upcoming ${summary.upcomingBillsCount == 1 ? 'bill' : 'bills'}${summary.nextBillTitle != null ? ' · Next: ${summary.nextBillTitle}' : ''}'
                : '${summary.openTasksCount} open family ${summary.openTasksCount == 1 ? 'task' : 'tasks'}',
            caption: summary.openTasksCount > 0 && summary.upcomingBillsCount > 0
                ? '${summary.openTasksCount} open family ${summary.openTasksCount == 1 ? 'task' : 'tasks'}'
                : 'Next 7 days',
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('weekly_summary_share_button'),
            onPressed: () => _confirmAndShare(context, s, summary),
            icon: const Icon(Icons.ios_share_rounded, size: 18),
            label: const Text('Share summary'),
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String caption;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: context.inkSoft,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: context.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: TextStyle(
              fontSize: 11.5,
              color: context.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}
