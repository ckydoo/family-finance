import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/notifications/notifier.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/notifications/reminders.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';

/// Settings (spec §7 Settings: notifications J3, month start, data).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return AnimatedBuilder(
      animation: s,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: context.bg,
          appBar: AppBar(
            title: Text(AppLocalizations.of(context)!.settingsTitle),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              _header(context, Icons.notifications_outlined,
                  AppLocalizations.of(context)!.remindersTitle),
              SwitchListTile(
                value: s.notifyEnabled,
                onChanged: (v) => s.setRemindersEnabled(v),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  AppLocalizations.of(context)!.remindersOnDevice,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: context.ink,
                  ),
                ),
                subtitle: Text(
                  AppLocalizations.of(context)!.remindersSubtitle,
                  style: TextStyle(fontSize: 12, color: context.inkSoft),
                ),
              ),
              if (s.notifyEnabled)
                for (final c in ReminderCategory.values)
                  SwitchListTile(
                    value: s.notifyAllowed.contains(c),
                    onChanged: (v) => s.setReminderPref(c, v),
                    dense: true,
                    contentPadding: const EdgeInsets.only(left: 8),
                    title: Text(
                      c.label,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.ink,
                      ),
                    ),
                  ),
              if (s.notifyEnabled) ...[
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.quietHours,
                  style: TextStyle(fontSize: 12, color: context.inkSoft),
                ),
                Row(
                  children: [
                    Text(AppLocalizations.of(context)!.fromLabel,
                        style: const TextStyle(fontSize: 13)),
                    _hourDropdown(
                      value: s.quietStart,
                      onChanged: (v) => s.setQuietHours(v, s.quietEnd),
                    ),
                    const SizedBox(width: 24),
                    const Text('to  ', style: TextStyle(fontSize: 13)),
                    _hourDropdown(
                      value: s.quietEnd,
                      onChanged: (v) => s.setQuietHours(s.quietStart, v),
                    ),
                  ],
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.science, size: 20),
                  title: Text(
                    AppLocalizations.of(context)!.sendTest,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.ink,
                    ),
                  ),
                  onTap: () {
                    final l = AppLocalizations.of(context)!;
                    Notifier.requestPermission().then(
                      (_) => Notifier.showNow(
                        Reminder(
                          key: 'test_now',
                          category: ReminderCategory.digest,
                          title: l.sendTest,
                          body: l.testOk,
                          when: DateTime.now(),
                        ),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 8),
              _header(context, Icons.calendar_month_outlined,
                  AppLocalizations.of(context)!.monthCycle),
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  AppLocalizations.of(context)!.monthStartsOn,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.ink,
                  ),
                ),
                subtitle: Text(
                  AppLocalizations.of(context)!.paydayAlign,
                  style: TextStyle(fontSize: 12, color: context.inkSoft),
                ),
                trailing: DropdownButton<int>(
                  value: s.monthStartDay,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (var d = 1; d <= 28; d++)
                      DropdownMenuItem(value: d, child: Text('Day $d')),
                  ],
                  onChanged: (v) {
                    if (v != null) s.setMonthStartDay(v);
                  },
                ),
              ),
              const SizedBox(height: 8),
              _header(context, Icons.folder_outlined, 'Data'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.receipt_long, size: 20),
                title: Text(
                  AppLocalizations.of(context)!.exportCsvSettings,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.ink,
                  ),
                ),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final l = AppLocalizations.of(context)!;
                  final path = await s.exportCsv();
                  if (!context.mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        path != null ? l.exportedPath(path) : l.exportReal,
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.language, size: 20),
                title: Text(
                  AppLocalizations.of(context)!.language,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.ink,
                  ),
                ),
                trailing: DropdownButton<String>(
                  value: kLanguageNames.containsKey(s.localeCode)
                      ? s.localeCode
                      : 'en',
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final e in kLanguageNames.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) {
                    if (v != null) s.setLocale(v);
                  },
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.dark_mode_outlined, size: 20),
                title: Text(AppLocalizations.of(context)!.themeLabel),
                trailing: DropdownButton<int>(
                  value: s.themeMode,
                  underline: const SizedBox.shrink(),
                  items: [
                    DropdownMenuItem(
                        value: 0,
                        child: Text(AppLocalizations.of(context)!.themeSystem)),
                    DropdownMenuItem(
                        value: 1,
                        child: Text(AppLocalizations.of(context)!.themeLight)),
                    DropdownMenuItem(
                        value: 2,
                        child: Text(AppLocalizations.of(context)!.themeDark)),
                  ],
                  onChanged: (v) {
                    if (v != null) s.setThemeMode(v);
                  },
                ),
              ),
              SwitchListTile(
                value: s.largeText,
                onChanged: (v) => s.setLargeText(v),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  AppLocalizations.of(context)!.largeText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.ink,
                  ),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                enabled: false,
                leading: Icon(Icons.cloud_outlined, size: 20),
                title: Text(
                  AppLocalizations.of(context)!.backupComing,
                  style: TextStyle(fontSize: 13, color: context.inkSoft),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: Row(
          children: [
            Icon(icon, size: 15, color: context.primaryDark),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: context.inkSoft,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      );

  Widget _hourDropdown(
          {required int value, required ValueChanged<int> onChanged}) =>
      DropdownButton<int>(
        value: value,
        underline: const SizedBox.shrink(),
        items: [
          for (var h = 0; h < 24; h++)
            DropdownMenuItem(
              value: h,
              child: Text('${h.toString().padLeft(2, '0')}:00'),
            ),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      );
}
