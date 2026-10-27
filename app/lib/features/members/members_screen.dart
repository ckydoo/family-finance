import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/ui.dart';

import '../../core/billing/entitlement.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/observability/reporter.dart';
import '../../core/auth/pin_store.dart';
import '../settings/settings_screen.dart';
import '../settings/sync_screen.dart';
import '../activity/activity_screen.dart';
import '../family_chat/family_chat_screen.dart';
import '../family_tasks/family_tasks_screen.dart';
import 'invite_screen.dart';
import '../settings/plus_screen.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/money/money.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/models/models.dart';
import '../../core/state/app_state.dart';
import '../../core/sync/avatar_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_messages.dart';
import '../../l10n/generated/app_localizations.dart';

Future<({bool success, String message})> _pickAndUploadPhoto(
  BuildContext sheetCtx,
  AppState s,
  Member member,
) async {
  final l = AppLocalizations.of(sheetCtx)!;
  try {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 720, imageQuality: 72);
    if (picked == null) {
      return (success: false, message: 'No photo was selected.');
    }
    final bytes = await picked.readAsBytes();
    final ext = picked.name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final url = s.env.supabaseUrl;
    final key = s.env.supabaseAnonKey;
    if (url == null || key == null || member.id.isEmpty) {
      throw AvatarException(l.photoFailed);
    }
    final uploader = AvatarUploader(
      baseUrl: url,
      anonKey: key,
      tokenGet: () async {
        final auth = s.auth;
        if (auth == null) return null;
        return auth.validAccessToken();
      },
    );
    final publicUrl =
        await uploader.upload(bytes: bytes, userId: member.id, ext: ext);
    s.setMemberAvatar(member, publicUrl);
    return (success: true, message: l.photoSaved);
  } on AvatarException catch (e) {
    return (success: false, message: e.message);
  } catch (error) {
    debugPrint('Mhuri avatar upload error: $error');
    return (success: false, message: l.photoFailed);
  }
}

Future<void> showProfileAvatarViewer(
  BuildContext context,
  AppState state, [
  Member? member,
]) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _ProfileAvatarViewer(
        state: state,
        memberId: member?.id,
        initialMember: member,
      ),
    ),
  );
}

class _ProfileAvatarViewer extends StatelessWidget {
  const _ProfileAvatarViewer({
    required this.state,
    this.memberId,
    this.initialMember,
  });

  final AppState state;
  final String? memberId;
  final Member? initialMember;

  @override
  Widget build(BuildContext context) {
    // Listen to avatar edits so the full view updates immediately when the
    // user returns from the editor.
    final liveState = AppScope.of(context);
    final member = memberId == null
        ? liveState.user
        : liveState.member(memberId!) ?? initialMember ?? liveState.user;
    final canEdit = member.id == liveState.realUser.id ||
        liveState.canEditChildProfile(member);
    final imageUrl = member.avatarUrl?.trim();
    final hasPhoto = imageUrl != null && imageUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: Text(member.name),
        leading: IconButton(
          tooltip: 'Close avatar',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: hasPhoto
                ? InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => _LargeAvatar(member),
                      ),
                    ),
                  )
                : _LargeAvatar(member),
          ),
        ),
      ),
      bottomNavigationBar: canEdit
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: FilledButton.icon(
                onPressed: () => _editProfileSheet(context, state, member),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: context.accent,
                  foregroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? context.onSolid
                          : context.primaryDark,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: kBRadiusM),
                ),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Change avatar'),
              ),
            )
          : null,
    );
  }
}

class _LargeAvatar extends StatelessWidget {
  const _LargeAvatar(this.member);

  final Member member;

  @override
  Widget build(BuildContext context) => MemberAvatar(
        radius: 112,
        backgroundColor: context.primarySoft,
        icon: iconForKey(member.emoji) ?? kFallbackSemanticIcon,
        imageUrl: member.avatarUrl,
      );
}

