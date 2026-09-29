import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/ui.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/observability/reporter.dart';
import '../../core/auth/pin_store.dart';
import '../settings/settings_screen.dart';
import '../settings/sync_screen.dart';
import 'invite_screen.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/money/money.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/models/models.dart';
import '../../core/state/app_state.dart';
import '../../core/sync/avatar_service.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';

Future<void> _pickAndUploadPhoto(BuildContext sheetCtx, AppState s) async {
  final l = AppLocalizations.of(sheetCtx)!;
  final messenger = ScaffoldMessenger.of(sheetCtx);
  try {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 720, imageQuality: 72);
    if (picked == null) return;
    messenger.showSnackBar(SnackBar(
        content: Text(l.photoUploading), behavior: SnackBarBehavior.floating));
    final bytes = await picked.readAsBytes();
    final ext = picked.name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final url = s.env.supabaseUrl;
    final key = s.env.supabaseAnonKey;
    if (url == null || key == null || s.user.id.isEmpty) {
      throw AvatarException(l.photoFailed);
    }
    final uploader = AvatarUploader(
      baseUrl: url,
      anonKey: key,
      tokenGet: () async {
        final t = await s.db?.kvGet('auth_access_token');
        if (t != null && t.isNotEmpty) return t;
        final auth = s.auth;
        if (auth == null) return null;
        return auth.refreshAccessToken();
      },
    );
    final publicUrl =
        await uploader.upload(bytes: bytes, userId: s.user.id, ext: ext);
    s.setMyAvatar(publicUrl);
    messenger.showSnackBar(SnackBar(
        content: Text(l.photoSaved), behavior: SnackBarBehavior.floating));
  } on AvatarException {
    messenger.showSnackBar(SnackBar(
        content: Text(l.avatarError), behavior: SnackBarBehavior.floating));
  } catch (_) {
    messenger.showSnackBar(SnackBar(
        content: Text(l.photoFailed), behavior: SnackBarBehavior.floating));
  }
}

