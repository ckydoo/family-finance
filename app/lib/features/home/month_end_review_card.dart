import 'package:flutter/material.dart';

import '../../core/money/money.dart';
import '../../core/planning/month_end_review.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../l10n/generated/app_localizations.dart';

/// Month-end review (9.6).
///
/// Last month's unspent money is never swept silently: Home asks once per
/// closed cycle and the family decides whether to move it into savings or
/// leave it in the budget. Envelopes set to roll over or accumulate are shown
/// for context only - their money is already promised to next month.
class MonthEndReviewCard extends StatelessWidget {
  const MonthEndReviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final l = AppLocalizations.of(context)!;

    if (s.monthEndReviewDue) {
      final review = s.monthEndReview!;
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: _Panel(
          icon: Icons.savings_outlined,
          title: l.monthEndReviewTitle,
          body: l.monthEndReviewBody(review.totalLeft.text),
          action: Row(
            children: [
              FilledButton(
                onPressed: () => showMonthEndReviewSheet(context),
                child: Text(l.monthEndReviewCta),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: s.markMonthEndReviewed,
                child: Text(l.monthEndReviewLater),
              ),
            ],
          ),
        ),
      );
    }

    // Quiet receipt for an automatic sweep, so "always" is still visible.
    final swept = s.lastMonthEndSweep;
    if (swept != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: _Panel(
          icon: Icons.check_circle_outline,
          title: l.monthEndReviewTitle,
          body: l.monthEndSweptAutomatically(swept.text),
          action: Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: s.clearLastMonthEndSweep,
              child: Text(l.done),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget action;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: BoxDecoration(
          color: context.primarySoft,
          borderRadius: kBRadiusM,
          border: Border.all(color: context.primary.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: context.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: context.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        body,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: context.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            action,
          ],
        ),
      );
}

/// Review sheet: pick which envelopes give up their leftovers and which goal
/// receives them. Nothing moves until the primary button is pressed.
Future<void> showMonthEndReviewSheet(BuildContext context) async {
  final s = AppScope.of(context);
  final l = AppLocalizations.of(context)!;
  final review = s.monthEndReview;
  if (review == null) return;
  final goals = s.monthEndSweepGoals;
  final lines = review.sweepable.toList(growable: false);

  final selected = <String>{for (final line in lines) line.envelopeId};
  String? goalId = s.preferredMonthEndGoal?.id ??
      (goals.isEmpty ? null : goals.first.id);
  var busy = false;

  Money selectedTotal() {
    var sum = 0;
    for (final line in lines) {
      if (!selected.contains(line.envelopeId)) continue;
      sum += line.remaining.inCurrency(s.displayCurrency, s.rate).minor;
    }
    return Money(sum, s.displayCurrency);
  }

  await showMhuriSheet<void>(
    context: context,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (sheetCtx, setSheet) {
        final goal = goalId == null
            ? null
            : goals.where((g) => g.id == goalId).firstOrNull;
        final total = selectedTotal();
        final canMove = !busy && goal != null && total.minor > 0;

        return MhuriSheetShell(
          title: l.monthEndReviewSheetTitle,
          subtitle: l.monthEndReviewSheetBody(review.totalLeft.text),
          onClose: () => Navigator.pop(sheetCtx),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _LineRow(
                    line: line,
                    selected: selected.contains(line.envelopeId),
                    onChanged: (on) => setSheet(() {
                      if (on) {
                        selected.add(line.envelopeId);
                      } else {
                        selected.remove(line.envelopeId);
                      }
                    }),
                  ),
                ),
              if (review.carried.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  l.monthEndReviewCarryNote,
                  style: TextStyle(fontSize: 11.5, color: context.inkFaint),
                ),
              ],
              const SizedBox(height: 16),
              if (goal == null)
                ErrorNotice(l.monthEndReviewNoGoals)
              else ...[
                Text(
                  l.monthEndReviewSendTo,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.inkSoft,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: goalId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: context.card,
                    border:
                        const OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                  items: [
                    for (final g in goals)
                      DropdownMenuItem(
                        value: g.id,
                        child: Text('${g.emoji}  ${g.name}'),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setSheet(() => goalId = value);
                  },
                ),
              ],
              const SizedBox(height: 18),
              PrimaryButton(
                label: goal == null
                    ? l.monthEndReviewKeep
                    : l.monthEndReviewMove(total.text, goal.name),
                busy: busy,
                onPressed: !canMove
                    ? null
                    : () {
                        setSheet(() => busy = true);
                        final moved = s.sweepMonthEndToGoal(
                          goal,
                          envelopeIds: selected,
                        );
                        if (!sheetCtx.mounted) return;
                        Navigator.pop(sheetCtx);
                        if (moved != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                l.monthEndReviewDone(moved.text, goal.name),
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: () {
                    s.markMonthEndReviewed();
                    Navigator.pop(sheetCtx);
                  },
                  child: Text(l.monthEndReviewKeep),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: () {
                    s.setMonthEndSweepMode(MonthEndSweepMode.never);
                    Navigator.pop(sheetCtx);
                  },
                  child: Text(
                    l.monthEndReviewDontAsk,
                    style: TextStyle(fontSize: 12, color: context.inkFaint),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.line,
    required this.selected,
    required this.onChanged,
  });

  final MonthEndLine line;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Material(
        color: context.card,
        borderRadius: kBRadiusM,
        child: InkWell(
          borderRadius: kBRadiusM,
          onTap: () => onChanged(!selected),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
              Expanded(
                child: Text(
                  '${line.emoji}  ${line.name}',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.ink,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                line.remaining.text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.primary,
                ),
              ),
              const SizedBox(width: 4),
              Switch(
                value: selected,
                onChanged: onChanged,
              ),
              ],
            ),
          ),
        ),
      );
}
