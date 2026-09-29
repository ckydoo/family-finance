import 'package:flutter/material.dart';

import '../../core/notifications/reminders.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../l10n/generated/app_localizations.dart';

/// Home bell (§7.5) → what will actually notify on this device.
void showRemindersSheet(BuildContext context) {
  showMhuriSheet<void>(
    context: context,
    builder: (context) => const _RemindersSheet(),
  );
}

class _RemindersSheet extends StatelessWidget {
  const _RemindersSheet();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final plan = s.planReminders();
    final l10n = AppLocalizations.of(context)!;
    final subtitle = s.notifyEnabled
        ? l10n.scheduledOn(_hh(s.quietStart), _hh(s.quietEnd))
        : l10n.remindersOff;

    return MhuriSheetShell(
      title: l10n.remindersTitle,
      subtitle: subtitle,
      child: !s.notifyEnabled
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  l10n.remindersOff,
                  style: TextStyle(color: context.inkSoft),
                ),
              ),
            )
          : plan.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      l10n.nothingComing,
                      style: TextStyle(color: context.inkSoft),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
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