Future<void> _addChoreSheet(BuildContext context, AppState s) async {
  final l = AppLocalizations.of(context)!;
  var name = '';
  var stars = '3';
  String? error;
  await showMhuriSheet<void>(
    context: context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheet) => MhuriSheetShell(
        title: l.addChore,
        subtitle: l.addChoreHint,
        footer: PrimaryButton(
          label: l.addChore,
          onPressed: () {
            final reward = int.tryParse(stars.trim());
            if (name.trim().isEmpty || reward == null || reward < 1) {
              setSheet(() => error = l.choreFieldsRequired);
              return;
            }
            final added = s.addChore(
              name: name,
              starsReward: reward,
            );
            if (added == null) {
              setSheet(() => error = l.choreFieldsRequired);
              return;
            }
            Navigator.pop(sheetContext);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l.choreAdded(added.name)),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.choreName),
              onChanged: (value) {
                name = value;
                if (error != null) setSheet(() => error = null);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: stars,
              keyboardType: TextInputType.number,
              inputFormatters: integerInputFormatters,
              decoration: InputDecoration(labelText: l.starReward),
              onChanged: (value) {
                stars = value;
                if (error != null) setSheet(() => error = null);
              },
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(error!, style: TextStyle(color: context.danger)),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

void _editProfileSheet(BuildContext context, AppState s, Member m) {
  final l = AppLocalizations.of(context)!;
  final nameCtrl = TextEditingController(text: m.name);
  var avatar = m.emoji;
  const avatarKeys = [
    'person',
    'man',
    'woman',
    'boy',
    'baby',
    'student',
    'grandma'
  ];
  showMhuriSheet<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => MhuriSheetShell(
        title: l.editProfile,
        subtitle: l.editProfileSub,
        footer: PrimaryButton(
          label: l.save,
          onPressed: () {
            s.updateMember(m.id, name: nameCtrl.text, emoji: avatar);
            Navigator.pop(ctx);
          },
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: m.name,
                filled: true,
                fillColor: context.card,
                border: const OutlineInputBorder(borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final k in avatarKeys)
                  InkWell(
                    onTap: () => setSheet(() => avatar = k),
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: avatar == k
                              ? context.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 21,
                        backgroundColor: context.card,
                        child: Icon(iconForKey(k) ?? Icons.person,
                            size: 20, color: context.ink),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    onPressed: () => _pickAndUploadPhoto(context, s),
                    icon: Icons.photo_outlined,
                    label: l.addPhoto,
                  ),
                ),
                if (m.avatarUrl != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: SecondaryButton(
                      onPressed: () {
                        s.setMyAvatar('');
                        Navigator.pop(ctx);
                      },
                      danger: true,
                      label: l.removePhoto,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Color _roleBg(Role role) => switch (role) {
      Role.owner => const Color(0xFFD9EDE8),
      Role.adult => const Color(0xFFFBE7C6),
      Role.teen => const Color(0xFFDCEBFA),
      Role.kid => const Color(0xFFFFF1C9),
      Role.viewer => const Color(0xFFEFE3F7),
    };

/// Members, roles and the "View as" profile switcher (spec §3, §7.10).
class MembersScreen extends StatelessWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final l = AppLocalizations.of(context)!;
    final syncedName = s.spaceName?.trim();
    final familyName =
        syncedName != null && syncedName.isNotEmpty ? syncedName : s.space.name;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.familyTitle),
        actions: [
          IconButton(
            tooltip: AppLocalizations.of(context)!.settingsTitle,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            icon: Icon(Icons.settings_outlined, color: context.ink),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            // ── Space card ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [context.primary, context.primaryDark],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          familyName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l.membersCycleDesc(s.monthStartDay),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (s.canAdmin)
                    PopupMenuButton<String>(
                      color: context.card,
                      iconColor: Colors.white,
                      tooltip: 'Manage family',
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editFamilySheet(context, s, familyName);
                        } else if (value == 'invite') {
                          Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => const InviteScreen(),
                          ));
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 'edit', child: Text('Edit family')),
                        PopupMenuItem(
                            value: 'invite', child: Text('Invite member')),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                AppLocalizations.of(context)!.membersInviteHint,
                style: TextStyle(fontSize: 12, color: context.inkSoft),
              ),
            ),
            const SizedBox(height: 16),

            // ── Members ───────────────────────────────────────────────────
            for (final m in s.members) ...[
              _MemberRow(m: m),
              const SizedBox(height: 10),
            ],

            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: s.canInvite
                  ? () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const InviteScreen(),
                        ),
                      )
                  : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: context.primary,
                side: BorderSide(color: context.primary),
                minimumSize: const Size.fromHeight(50),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.person_add_alt_1, size: 19),
              label: Text(AppLocalizations.of(context)!.inviteTitle),
            ),
            if (s.canApprove) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.kidsAndChores,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: context.ink,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _addChoreSheet(context, s),
                    icon: const Icon(Icons.add_task_rounded, size: 19),
                    label: Text(l.addChore),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (s.chores.isEmpty)
                Text(
                  l.noFamilyChores,
                  style: TextStyle(color: context.inkSoft, fontSize: 13),
                )
              else
                for (final chore in s.chores)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      chore.state == ChoreState.confirmed
                          ? Icons.check_circle_rounded
                          : Icons.task_alt_rounded,
                      color: context.primary,
                    ),
                    title: Text(chore.name),
                    subtitle: Text(l.choreStars(chore.stars)),
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Chore actions',
                      onSelected: (action) async {
                        if (action == 'edit') {
                          _editChoreSheet(context, s, chore);
                          return;
                        }
                        final ok = await confirmDialog(
                          context,
                          title: 'Remove ${chore.name}?',
                          body: 'The chore will leave the active kids list.',
                          confirmLabel: 'Remove chore',
                          danger: true,
                        );
                        if (ok && context.mounted) {
                          s.archiveChore(chore);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Chore removed'),
                                  behavior: SnackBarBehavior.floating));
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit chore')),
                        PopupMenuItem(
                            value: 'archive', child: Text('Remove chore')),
                      ],
                    ),
                  ),
            ],
            const SizedBox(height: 8),
            const SizedBox(height: 16),

            // ── Settings stubs ────────────────────────────────────────────
            Text(
              AppLocalizations.of(context)!.settingsTitle,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.ink),
            ),
            const SizedBox(height: 10),
            _settingAction(
              context,
              AppLocalizations.of(context)!.switchProfile,
              AppLocalizations.of(context)!.switchProfileSub,
              () => _switchProfileSheet(context, s),
            ),
            _settingAction(
              context,
              AppLocalizations.of(context)!.setCurrency,
              AppLocalizations.of(context)!.setCurrencySub(s.rateLabel),
              () => _currencySheet(context, s),
            ),
            _languageRow(context, s),
            _settingAction(
              context,
              AppLocalizations.of(context)!.setPrivacy,
              AppLocalizations.of(context)!.setPrivacySub,
              () => _privacySheet(context, s),
            ),
            _settingAction(
              context,
              AppLocalizations.of(context)!.setMonthStart,
              AppLocalizations.of(context)!.setMonthStartSub,
              () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            _settingAction(
              context,
              AppLocalizations.of(context)!.setNotif,
              AppLocalizations.of(context)!.setNotifSub,
              () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            if (s.isLive && !s.hasSpace) _spaceCard(context, s),
            _pinRow(context, s),
            if (s.auth?.isLoggedIn ?? false) _accountRow(context, s),
            _settingAction(
              context,
              AppLocalizations.of(context)!.setBackup,
              AppLocalizations.of(context)!.setBackupSub,
              () => _backupSheet(context, s),
            ),
          ],
        ),
      ),
    );
  }

  Widget _languageRow(BuildContext context, AppState s) => InkWell(
        onTap: () => _pickLanguage(context, s),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.hairline)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tStr(context, 'language'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: context.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      kLanguageNames[s.localeCode] ?? 'English',
                      style: TextStyle(fontSize: 12, color: context.inkSoft),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.inkSoft),
            ],
          ),
        ),
      );

  Future<void> _pickLanguage(BuildContext context, AppState s) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(tStr(context, 'language')),
        children: [
          for (final entry in kLanguageNames.entries)
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(ctx, entry.key);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    if (s.localeCode == entry.key)
                      Icon(Icons.check, color: context.primary, size: 18)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 8),
                    Text(
                      entry.value,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              AppLocalizations.of(context)!.localizedNote,
              style: TextStyle(fontSize: 11.5, color: context.inkSoft),
            ),
          ),
        ],
      ),
    );
    if (selected == null || !context.mounted) return;
    s.setLocale(selected);
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  Widget _spaceCard(BuildContext context, AppState s) {
    final engine = s.sync;

    // No space yet → setup card.
    if (!s.hasSpace || engine == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.spaceSetup,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: context.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context)!.spaceSetupSub,
              style:
                  TextStyle(fontSize: 12, color: context.inkSoft, height: 1.35),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _createSpaceDialog(context, s),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.primary,
                      foregroundColor: context.onSolid,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(AppLocalizations.of(context)!.createSpace),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _joinSpaceDialog(context, s),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.primary,
                      side: BorderSide(color: context.primary),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(AppLocalizations.of(context)!.joinWithCode),
                  ),
                ),
              ],
            ),
            if (s.syncLastError != null &&
                (s.syncStatus == SyncStatus.error ||
                    s.syncStatus == SyncStatus.offline)) ...[
              const SizedBox(height: 10),
              Text(
                s.syncLastError!,
                style: TextStyle(fontSize: 11.5, color: context.expenseRed),
              ),
            ],
          ],
        ),
      );
    }

    // Space linked → status card.
    final last = s.lastSyncAt;
    final lastText = last == null
        ? 'never'
        : AppLocalizations.of(context)!
            .syncTime('${_twoDigits(last.hour)}:${_twoDigits(last.minute)}');
    final statusText = switch (s.syncStatus) {
      SyncStatus.syncing => AppLocalizations.of(context)!.syncing,
      SyncStatus.offline => AppLocalizations.of(context)!.offlineRetry,
      SyncStatus.error =>
        s.syncLastError ?? AppLocalizations.of(context)!.syncProblem,
      SyncStatus.needsSignIn => AppLocalizations.of(context)!.signinExpired,
      _ => AppLocalizations.of(context)!.lastSync(lastText),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient:
            LinearGradient(colors: [context.primary, context.primaryDark]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.spaceName ?? AppLocalizations.of(context)!.familySpace,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  s.inviteCode ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context)!.membersInviteHint,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  statusText,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              TextButton.icon(
                onPressed: () => engine.syncNow(),
                icon: const Icon(Icons.sync, size: 16, color: Colors.white),
                label: Text(
                  AppLocalizations.of(context)!.syncNow,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _createSpaceDialog(BuildContext context, AppState s) async {
    final engine = s.sync;
    if (engine == null) return;
    final l = AppLocalizations.of(context)!;
    final name = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l.createFamilySpace),
        content: MhuriField(
          controller: name,
          label: l.familyName,
          hint: l.hintFamilyExample,
          fillColor: context.bg,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primary,
              foregroundColor: context.onSolid,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.btnCreate),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await engine.createSpace(
      name.text.trim().isEmpty ? l.myFamily : name.text.trim(),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? l.spaceCreated(s.inviteCode ?? '?')
              : (s.syncLastError ?? l.createFail),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _joinSpaceDialog(BuildContext context, AppState s) async {
    final l = AppLocalizations.of(context)!;
    final engine = s.sync;
    if (engine == null) return;
    final code = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppLocalizations.of(context)!.joinSpaceTitle),
        content: TextField(
          controller: code,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.inviteCode,
            hintText: 'MHRI-XXXX',
            filled: true,
            fillColor: context.bg,
            border: const OutlineInputBorder(borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primary,
              foregroundColor: context.onSolid,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.btnJoin),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await engine.joinSpace(code.text);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? AppLocalizations.of(context)!.joinedOk
              : (s.syncLastError ?? AppLocalizations.of(context)!.joinFail),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _pinRow(BuildContext context, AppState s) => InkWell(
        onTap: () => _editParentPin(context, s),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.hairline)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.kidsPin,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: context.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context)!.kidsPinSub,
                      style: TextStyle(fontSize: 12, color: context.inkSoft),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.inkSoft),
            ],
          ),
        ),
      );

  void _editParentPin(BuildContext context, AppState s) {
    final l = AppLocalizations.of(context)!;
    final pin = TextEditingController();
    String? pinError;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(AppLocalizations.of(context)!.kidsPin),
          content: TextField(
            controller: pin,
            keyboardType: TextInputType.number,
            inputFormatters: pinInputFormatters,
            obscureText: true,
            maxLength: 6,
            onChanged: (_) {
              if (pinError != null) setDialogState(() => pinError = null);
            },
            decoration: InputDecoration(
              hintText: l.kidsPinHint,
              counterText: '',
              errorText: pinError,
              errorStyle: TextStyle(color: context.danger),
              filled: true,
              fillColor: context.bg,
              border: const OutlineInputBorder(borderSide: BorderSide.none),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.primary,
                foregroundColor: context.onSolid,
              ),
              onPressed: () async {
                final v = pin.text.trim();
                if (v.length < 4) {
                  setDialogState(() => pinError = l.kidsPinHint);
                  return;
                }
                await s.pinStore.setPin(PinStore.parentKey, v);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l.kidsPinUpdated),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: Text(MaterialLocalizations.of(ctx).saveButtonLabel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountRow(BuildContext context, AppState s) {
    final auth = s.auth!;
    final l = AppLocalizations.of(context)!;
    final phone = auth.session?.email ?? '';
    final masked = phone.length <= 4
        ? phone
        : '\u2022\u2022\u2022 ${phone.substring(phone.length - 4)}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.accountTitle,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: context.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l.signedInAs(masked),
            style: TextStyle(fontSize: 12, color: context.inkSoft),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: auth.busy
                    ? null
                    : () async {
                        final navigator = Navigator.of(context);
                        navigator.popUntil((route) => route.isFirst);
                        await auth.signOut();
                      },
                child: Text(l.signOut),
              ),
              TextButton(
                onPressed:
                    auth.busy ? null : () => _confirmDeleteAccount(context, s),
                style: TextButton.styleFrom(foregroundColor: context.danger),
                child: Text(l.deleteAccount),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context, AppState s) async {
    final auth = s.auth;
    if (auth == null) return;

    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    // Rule: Owner cannot delete or abandon family while other members exist
    if (s.canDeleteSpace && s.members.length > 1) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(l.makeOwner),
          content: const Text(
            'You are the owner of this family space. Please transfer ownership to another adult member before deleting your account, or remove all other members first.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
            ),
          ],
        ),
      );
      return;
    }

    // Reauthentication step: verify current password before account deletion
    final passwordCtrl = TextEditingController();
    var obscurePw = true;
    String? reauthError;
    var reauthBusy = false;

    final reauthenticated = await showDialog<bool>(
      context: context,
      builder: (reauthCtx) => StatefulBuilder(
        builder: (reauthCtx, setReauth) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Confirm your password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'For security, enter your current password to confirm account deletion.',
                style: TextStyle(
                    fontSize: 13, color: context.inkSoft, height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                obscureText: obscurePw,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l.passwordLabel,
                  errorText: reauthError,
                  filled: true,
                  fillColor: context.card,
                  border: const OutlineInputBorder(borderSide: BorderSide.none),
                  suffixIcon: IconButton(
                    icon: Icon(obscurePw
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setReauth(() => obscurePw = !obscurePw),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed:
                  reauthBusy ? null : () => Navigator.pop(reauthCtx, false),
              child:
                  Text(MaterialLocalizations.of(reauthCtx).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: reauthBusy
                  ? null
                  : () async {
                      final pw = passwordCtrl.text.trim();
                      if (pw.isEmpty) {
                        setReauth(() => reauthError = l.loginShortPassword);
                        return;
                      }
                      setReauth(() {
                        reauthBusy = true;
                        reauthError = null;
                      });
                      final ok = await auth.reauthenticate(pw);
                      if (!reauthCtx.mounted) return;
                      if (ok) {
                        Navigator.pop(reauthCtx, true);
                      } else {
                        setReauth(() {
                          reauthBusy = false;
                          reauthError =
                              auth.lastError ?? l.authErrBadCredentials;
                        });
                      }
                    },
              child: reauthBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                  : const Text('Verify'),
            ),
          ],
        ),
      ),
    );
    if (reauthenticated != true) return;
    if (!context.mounted) return;

    // Step 1 of 3 - what actually happens (owner and member differ; the
    // server enforces the real rules, migration 008).
    final proceed = await showMhuriSheet<bool>(
          context: context,
          builder: (sheetContext) => MhuriSheetShell(
            title: l.deleteWhatTitle,
            footer: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: context.danger,
                      foregroundColor: context.onSolid,
                    ),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.pop(sheetContext, true);
                    },
                    child: Text(l.deletePermanently),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(sheetContext, false),
                    child: Text(MaterialLocalizations.of(sheetContext)
                        .cancelButtonLabel),
                  ),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.canDeleteSpace ? l.deleteWhatOwner : l.deleteWhatMember,
                  style: TextStyle(
                      fontSize: 13.5, color: context.ink, height: 1.45),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.logout, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(l.deleteWhatSessions,
                          style: TextStyle(
                              fontSize: 12.5, color: context.inkSoft)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.shield_outlined,
                        size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.canDeleteSpace
                            ? 'All family ledger entries and balances will be permanently erased.'
                            : 'Past transactions remain preserved with your name anonymized to keep balances balanced.',
                        style:
                            TextStyle(fontSize: 12.5, color: context.inkSoft),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (!proceed) return;
    if (!context.mounted) return;

    final typeCtrl = TextEditingController();
    // P5: destructive tier - typing DELETE + a button that stays disabled
    // until the exact word matches. Never pops on the happy path by accident.
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (dialogContext, setDialog) => AlertDialog(
              title: Text(l.deleteAccountTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.deleteAccountBody,
                      style: TextStyle(
                          fontSize: 13, color: context.inkSoft, height: 1.4)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: typeCtrl,
                    autofocus: true,
                    onChanged: (_) => setDialog(() {}),
                    decoration: InputDecoration(
                      hintText: l.deleteTypeHint,
                      filled: true,
                      fillColor: context.card,
                      border:
                          const OutlineInputBorder(borderSide: BorderSide.none),
                    ),
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
                  onPressed: typeCtrl.text.trim() == 'DELETE'
                      ? () => Navigator.pop(dialogContext, true)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: context.danger,
                    foregroundColor: context.onSolid,
                    disabledBackgroundColor:
                        context.danger.withValues(alpha: 0.5),
                  ),
                  child: Text(l.deletePermanently),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!confirmed) return;
    if (!context.mounted) return;
    mhuriEvent('account.delete.requested',
        {'role': s.user.role.name}); // no identifiers - see reporter.dart
    // Step 3 of 3 - progress while the server does the four phases; the
    // dialog is not dismissible and pops with the outcome.
    final deleted = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _DeleteProgressDialog(auth: auth),
        ) ??
        false;
    if (deleted) {
      await s.clearLocalAccountData();
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(auth.lastError ?? l.deleteAccountFailed),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Premium pass: every settings row now does something ──────────────────

  Widget _settingAction(BuildContext context, String title, String subtitle,
          VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.hairline)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: context.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: context.inkSoft),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.inkSoft),
            ],
          ),
        ),
      );

  Future<void> _switchProfileSheet(BuildContext context, AppState s) async {
    final l = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final selected = await showMhuriSheet<Member>(
      context: context,
      builder: (ctx) => MhuriSheetShell(
        title: l.switchProfile,
        subtitle: l.switchProfileSub,
        child: ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: s.members.length,
          itemBuilder: (ctx, index) {
            final member = s.members[index];
            return _profileTile(
              ctx,
              s,
              member,
              () => Navigator.pop(ctx, member),
            );
          },
        ),
      ),
    );
    if (selected == null || !navigator.mounted) return;
    navigator.popUntil((route) => route.isFirst);
    s.switchUser(selected);
  }

  Widget _profileTile(
    BuildContext ctx,
    AppState s,
    Member m,
    VoidCallback onSelected,
  ) {
    final l = AppLocalizations.of(ctx)!;
    final isCurrent = s.user.id == m.id;
    return ListTile(
      leading: MemberAvatar(
        backgroundColor: _roleBg(m.role),
        icon: iconForKey(m.emoji) ?? Icons.person,
        imageUrl: m.avatarUrl,
      ),
      title: Text(
        m.name,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14.5,
          color: ctx.ink,
        ),
      ),
      subtitle: Text(
        roleLabel(AppLocalizations.of(ctx)!, m.role),
        style: TextStyle(fontSize: 12, color: ctx.inkSoft),
      ),
      trailing: isCurrent
          ? Text(
              l.youTag,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: ctx.primary,
              ),
            )
          : Icon(Icons.chevron_right, color: ctx.inkSoft),
      onTap: onSelected,
    );
  }

  void _currencySheet(BuildContext context, AppState s) {
    final l = AppLocalizations.of(context)!;
    if (s.secondaryCurrency != null) {
      final isZwgPair = s.primaryCurrency == Currency.zwg ||
          s.secondaryCurrency == Currency.zwg;
      if (!isZwgPair && s.rate > 15) {
        final def = s.primaryCurrency.defaultRateTo(s.secondaryCurrency!);
        s.setCustomRate(def);
      }
    }
    final rateCtrl = TextEditingController(text: s.rate.toString());
    showMhuriSheet<void>(
      context: context,
      builder: (ctx) => AnimatedBuilder(
        animation: s,
        builder: (ctx, _) => MhuriSheetShell(
          title: l.setCurrency,
          footer: PrimaryButton(
            label: l.rateSave,
            onPressed: () {
              final v = double.tryParse(rateCtrl.text.trim());
              if (v != null && v > 0) s.setCustomRate(v);
              Navigator.pop(ctx);
            },
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Primary Family Currency',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: ctx.inkSoft,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<Currency>(
                initialValue: s.primaryCurrency,
                isExpanded: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: ctx.card,
                  border: const OutlineInputBorder(borderSide: BorderSide.none),
                ),
                items: [
                  for (final c in Currency.values)
                    DropdownMenuItem(
                      value: c,
                      child: Text('${c.long} (${c.symbol})'),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    s.setPrimaryCurrency(v);
                    rateCtrl.text = s.rate.toString();
                  }
                },
              ),
              const SizedBox(height: 14),
              Text(
                'Secondary Currency (Optional Dual-Currency)',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: ctx.inkSoft,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<Currency?>(
                initialValue: s.secondaryCurrency,
                isExpanded: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: ctx.card,
                  border: const OutlineInputBorder(borderSide: BorderSide.none),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('None (Single Currency Mode)'),
                  ),
                  for (final c
                      in Currency.values.where((c) => c != s.primaryCurrency))
                    DropdownMenuItem(
                      value: c,
                      child: Text('${c.long} (${c.symbol})'),
                    ),
                ],
                onChanged: (v) {
                  s.setSecondaryCurrency(v);
                  rateCtrl.text = s.rate.toString();
                },
              ),
              const SizedBox(height: 14),
              if (s.secondaryCurrency != null) ...[
                Text(
                  'Exchange Rate (1 ${s.primaryCurrency.short} = ? ${s.secondaryCurrency!.short})',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: ctx.inkSoft,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: rateCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: amountInputFormatters,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: ctx.card,
                    border:
                        const OutlineInputBorder(borderSide: BorderSide.none),
                    suffixIcon: TextButton(
                      onPressed: () {
                        if (s.secondaryCurrency != null) {
                          final def = s.primaryCurrency
                              .defaultRateTo(s.secondaryCurrency!);
                          s.setCustomRate(def);
                          rateCtrl.text = def.toString();
                        }
                      },
                      child: Text(l.rateReset),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Used for conversion between ${s.primaryCurrency.short} and ${s.secondaryCurrency!.short} across the app.',
                  style: TextStyle(fontSize: 11.5, color: ctx.inkSoft),
                ),
                const SizedBox(height: 14),
              ],
              Text(
                'Current Display View',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: ctx.inkSoft,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final c in s.activeCurrencies)
                    Expanded(
                      child: InkWell(
                        onTap: () => s.setDisplayCurrency(c),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color:
                                s.displayCurrency == c ? ctx.primary : ctx.card,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            c.short,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: s.displayCurrency == c
                                  ? ctx.onSolid
                                  : ctx.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _privacySheet(BuildContext context, AppState s) {
    final l = AppLocalizations.of(context)!;
    showMhuriSheet<void>(
      context: context,
      builder: (ctx) => AnimatedBuilder(
        animation: s,
        builder: (ctx, _) => MhuriSheetShell(
          title: l.setPrivacy,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile.adaptive(
                value: s.autoHideAmounts,
                onChanged: s.setAutoHideAmounts,
                title: Text(
                  l.autoHide,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ctx.ink),
                ),
                subtitle: Text(
                  l.autoHideSub,
                  style: TextStyle(fontSize: 12, color: ctx.inkSoft),
                ),
              ),
              SwitchListTile.adaptive(
                value: s.hideAmounts,
                onChanged: s.setHideAmounts,
                title: Text(
                  l.hideNow,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ctx.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _backupSheet(BuildContext context, AppState s) {
    final l = AppLocalizations.of(context)!;
    showMhuriSheet<void>(
      context: context,
      builder: (ctx) => MhuriSheetShell(
        title: l.setBackup,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: Icon(Icons.ios_share, color: ctx.primary),
              title: Text(
                l.exportCsvRow,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: ctx.ink),
              ),
              onTap: () async {
                final path = await s.exportCsv();
                if (!ctx.mounted) return;
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      path == null ? l.exportReal : l.exportedPath(path),
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            if (s.isLive && (s.inviteCode ?? '').isNotEmpty) ...[
              ListTile(
                leading: Icon(Icons.person_add_alt, color: ctx.primary),
                title: Text(
                  l.inviteTitle,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ctx.ink),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const InviteScreen(),
                  ));
                },
              ),
              ListTile(
                leading: Icon(Icons.link, color: ctx.primary),
                title: Text(
                  l.copyInvite,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ctx.ink),
                ),
                onTap: () {
                  final messenger = ScaffoldMessenger.of(context);
                  Clipboard.setData(ClipboardData(text: s.inviteCode ?? ''));
                  Navigator.pop(ctx);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(l.copied),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
            ListTile(
              leading: Icon(Icons.cloud_sync_outlined, color: ctx.primary),
              title: Text(
                l.syncDataTitle,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: ctx.ink),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const SyncScreen(),
                ));
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _editFamilySheet(
    BuildContext context, AppState state, String currentName) async {
  final controller = TextEditingController(text: currentName);
  var saving = false;
  String? error;
  await showMhuriSheet<void>(
    context: context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheet) => MhuriSheetShell(
        title: 'Edit family',
        subtitle: 'The updated name will sync to every family member.',
        footer: PrimaryButton(
          label: saving ? 'Saving…' : 'Save changes',
          onPressed: saving
              ? null
              : () async {
                  final name = controller.text.trim();
                  if (name.length < 2) {
                    setSheet(() => error = 'Enter a family name.');
                    return;
                  }
                  setSheet(() {
                    saving = true;
                    error = null;
                  });
                  try {
                    await state.sync?.updateFamilyName(name);
                    if (!sheetContext.mounted) return;
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(sheetContext);
                    messenger.showSnackBar(const SnackBar(
                      content: Text('Family name changed'),
                      behavior: SnackBarBehavior.floating,
                    ));
                  } catch (_) {
                    if (sheetContext.mounted) {
                      setSheet(() {
                        saving = false;
                        error = 'Could not change the family name. Try again.';
                      });
                    }
                  }
                },
        ),
        child: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'Family name',
            errorText: error,
          ),
        ),
      ),
    ),
  );
}

Future<void> _editChoreSheet(
    BuildContext context, AppState state, Chore chore) async {
  final name = TextEditingController(text: chore.name);
  final stars = TextEditingController(text: '${chore.stars}');
  var assignee = chore.assigneeMemberId;
  String? error;
  await showMhuriSheet<void>(
    context: context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheet) => MhuriSheetShell(
        title: 'Edit chore',
        footer: PrimaryButton(
          label: 'Save changes',
          onPressed: () {
            final reward = int.tryParse(stars.text);
            if (name.text.trim().isEmpty || reward == null || reward < 1) {
              setSheet(() => error = 'Enter a chore name and star reward.');
              return;
            }
            state.updateChore(chore,
                name: name.text, starsReward: reward, assigneeId: assignee);
            final messenger = ScaffoldMessenger.of(context);
            Navigator.pop(sheetContext);
            messenger.showSnackBar(const SnackBar(
                content: Text('Chore updated'),
                behavior: SnackBarBehavior.floating));
          },
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Chore name')),
          const SizedBox(height: 12),
          TextField(
              controller: stars,
              keyboardType: TextInputType.number,
              inputFormatters: integerInputFormatters,
              decoration: const InputDecoration(labelText: 'Star reward')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: assignee,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Assign to'),
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('Any child')),
              for (final member in state.members
                  .where((m) => m.role == Role.kid || m.role == Role.teen))
                DropdownMenuItem<String?>(
                    value: member.id, child: Text(member.name)),
            ],
            onChanged: (value) => setSheet(() => assignee = value),
          ),
          if (error != null) ErrorNotice(error!),
        ]),
      ),
    ),
  );
}

class _MemberRow extends StatelessWidget {
  final Member m;

  const _MemberRow({required this.m});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final isMe = s.user.id == m.id;
    // Profile switching previews that member's view; Kids Mode stays
    // PIN-sealed.

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _roleBg(m.role),
                backgroundImage:
                    m.avatarUrl != null ? NetworkImage(m.avatarUrl!) : null,
                child: m.avatarUrl != null
                    ? null
                    : Icon(
                        iconForKey(m.emoji) ?? Icons.person,
                        size: 20,
                        color: context.ink,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: isMe ? () => _editProfileSheet(context, s, m) : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              m.name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: context.ink,
                              ),
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 6),
                            Text(
                              AppLocalizations.of(context)!.youTag,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: context.primary,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        roleLabel(AppLocalizations.of(context)!, m.role),
                        style: TextStyle(fontSize: 12, color: context.inkSoft),
                      ),
                    ],
                  ),
                ),
              ),
              if (isMe)
                InkWell(
                  onTap: () => _editProfileSheet(context, s, m),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.edit, size: 18, color: context.primary),
                  ),
                ),
              if (!isMe)
                OutlinedButton(
                  onPressed: () {
                    final navigator = Navigator.of(context);
                    s.switchUser(m);
                    navigator.popUntil((r) => r.isFirst);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.primary,
                    side: BorderSide(color: context.primary),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(AppLocalizations.of(context)!.viewAs),
                ),
            ],
          ),
          // Owner handing the family over (server: roles swap, the family
          // code moves, audit row - migration 010).
          if (!isMe && s.canTransferOwnership && m.role == Role.adult)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _makeOwner(context, s, m),
                  icon: const Icon(Icons.workspace_premium, size: 18),
                  label: Text(AppLocalizations.of(context)!.makeOwner),
                ),
              ),
            ),
          if (!isMe && s.canAdmin) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<String>(
                tooltip: 'Manage ${m.name}',
                onSelected: (action) => _manageMember(context, s, m, action),
                itemBuilder: (_) => [
                  if ((m.serverRole ?? m.role.name) == 'adult')
                    const PopupMenuItem(
                      value: 'promote',
                      child: Text('Make Family Admin'),
                    ),
                  if ((m.serverRole ?? m.role.name) == 'co_parent')
                    const PopupMenuItem(
                      value: 'adult',
                      child: Text('Change to Adult Member'),
                    ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'remove',
                    child: Text('Remove from family'),
                  ),
                ],
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text('Manage',
                      style: TextStyle(
                          color: context.primary, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _makeOwner(BuildContext context, AppState s, Member m) async {
    final l = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.makeOwner),
        content: Text(l.makeOwnerBody(m.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.makeOwner)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await s.sync?.transferOwnership(m.id);
      await s.refresh();
      navigator.popUntil((r) => r.isFirst);
      messenger.showSnackBar(SnackBar(
        content: Text(l.makeOwnerDone(m.name)),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      messenger.showSnackBar(SnackBar(
        content: Text(l.makeOwnerFailed),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _manageMember(
      BuildContext context, AppState s, Member m, String action) async {
    final messenger = ScaffoldMessenger.of(context);
    if (action == 'remove') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: Text('Remove ${m.name}?'),
          content: const Text(
            'They will lose access to this family. Their previous financial activity will remain in the family history.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Remove member')),
          ],
        ),
      );
      if (confirmed != true) return;
      try {
        await s.sync?.removeFamilyMember(m.id);
        messenger.showSnackBar(const SnackBar(
            content: Text('Member removed'),
            behavior: SnackBarBehavior.floating));
      } catch (_) {
        messenger.showSnackBar(const SnackBar(
            content: Text(
                'Could not remove this member. The family must always have an admin.'),
            behavior: SnackBarBehavior.floating));
      }
      return;
    }
    final targetRole = action == 'promote' ? 'co_parent' : 'adult';
    try {
      await s.sync?.changeMemberRole(m.id, targetRole);
      messenger.showSnackBar(SnackBar(
        content: Text(action == 'promote'
            ? '${m.name} is now a Family Admin'
            : '${m.name} is now an Adult Member'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not change this member\'s role.'),
          behavior: SnackBarBehavior.floating));
    }
  }
}

/// Step 3 of account deletion: shows the four server phases while the RPC
/// runs (not dismissible), marks them done on completion, pops with the
/// outcome. The server performs all phases in one call - the list explains
/// what is happening, it does not fake per-step timing.
class _DeleteProgressDialog extends StatefulWidget {
  const _DeleteProgressDialog({required this.auth});

  final AuthController auth;

  @override
  State<_DeleteProgressDialog> createState() => _DeleteProgressDialogState();
}

class _DeleteProgressDialogState extends State<_DeleteProgressDialog> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final r = await widget.auth.deleteAccount();
    if (!mounted) return;
    setState(() => _done = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    Navigator.of(context).pop(r);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final steps = [
      l.deleteStepLeave,
      l.deleteStepAnonymize,
      l.deleteStepSessions,
      l.deleteStepIdentity,
    ];
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final step in steps)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  if (_done)
                    const Icon(Icons.check_circle,
                        size: 18, color: Colors.green)
                  else
                    const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator.adaptive(strokeWidth: 2)),
                  const SizedBox(width: 10),
                  Expanded(
                      child:
                          Text(step, style: const TextStyle(fontSize: 13.5))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