void _editProfileSheet(BuildContext context, AppState s, Member m) {
  final l = AppLocalizations.of(context)!;
  final nameCtrl = TextEditingController(text: m.name);
  var avatar = m.emoji;
  var uploadingPhoto = false;
  String? photoStatus;
  var photoUploadSucceeded = false;
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
          onPressed: uploadingPhoto
              ? null
              : () {
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
                        child: Icon(iconForKey(k) ?? kFallbackSemanticIcon,
                            size: 20, color: context.ink),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (uploadingPhoto) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(
                l.photoUploading,
                style: TextStyle(
                  color: context.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (!uploadingPhoto && photoStatus != null) ...[
              if (photoUploadSucceeded)
                Text(
                  photoStatus!,
                  style: TextStyle(
                    color: context.primary,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                ErrorNotice(photoStatus!),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    onPressed: uploadingPhoto
                        ? null
                        : () async {
                            setSheet(() {
                              uploadingPhoto = true;
                              photoStatus = null;
                            });
                            final result = await _pickAndUploadPhoto(ctx, s, m);
                            if (ctx.mounted) {
                              setSheet(() {
                                uploadingPhoto = false;
                                photoStatus = result.message;
                                photoUploadSucceeded = result.success;
                              });
                            }
                          },
                    icon: uploadingPhoto ? null : Icons.photo_outlined,
                    label: uploadingPhoto ? l.photoUploading : l.addPhoto,
                  ),
                ),
                if (m.avatarUrl != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: SecondaryButton(
                      onPressed: uploadingPhoto
                          ? null
                          : () {
                              s.setMemberAvatar(m, '');
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

Color _roleBg(BuildContext context, Role role) => switch (role) {
      Role.owner => context.successSoft,
      Role.admin => context.infoSoft,
      Role.adult => context.warningSoft,
      Role.contributor => context.primarySoft,
      Role.teen => context.infoSoft,
      Role.kid => context.accentSoft,
      Role.viewer => context.violetSoft,
    };

Future<void> _showRoleGuide(BuildContext context) => showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Who can do what?'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Family Owner',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              Text(
                  'Full family, money, member and ownership control. Can remove any other member.'),
              SizedBox(height: 12),
              Text('Family Admin',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              Text(
                  'Manages budgets, approvals and members. Can remove another member, but cannot transfer ownership or delete the family.'),
              SizedBox(height: 12),
              Text('Adult Member',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              Text(
                  'Adds personal transactions, savings goals and debts; can edit shopping lists. Cannot remove members.'),
              SizedBox(height: 12),
              Text('Contributor',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              Text(
                  'Adds personal transactions and contributes to existing savings records. Cannot remove members.'),
              SizedBox(height: 12),
              Text('Teen', style: TextStyle(fontWeight: FontWeight.w700)),
              Text(
                  'Uses transactions, budgets and savings according to the family permission switches. Cannot remove members.'),
              SizedBox(height: 12),
              Text('Kid', style: TextStyle(fontWeight: FontWeight.w700)),
              Text(
                  'Claims chores, makes requests and uses enabled child money features. Cannot remove members.'),
              SizedBox(height: 12),
              Text('Viewer', style: TextStyle(fontWeight: FontWeight.w700)),
              Text(
                  'Can view shared family information but cannot change money records or remove members.'),
              SizedBox(height: 16),
              Text('Removing family members',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              Text(
                  'Only the Family Owner or a Family Admin can remove another member. No one can remove themselves here, and the family must always keep at least one Owner or Admin.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );

Future<void> _showAdminRestriction(BuildContext context) => showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Family Admin permission needed'),
        content: const Text(
          'Only the Family Owner or a Family Admin can invite and manage family members.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );

/// Members, roles and family administration.
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
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            // ── Family identity ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
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
                          familyName,
                          style: TextStyle(
                            color: context.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l.membersCycleDesc(s.monthStartDay),
                          style:
                              TextStyle(color: context.inkSoft, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (s.canAdmin)
                    PopupMenuButton<String>(
                      color: context.card,
                      iconColor: context.ink,
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
            Center(
              child: TextButton.icon(
                onPressed: () => _showRoleGuide(context),
                icon: const Icon(Icons.shield_outlined, size: 18),
                label: const Text('See role permissions'),
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: kBRadiusM,
                border: Border.all(color: context.hairline),
              ),
              child: Row(
                children: [
                  Icon(Icons.groups_2_outlined, color: context.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.hasPlus
                              ? '${s.members.length} active family members · Plus'
                              : '${s.members.length} of $freeFamilyMemberLimit Free family members',
                          style: TextStyle(
                              color: context.ink, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.hasPlus
                              ? 'More than five members can join this Plus family.'
                              : 'Open invitations also reserve a place.',
                          style:
                              TextStyle(color: context.inkSoft, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  if (!s.hasPlus && s.members.length >= freeFamilyMemberLimit)
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PlusScreen()),
                      ),
                      child: const Text('Explore Mhuri Plus'),
                    ),
                ],
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
              onPressed: () {
                if (!s.canInvite) {
                  _showAdminRestriction(context);
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const InviteScreen()),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: context.primary,
                side: BorderSide(color: context.primary),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: kBRadiusM),
              ),
              icon: const Icon(Icons.person_add_alt_1, size: 19),
              label: Text(AppLocalizations.of(context)!.inviteTitle),
            ),
            const SizedBox(height: 24),
            Text('FAMILY',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: context.inkSoft, letterSpacing: 0.8)),
            const SizedBox(height: 4),
            _familyDestination(
              context,
              icon: Icons.task_alt_outlined,
              title: 'Tasks & responsibilities',
              subtitle:
                  '${s.familyTasks.where((task) => !task.isArchived && !task.isDone).length} open',
              screen: const FamilyTasksScreen(),
            ),
            _familyDestination(
              context,
              icon: Icons.workspace_premium_outlined,
              title: 'Points & rewards',
              subtitle: '${s.familyTaskPoints} family points',
              screen: const _PointsRewardsScreen(),
            ),
            _familyDestination(
              context,
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Family chat',
              subtitle: s.unreadChatCount > 0
                  ? '${s.unreadChatCount > 99 ? '99+' : s.unreadChatCount} unread ${s.unreadChatCount == 1 ? 'message' : 'messages'}'
                  : 'Messages and shared task discussions',
              screen: const FamilyChatScreen(),
              badgeCount: s.unreadChatCount,
            ),
            _familyDestination(
              context,
              icon: Icons.history_rounded,
              title: 'Family activity',
              subtitle: 'Money and family updates',
              screen: const ActivityScreen(),
            ),
            const SizedBox(height: 20),

            // ── Settings stubs ────────────────────────────────────────────
            Text(
              'SETTINGS',
              style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                  color: context.inkSoft),
            ),
            const SizedBox(height: 10),
            _settingAction(
              context,
              AppLocalizations.of(context)!.setCurrency,
              s.secondaryCurrency == null
                  ? '${s.primaryCurrency.short} · Single currency mode'
                  : '${s.primaryCurrency.short} primary · ${s.secondaryCurrency!.short} secondary · ${s.rateLabel}',
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
            if (s.isLive && s.shouldPromptFamilySetup) _spaceCard(context, s),
            _pinRow(context, s),
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

  Widget _familyDestination(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget screen,
    int badgeCount = 0,
  }) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        minTileHeight: 58,
        leading: Badge(
          isLabelVisible: badgeCount > 0,
          label: badgeCount > 0
              ? Text(badgeCount > 99 ? '99+' : '$badgeCount')
              : null,
          child: Icon(icon, color: context.primaryDark),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => screen),
        ),
      );

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
        shape: RoundedRectangleBorder(borderRadius: kBRadiusM),
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
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.spaceSetup,
              style: TextStyle(
                fontWeight: FontWeight.w700,
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _joinSpaceDialog(context, s),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.primary,
                  foregroundColor: context.onSolid,
                  shape: RoundedRectangleBorder(borderRadius: kBRadiusM),
                ),
                child: Text(AppLocalizations.of(context)!.joinWithCode),
              ),
            ),
            if (s.syncLastError != null &&
                (s.syncStatus == SyncStatus.error ||
                    s.syncStatus == SyncStatus.offline)) ...[
              const SizedBox(height: 10),
              Text(
                userFacingErrorMessage(
                  s.syncLastError,
                  fallback: AppLocalizations.of(context)!.syncProblem,
                ),
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
      SyncStatus.error => userFacingErrorMessage(
          s.syncLastError,
          fallback: AppLocalizations.of(context)!.syncProblem,
        ),
      SyncStatus.needsSignIn => AppLocalizations.of(context)!.signinExpired,
      _ => AppLocalizations.of(context)!.lastSync(lastText),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: Theme.of(context).brightness == Brightness.dark
              ? [context.card, context.primarySoft]
              : [context.primary, context.primaryDark],
        ),
        borderRadius: BorderRadius.circular(16),
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
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  s.inviteCode ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context)!.membersInviteHint,
            style: const TextStyle(
              color: Colors.white70,
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

  Future<void> _joinSpaceDialog(BuildContext context, AppState s) async {
    final l = AppLocalizations.of(context)!;
    final engine = s.sync;
    if (engine == null) return;
    final code = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: kBRadiusM),
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
              : userFacingErrorMessage(
                  s.syncLastError,
                  fallback: AppLocalizations.of(context)!.joinFail,
                ),
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
          shape: RoundedRectangleBorder(borderRadius: kBRadiusM),
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

  // Kept temporarily for compatibility with the existing deletion flow while
  // account controls are hosted by Settings.
  // ignore: unused_element
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
        borderRadius: BorderRadius.circular(16),
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
          shape: RoundedRectangleBorder(borderRadius: kBRadiusM),
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
          shape: RoundedRectangleBorder(borderRadius: kBRadiusM),
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
                          reauthError = userFacingErrorMessage(
                            auth.lastError,
                            fallback: l.authErrBadCredentials,
                          );
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
                    Icon(Icons.logout, size: 16, color: context.warning),
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
                    Icon(Icons.shield_outlined,
                        size: 16, color: context.incomeGreen),
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
                    disabledBackgroundColor: context.dangerSoft,
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
    final deletingUserId = auth.session?.userId;
    // Step 3 of 3 - progress while the server does the four phases; the
    // dialog is not dismissible and pops with the outcome.
    final deleted = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _DeleteProgressDialog(auth: auth),
        ) ??
        false;
    if (deleted) {
      await s.clearLocalAccountData(deletedUserId: deletingUserId);
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(userFacingErrorMessage(
          auth.lastError,
          fallback: l.deleteAccountFailed,
        )),
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
          footer: s.secondaryCurrency == null
              ? null
              : PrimaryButton(
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
                              fontWeight: FontWeight.w700,
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

class _PointsRewardsScreen extends StatelessWidget {
  const _PointsRewardsScreen();

  Future<void> _addReward(BuildContext context, AppState state) async {
    final name = TextEditingController();
    final cost = TextEditingController(text: '10');
    final note = TextEditingController();
    await showMhuriSheet<void>(
      context: context,
      builder: (sheetContext) => MhuriSheetShell(
        title: 'Add family reward',
        subtitle: 'Set a reward and how many approved points it costs.',
        footer: PrimaryButton(
          label: 'Save reward',
          onPressed: () {
            final points = int.tryParse(cost.text.trim());
            if (name.text.trim().isEmpty || points == null || points < 1) {
              return;
            }
            if (!state.addFamilyReward(
              name: name.text,
              pointsCost: points,
              description: note.text,
            )) {
              return;
            }
            Navigator.pop(sheetContext);
          },
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Reward name')),
          const SizedBox(height: 12),
          TextField(
              controller: cost,
              keyboardType: TextInputType.number,
              inputFormatters: integerInputFormatters,
              decoration: const InputDecoration(labelText: 'Points required')),
          const SizedBox(height: 12),
          TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Optional details')),
        ]),
      ),
    );
    name.dispose();
    cost.dispose();
    note.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final pointsByMember = <String, int>{
      for (final member in state.members)
        member.id: state.pointsForMember(member.id),
    };
    final ranking = state.members.toList()
      ..sort((a, b) =>
          (pointsByMember[b.id] ?? 0).compareTo(pointsByMember[a.id] ?? 0));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Points & rewards'),
        actions: [
          if (state.canApprove)
            IconButton(
              tooltip: 'Add reward',
              onPressed: () => _addReward(context, state),
              icon: const Icon(Icons.add_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text('Approved task points',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (var index = 0; index < ranking.length; index++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: SizedBox(
                width: 28,
                child: Text('${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              title: Text(ranking[index].name),
              trailing: Text('${pointsByMember[ranking[index].id] ?? 0} pts'),
            ),
          const Divider(height: 28),
          Text('Rewards', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (state.familyRewards.where((reward) => !reward.isArchived).isEmpty)
            Text(
              state.canApprove
                  ? 'Add a reward for family members to work toward.'
                  : 'No family rewards have been added yet.',
              style: TextStyle(color: context.inkSoft),
            ),
          for (final reward
              in state.familyRewards.where((item) => !item.isArchived))
            Builder(builder: (context) {
              final redeemedBy = reward.redeemedByMemberId == null
                  ? null
                  : state.member(reward.redeemedByMemberId!);
              final memberPoints = state.pointsForMember(state.realUser.id);
              final canRedeem = state.canSubmitFamilyTasks &&
                  reward.redeemedAt == null &&
                  memberPoints >= reward.pointsCost;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.card_giftcard_outlined),
                title: Text(reward.name),
                subtitle: Text(reward.description?.isNotEmpty == true
                    ? '${reward.description} · ${reward.pointsCost} pts'
                    : '${reward.pointsCost} pts'),
                trailing: reward.redeemedAt != null
                    ? Text('Redeemed by ${redeemedBy?.name ?? 'member'}')
                    : state.canApprove
                        ? IconButton(
                            tooltip: 'Archive reward',
                            onPressed: () => state.archiveFamilyReward(reward),
                            icon: const Icon(Icons.archive_outlined),
                          )
                        : state.canSubmitFamilyTasks
                            ? FilledButton.tonal(
                                onPressed: canRedeem
                                    ? () => state.redeemFamilyReward(reward)
                                    : null,
                                child: Text(canRedeem
                                    ? 'Redeem'
                                    : '${(reward.pointsCost - memberPoints).clamp(0, reward.pointsCost)} more'),
                              )
                            : null,
              );
            }),
        ],
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

class _MemberRow extends StatelessWidget {
  final Member m;

  const _MemberRow({required this.m});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final isMe = s.user.id == m.id;
    final canEditKid = s.canEditChildProfile(m);
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: kBRadiusM,
        border: Border.all(color: context.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Tooltip(
            message: 'View ${m.name} avatar',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => showProfileAvatarViewer(context, s, m),
              child: MemberAvatar(
                radius: 20,
                backgroundColor: _roleBg(context, m.role),
                icon: iconForKey(m.emoji) ?? kFallbackSemanticIcon,
                imageUrl: m.avatarUrl,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: isMe || canEditKid
                  ? () => _editProfileSheet(context, s, m)
                  : null,
              borderRadius: kBRadiusS,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            m.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
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
                              fontWeight: FontWeight.w700,
                            ),
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
          ),
          if (isMe || canEditKid)
            IconButton(
              tooltip: isMe ? 'Edit profile' : 'Edit ${m.name} profile',
              onPressed: () => _editProfileSheet(context, s, m),
              icon: const Icon(Icons.edit_outlined, size: 20),
            ),
          if (!isMe && s.canAdmin)
            PopupMenuButton<String>(
              tooltip: 'Manage ${m.name}',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (action) {
                if (action == 'make_owner') {
                  _makeOwner(context, s, m);
                } else {
                  _manageMember(context, s, m, action);
                }
              },
              itemBuilder: (_) => [
                if (s.canTransferOwnership && m.role == Role.adult)
                  PopupMenuItem(
                    value: 'make_owner',
                    child: Text(AppLocalizations.of(context)!.makeOwner),
                  ),
                if ((m.serverRole ?? m.role.name) == 'adult')
                  const PopupMenuItem(
                    value: 'promote',
                    child: Text('Make Family Admin'),
                  ),
                if ((m.serverRole ?? m.role.name) == 'adult')
                  const PopupMenuItem(
                    value: 'contributor',
                    child: Text('Change to Contributor'),
                  ),
                if ((m.serverRole ?? m.role.name) == 'contributor' ||
                    (m.serverRole ?? m.role.name) == 'co_parent')
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
            ),
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
    final targetRole = switch (action) {
      'promote' => 'co_parent',
      'contributor' => 'contributor',
      _ => 'adult',
    };
    try {
      await s.sync?.changeMemberRole(m.id, targetRole);
      messenger.showSnackBar(SnackBar(
        content: Text(switch (action) {
          'promote' => '${m.name} is now a Family Admin',
          'contributor' => '${m.name} is now a Contributor',
          _ => '${m.name} is now an Adult Member',
        }),
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
                    Icon(Icons.check_circle,
                        size: 18, color: context.incomeGreen)
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
