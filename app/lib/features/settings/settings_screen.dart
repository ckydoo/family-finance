import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/notifications/notifier.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/notifications/reminders.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../instructions/instructions_screen.dart';
import '../legal/legal_screen.dart';
import 'sync_screen.dart';
import '../../core/widgets/ui.dart';

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
          body: SafeArea(
            top: false,
            child: ListView(
              padding: kPageInsets,
              children: [
                if (s.auth?.isLoggedIn ?? false) ...[
                  _header(context, Icons.account_circle_outlined,
                      AppLocalizations.of(context)!.accountTitle),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: context.primarySoft,
                      child: Icon(Icons.person_outline, color: context.primary),
                    ),
                    title: Text(
                      s.user.name,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: context.ink,
                      ),
                    ),
                    subtitle: Text(
                      'Profile',
                      style: TextStyle(fontSize: 12, color: context.inkSoft),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => _editProfile(context, s),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.alternate_email, size: 20),
                    title: Text(
                      'Signed in as',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.ink,
                      ),
                    ),
                    subtitle: Text(
                      s.auth?.session?.email ?? '',
                      style: TextStyle(fontSize: 12, color: context.inkSoft),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.logout, size: 20),
                    title: Text(
                      AppLocalizations.of(context)!.signOut,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.ink,
                      ),
                    ),
                    onTap: s.auth!.busy ? null : () => _signOut(context, s),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline,
                        size: 20, color: context.danger),
                    title: Text(
                      AppLocalizations.of(context)!.deleteAccount,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.danger,
                      ),
                    ),
                    subtitle: Text(
                      'Permanently remove your account and access',
                      style: TextStyle(fontSize: 12, color: context.inkSoft),
                    ),
                    onTap:
                        s.auth!.busy ? null : () => _deleteAccount(context, s),
                  ),
                  const SizedBox(height: 16),
                ],
                _header(context, Icons.notifications_outlined,
                    AppLocalizations.of(context)!.remindersTitle),
                SwitchListTile.adaptive(
                  value: s.notifyEnabled,
                  onChanged: (v) async {
                    if (!v) {
                      s.setRemindersEnabled(false);
                      return;
                    }
                    final granted = await Notifier.requestPermission();
                    if (!context.mounted) return;
                    if (granted) {
                      s.setRemindersEnabled(true);
                    } else {
                      s.setRemindersEnabled(false);
                      _showMessage(
                        context,
                        AppLocalizations.of(context)!.notificationsDenied,
                      );
                    }
                  },
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
                    SwitchListTile.adaptive(
                      value: s.notifyAllowed.contains(c),
                      onChanged: (v) => s.setReminderPref(c, v),
                      dense: true,
                      contentPadding: const EdgeInsets.only(left: 8),
                      title: Text(
                        _categoryLabel(AppLocalizations.of(context)!, c),
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
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(AppLocalizations.of(context)!.fromLabel,
                          style: const TextStyle(fontSize: 13)),
                      _hourDropdown(
                        value: s.quietStart,
                        onChanged: (v) => s.setQuietHours(v, s.quietEnd),
                      ),
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
                    onTap: () async {
                      final l = AppLocalizations.of(context)!;
                      final granted = await Notifier.requestPermission();
                      if (!context.mounted) return;
                      if (!granted) {
                        _showMessage(context, l.notificationsDenied);
                        return;
                      }
                      final shown = await Notifier.showNow(
                        Reminder(
                          key: 'test_now',
                          category: ReminderCategory.digest,
                          title: l.sendTest,
                          body: l.testOk,
                          when: DateTime.now(),
                        ),
                      );
                      if (!context.mounted) return;
                      _showMessage(
                        context,
                        shown
                            ? l.testNotificationSent
                            : l.testNotificationFailed,
                      );
                    },
                  ),
                ],
                const SizedBox(height: 8),
                _header(context, Icons.savings_outlined,
                    AppLocalizations.of(context)!.savingsTitle),
                SwitchListTile.adaptive(
                  value: s.mukandoEnabled,
                  onChanged: (v) => s.setMukandoEnabled(v),
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.autorenew),
                  title: Text(
                    AppLocalizations.of(context)!.mukandoOn,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: context.ink,
                    ),
                  ),
                  subtitle: Text(
                    AppLocalizations.of(context)!.mukandoEnableSub,
                    style: TextStyle(fontSize: 12, color: context.inkSoft),
                  ),
                ),
                _header(context, Icons.calendar_month_outlined,
                    AppLocalizations.of(context)!.monthCycle),
                _adaptiveDropdownTile(
                  context,
                  title: AppLocalizations.of(context)!.monthStartsOn,
                  subtitle: AppLocalizations.of(context)!.paydayAlign,
                  dropdown: DropdownButton<int>(
                    isExpanded: true,
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
                _adaptiveDropdownTile(
                  context,
                  icon: Icons.language,
                  title: AppLocalizations.of(context)!.language,
                  dropdown: DropdownButton<String>(
                    isExpanded: true,
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
                _adaptiveDropdownTile(
                  context,
                  icon: Icons.dark_mode_outlined,
                  title: AppLocalizations.of(context)!.themeLabel,
                  dropdown: DropdownButton<int>(
                    isExpanded: true,
                    value: s.themeMode,
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(
                          value: 0,
                          child:
                              Text(AppLocalizations.of(context)!.themeSystem)),
                      DropdownMenuItem(
                          value: 1,
                          child:
                              Text(AppLocalizations.of(context)!.themeLight)),
                      DropdownMenuItem(
                          value: 2,
                          child: Text(AppLocalizations.of(context)!.themeDark)),
                    ],
                    onChanged: (v) {
                      if (v != null) s.setThemeMode(v);
                    },
                  ),
                ),
                SwitchListTile.adaptive(
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
                  leading: const Icon(Icons.cloud_sync_outlined, size: 20),
                  title: Text(
                    AppLocalizations.of(context)!.syncDataTitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.ink,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const SyncScreen(),
                    ));
                  },
                ),
                const SizedBox(height: 16),
                _header(context, Icons.help_outline_rounded, 'Help & Legal'),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.menu_book_outlined, size: 20),
                  title: Text(
                    'How Mhuri Works (User Guide)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.ink,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const InstructionsScreen(),
                    ));
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.privacy_tip_outlined, size: 20),
                  title: Text(
                    'Privacy Policy & Data Rights',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.ink,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const LegalScreen(
                          initialSection: LegalSection.privacy),
                    ));
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.description_outlined, size: 20),
                  title: Text(
                    'Terms of Service',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.ink,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) =>
                          const LegalScreen(initialSection: LegalSection.terms),
                    ));
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.gavel_outlined, size: 20),
                  title: Text(
                    'Financial Advice Disclaimer',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.ink,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const LegalScreen(
                          initialSection: LegalSection.disclaimer),
                    ));
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.verified_outlined, size: 20),
                  title: Text(
                    'Open Source Licenses',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.ink,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Mhuri',
                    applicationVersion: '1.0.0',
                    applicationLegalese: '© 2026 Mhuri. All rights reserved.\n'
                        'Built for African family financial collaboration.',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _editProfile(BuildContext context, AppState s) async {
    var displayName = s.user.name;
    await showMhuriSheet<void>(
      context: context,
      builder: (sheetContext) => MhuriSheetShell(
        title: AppLocalizations.of(context)!.editProfile,
        subtitle: 'Update the name shown to your family.',
        footer: PrimaryButton(
          label: AppLocalizations.of(context)!.save,
          onPressed: () {
            final name = displayName.trim();
            if (name.isEmpty) return;
            s.setMyName(name);
            Navigator.pop(sheetContext);
          },
        ),
        child: TextFormField(
          initialValue: displayName,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Display name'),
          onChanged: (value) => displayName = value,
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, AppState s) async {
    final auth = s.auth;
    if (auth == null) return;
    final confirmed = await confirmDialog(
      context,
      title: 'Sign out?',
      body: 'You can sign in again to return to your family space.',
      confirmLabel: AppLocalizations.of(context)!.signOut,
    );
    if (!confirmed || !context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    await auth.signOut();
  }

  Future<void> _deleteAccount(BuildContext context, AppState s) async {
    final auth = s.auth;
    if (auth == null) return;
    final l = AppLocalizations.of(context)!;

    if (s.canDeleteSpace && s.members.length > 1) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l.makeOwner),
          content: const Text(
            'Transfer ownership to another adult in Family before deleting '
            'your account, or remove the other family members first.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child:
                  Text(MaterialLocalizations.of(dialogContext).okButtonLabel),
            ),
          ],
        ),
      );
      return;
    }

    final typeController = TextEditingController();
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (dialogContext, setDialogState) => AlertDialog(
              title: Text(l.deleteAccountTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.deleteAccountBody),
                  const SizedBox(height: 12),
                  TextField(
                    controller: typeController,
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(hintText: l.deleteTypeHint),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(MaterialLocalizations.of(dialogContext)
                      .cancelButtonLabel),
                ),
                FilledButton(
                  onPressed: typeController.text.trim() == 'DELETE'
                      ? () => Navigator.pop(dialogContext, true)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: context.danger,
                    foregroundColor: context.onSolid,
                  ),
                  child: Text(l.deletePermanently),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final deleted = await auth.deleteAccount();
    if (deleted) {
      await s.clearLocalAccountData();
      return;
    }
    messenger.showSnackBar(SnackBar(
      content: Text(auth.lastError ?? l.deleteAccountFailed),
      behavior: SnackBarBehavior.floating,
    ));
  }

  static String _categoryLabel(
    AppLocalizations l,
    ReminderCategory category,
  ) =>
      switch (category) {
        ReminderCategory.bills => l.reminderBills,
        ReminderCategory.budget => l.reminderBudget,
        ReminderCategory.kids => l.reminderKids,
        ReminderCategory.circle => l.reminderCircle,
        ReminderCategory.goals => l.reminderGoals,
        ReminderCategory.meeting => l.reminderMeeting,
        ReminderCategory.digest => l.reminderDigest,
      };

  Widget _header(BuildContext context, IconData icon, String text) =>
      SectionHeader(text, icon: icon);

  Widget _adaptiveDropdownTile(
    BuildContext context, {
    required String title,
    required Widget dropdown,
    String? subtitle,
    IconData? icon,
  }) {
    final scaled = MediaQuery.textScalerOf(context).scale(13) >= 18;
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.ink,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: context.inkSoft),
          ),
      ],
    );
    if (scaled) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(height: 6),
            ],
            copy,
            const SizedBox(height: 4),
            SizedBox(width: double.infinity, child: dropdown),
          ],
        ),
      );
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: icon == null ? null : Icon(icon, size: 20),
      title: copy,
      trailing: SizedBox(width: 150, child: dropdown),
    );
  }

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
