import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

import '../../core/auth/pin_store.dart';
import '../settings/settings_screen.dart';
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
  } on AvatarException catch (e) {
    messenger.showSnackBar(SnackBar(
        content: Text(e.message), behavior: SnackBarBehavior.floating));
  } catch (_) {
    messenger.showSnackBar(SnackBar(
        content: Text(l.photoFailed), behavior: SnackBarBehavior.floating));
  }
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
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.bg,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.editProfile,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l.editProfileSub,
                style: TextStyle(fontSize: 12.5, color: context.inkSoft),
              ),
              const SizedBox(height: 14),
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
                    child: OutlinedButton.icon(
                      onPressed: () => _pickAndUploadPhoto(context, s),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.primary,
                        side: BorderSide(color: context.primary),
                        minimumSize: const Size.fromHeight(44),
                        shape: const StadiumBorder(),
                      ),
                      icon: const Icon(Icons.photo_outlined, size: 18),
                      label: Text(l.addPhoto),
                    ),
                  ),
                  if (m.avatarUrl != null) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {
                        s.setMyAvatar('');
                        Navigator.pop(ctx);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.expenseRed,
                        side: BorderSide(color: context.expenseRed),
                        minimumSize: const Size.fromHeight(44),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(l.removePhoto),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () {
                  s.updateMember(m.id, name: nameCtrl.text, emoji: avatar);
                  Navigator.pop(ctx);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: context.primary,
                  foregroundColor: context.onSolid,
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                ),
                child: Text(l.save),
              ),
            ],
          ),
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
                          'The Taylor Family',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          AppLocalizations.of(context)!.membersDesc,
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'MHRI-4F2K',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
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
              onPressed: () => _inviteSheet(context, s),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.primary,
                side: BorderSide(color: context.primary),
                minimumSize: const Size.fromHeight(50),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.person_add_alt_1, size: 19),
              label: Text(AppLocalizations.of(context)!.inviteTitle),
            ),
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
            if (s.isLive) _spaceCard(context, s),
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
        borderRadius: BorderRadius.circular(18),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(18),
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
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
                  style: TextStyle(
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
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l.familyName,
            hintText: 'e.g. The Taylor Family',
            filled: true,
            fillColor: context.bg,
            border: OutlineInputBorder(borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primary,
              foregroundColor: context.onSolid,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
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
            border: OutlineInputBorder(borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primary,
              foregroundColor: context.onSolid,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Join'),
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
        borderRadius: BorderRadius.circular(18),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(18),
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
    final pin = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppLocalizations.of(context)!.kidsPin),
        content: TextField(
          controller: pin,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          decoration: InputDecoration(
            hintText: 'New PIN (4\u20136 digits)',
            counterText: '',
            filled: true,
            fillColor: context.bg,
            border: OutlineInputBorder(borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primary,
              foregroundColor: context.onSolid,
            ),
            onPressed: () async {
              final v = pin.text.trim();
              if (v.length >= 4) {
                await s.pinStore.setPin(PinStore.parentKey, v);
              }
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Kids Mode PIN updated \u2713'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
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
    final typeCtrl = TextEditingController();
    // P5: destructive tier — typing DELETE + a button that stays disabled
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
                      border: OutlineInputBorder(borderSide: BorderSide.none),
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
    final deleted = await auth.deleteAccount();
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
        borderRadius: BorderRadius.circular(18),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(18),
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

  void _inviteSheet(BuildContext context, AppState s) {
    final l = AppLocalizations.of(context)!;
    final code = s.inviteCode ?? '';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.inviteTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l.inviteHowTo,
                style: TextStyle(
                    fontSize: 12.5, color: context.inkSoft, height: 1.4),
              ),
              const SizedBox(height: 14),
              if (code.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: context.primary, width: 1.4),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    code,
                    style: TextStyle(
                      fontSize: 26,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w800,
                      color: context.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    final messenger = ScaffoldMessenger.of(context);
                    Clipboard.setData(ClipboardData(text: code));
                    Navigator.pop(ctx);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(l.copied),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: context.primary,
                    foregroundColor: context.onSolid,
                    minimumSize: const Size.fromHeight(48),
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(l.copyInvite),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _switchProfileSheet(BuildContext context, AppState s) async {
    final l = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final selected = await showModalBottomSheet<Member>(
      context: context,
      backgroundColor: context.bg,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.8,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.switchProfile,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l.switchProfileSub,
                style: TextStyle(fontSize: 12.5, color: context.inkSoft),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
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
            ],
          ),
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
      leading: CircleAvatar(
        backgroundColor: _roleBg(m.role),
        backgroundImage:
            m.avatarUrl != null ? NetworkImage(m.avatarUrl!) : null,
        child: m.avatarUrl != null
            ? null
            : Icon(iconForKey(m.emoji) ?? Icons.person,
                size: 20, color: ctx.ink),
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
    final rateCtrl = TextEditingController(text: s.rate.toStringAsFixed(2));
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => AnimatedBuilder(
        animation: s,
        builder: (ctx, _) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.setCurrency,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: ctx.ink,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  l.pickCurrency,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: ctx.inkSoft,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final c in Currency.values)
                      Expanded(
                        child: InkWell(
                          onTap: () => s.setDisplayCurrency(c),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: s.displayCurrency == c
                                  ? ctx.primary
                                  : ctx.card,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              c == Currency.usd ? 'USD' : 'ZiG',
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
                const SizedBox(height: 16),
                Text(
                  l.rateField,
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
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: ctx.card,
                    border:
                        const OutlineInputBorder(borderSide: BorderSide.none),
                    suffixIcon: TextButton(
                      onPressed: () {
                        s.setCustomRate(15.27);
                        rateCtrl.text = '15.27';
                      },
                      child: Text(l.rateReset),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l.rateCustomNote,
                  style: TextStyle(fontSize: 11.5, color: ctx.inkSoft),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    final v = double.tryParse(rateCtrl.text.trim());
                    if (v != null && v > 0) s.setCustomRate(v);
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ctx.primary,
                    foregroundColor: ctx.onSolid,
                    minimumSize: const Size.fromHeight(48),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(l.rateSave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _privacySheet(BuildContext context, AppState s) {
    final l = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => AnimatedBuilder(
        animation: s,
        builder: (ctx, _) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    l.setPrivacy,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: ctx.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
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
                SwitchListTile(
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
      ),
    );
  }

  void _backupSheet(BuildContext context, AppState s) {
    final l = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  l.setBackup,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: ctx.ink,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              ListTile(
                leading: Icon(Icons.ios_share, color: ctx.primary),
                title: Text(
                  l.exportCsvRow,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ctx.ink),
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
              if (s.isLive && (s.inviteCode ?? '').isNotEmpty)
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
              ListTile(
                enabled: false,
                leading: const Icon(Icons.cloud_outlined),
                title: Text(
                  l.backupComing,
                  style: TextStyle(fontSize: 14, color: ctx.inkSoft),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
      child: Row(
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
                      Text(
                        m.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: context.ink,
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
    );
  }
}
