import 'package:flutter/material.dart';

import '../../core/notifications/reminders.dart';
import '../../core/state/app_state.dart';
import '../../core/widgets/app_icons.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';

/// Home bell (§7.5) → what will actually notify on this device.
void showRemindersSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const _RemindersSheet(),
  );
}

class _RemindersSheet extends StatelessWidget {
  const _RemindersSheet();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final plan = s.planReminders();
    return Container(
      constraints: const BoxConstraints(maxHeight: 520),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.inkSoft.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              AppLocalizations.of(context)!.remindersTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              s.notifyEnabled
                  ? AppLocalizations.of(context)!
                      .scheduledOn(_hh(s.quietStart), _hh(s.quietEnd))
                  : AppLocalizations.of(context)!.remindersOff,
              style: TextStyle(fontSize: 12, color: context.inkSoft),
            ),
            const SizedBox(height: 12),
            if (!s.notifyEnabled)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    AppLocalizations.of(context)!.remindersOff,
                    style: TextStyle(color: context.inkSoft),
                  ),
                ),
              )
            else if (plan.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    AppLocalizations.of(context)!.nothingComing,
                    style: TextStyle(color: context.inkSoft),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: plan.length,
                  itemBuilder: (context, i) {
                    final r = plan[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(
                        _icon(r.category),
                        size: 22,
                        color: context.primaryDark,
                      ),
                      title: Text(
                        r.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: context.ink,
                        ),
                      ),
                      subtitle: Text(
                        r.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: context.inkSoft),
                      ),
                      trailing: Text(
                        _when(r.when, r.weekly),
                        style: TextStyle(fontSize: 11, color: context.inkSoft),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _hh(int h) => '${h.toString().padLeft(2, '0')}:00';

IconData _icon(ReminderCategory c) => switch (c) {
      ReminderCategory.bills => Icons.push_pin,
      ReminderCategory.budget => Icons.account_balance_wallet,
      ReminderCategory.kids => Icons.child_care,
      ReminderCategory.circle => Icons.autorenew,
      ReminderCategory.goals => Icons.track_changes,
      ReminderCategory.meeting => Icons.groups,
      ReminderCategory.digest => Icons.bar_chart,
    };

String _when(DateTime t, bool weekly) {
  if (weekly) return 'weekly';
  final diff = t.difference(DateTime.now());
  if (diff.inDays >= 1) return 'in ${diff.inDays}d';
  if (diff.inHours >= 1) return 'in ${diff.inHours}h';
  return 'soon';
}
