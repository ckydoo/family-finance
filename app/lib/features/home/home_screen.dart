import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/money/money.dart';
import 'reminders_sheet.dart';
import '../../core/models/models.dart';
import '../../core/state/app_state.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/widgets/app_icons.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_messages.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/ring_progress.dart';
import '../../core/widgets/tx_tile.dart';
import '../../core/widgets/ui.dart';
import '../activity/activity_screen.dart';
import '../budgets/budgets_screen.dart'
    show BudgetsScreen, showEnvelopeDetailSheet, showEditEnvelopeSheet;
import '../family_chat/family_chat_screen.dart';
import '../family_tasks/family_tasks_screen.dart';
import '../members/members_screen.dart';
import '../quickadd/quick_add_sheet.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';

Future<void> _showFamilySpaceSwitcher(BuildContext context, AppState s) async {
  final sync = s.sync;
  if (sync == null) {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MembersScreen()),
    );
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.bg,
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: 0.9,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: _FamilySpaceSwitcher(state: s),
        ),
      ),
    ),
  );
}

class _FamilySpaceSwitcher extends StatefulWidget {
  const _FamilySpaceSwitcher({required this.state});
  final AppState state;

  @override
  State<_FamilySpaceSwitcher> createState() => _FamilySpaceSwitcherState();
}

class _FamilySpaceSwitcherState extends State<_FamilySpaceSwitcher> {
  late Future<List<FamilySpaceSummary>> _spaces;
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _spaces = widget.state.sync!.listFamilySpaces();
  }

  Future<void> _switch(FamilySpaceSummary space) async {
    if (_switching) return;
    setState(() => _switching = true);
    final ok = await widget.state.sync!.switchFamilySpace(space);
    if (!mounted) return;
    setState(() => _switching = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(userFacingErrorMessage(
          widget.state.sync?.lastError,
          fallback: 'Could not switch families. Please try again.',
        )),
      ));
    }
  }

  Future<void> _createFamily() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _CreateFamilyDialog(),
    );
    if (name == null || name.isEmpty || !mounted) return;
    setState(() => _switching = true);
    final ok = await widget.state.sync!.createSpace(
      name,
      preferredName: widget.state.user.name,
      baseCurrency: widget.state.primaryCurrency.code,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _switching = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(userFacingErrorMessage(
          widget.state.sync?.lastError,
          fallback: 'Could not create family.',
        )),
      ));
    }
  }

  Future<void> _joinFamily() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Join another family'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Invite code'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.isEmpty || !mounted) return;
    setState(() => _switching = true);
    final ok = await widget.state.sync!.joinSpace(code);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _switching = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(userFacingErrorMessage(
          widget.state.sync?.lastError,
          fallback: 'Could not join family.',
        )),
      ));
    }
  }

  Future<void> _signOut() async {
    final auth = widget.state.auth;
    if (auth == null || auth.busy || _switching) return;
    final confirmed = await confirmDialog(
      context,
      title: 'Sign out?',
      body:
          'Are you sure you want to sign out? You can sign in again to return to your family space.',
      confirmLabel: AppLocalizations.of(context)!.signOut,
      danger: true,
    );
    if (!confirmed || !mounted) return;
    Navigator.pop(context);
    await auth.signOut();
  }

  Future<void> _openManageFamily() async {
    if (_switching || !mounted) return;
    final navigator = Navigator.of(context);
    navigator.pop();
    await navigator.push<void>(
      MaterialPageRoute(builder: (_) => const MembersScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeId = widget.state.sync?.spaceId;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FAMILY SPACES',
                      style: TextStyle(
                        color: context.primary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Switch family',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 5),
                    Text('Choose the family space you want to use.',
                        style: TextStyle(
                            fontSize: 13,
                            color: context.inkSoft,
                            height: 1.35)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: _switching ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FutureBuilder<List<FamilySpaceSummary>>(
            future: _spaces,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: context.hairline),
                    borderRadius: kBRadiusM,
                  ),
                  child: Column(children: [
                    const Text('Families could not be loaded.'),
                    TextButton(
                      onPressed: () => setState(_reload),
                      child: const Text('Try again'),
                    ),
                  ]),
                );
              }
              final spaces = snapshot.data ?? const <FamilySpaceSummary>[];
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 286),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: spaces.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final space = spaces[index];
                    final selected = space.id == activeId;
                    return Material(
                      color: selected
                          ? context.primary.withValues(alpha: 0.07)
                          : context.card,
                      borderRadius: kBRadiusM,
                      child: InkWell(
                        borderRadius: kBRadiusM,
                        onTap: _switching
                            ? null
                            : selected
                                ? _openManageFamily
                                : () => _switch(space),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 13),
                          decoration: BoxDecoration(
                            borderRadius: kBRadiusM,
                            border: Border.all(
                              color: selected
                                  ? context.primary.withValues(alpha: 0.5)
                                  : context.hairline,
                              width: selected ? 1.2 : 1,
                            ),
                          ),
                          child: Row(children: [
                            Icon(Icons.family_restroom_rounded,
                                size: 25,
                                color: selected
                                    ? context.primary
                                    : context.inkSoft),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(space.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: context.ink)),
                                  const SizedBox(height: 2),
                                  Text(
                                    selected
                                        ? '${_displayFamilyRole(space.role)} · Tap to manage'
                                        : _displayFamilyRole(space.role),
                                    style: TextStyle(
                                        fontSize: 12, color: context.inkSoft),
                                  ),
                                ],
                              ),
                            ),
                            if (selected)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 9, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: context.primary,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_rounded,
                                            size: 13, color: context.onSolid),
                                        const SizedBox(width: 4),
                                        Text('Current',
                                            style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: context.onSolid)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.chevron_right_rounded,
                                      size: 20, color: context.inkSoft),
                                ],
                              )
                            else
                              Icon(Icons.chevron_right_rounded,
                                  color: context.inkSoft),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text('ADD A FAMILY',
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: context.inkSoft)),
          const SizedBox(height: 9),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _switching ? null : _joinFamily,
                icon: const Icon(Icons.group_add_outlined),
                label: const Text('Join with code'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _switching ? null : _createFamily,
                icon: const Icon(Icons.add_home_outlined),
                label: const Text('Create family'),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            minTileHeight: 50,
            leading: const Icon(Icons.manage_accounts_outlined),
            title: const Text('Manage current family'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _switching ? null : _openManageFamily,
          ),
          if (widget.state.auth?.isLoggedIn ?? false)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              minTileHeight: 50,
              leading: Icon(Icons.logout_rounded, color: context.danger),
              title: Text(
                AppLocalizations.of(context)!.signOut,
                style: TextStyle(
                  color: context.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: widget.state.auth!.busy || _switching ? null : _signOut,
            ),
        ],
      ),
    );
  }
}

class _CreateFamilyDialog extends StatefulWidget {
  const _CreateFamilyDialog();

  @override
  State<_CreateFamilyDialog> createState() => _CreateFamilyDialogState();
}

class _CreateFamilyDialogState extends State<_CreateFamilyDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Enter a family name');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Create another family'),
        content: TextField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Family name',
            errorText: _error,
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _submit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _submit,
            child: const Text('Create'),
          ),
        ],
      );
}

String _displayFamilyRole(String role) => role
    .split('_')
    .map((part) => part.isEmpty
        ? part
        : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
    .join(' ');

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.tourOverviewKey,
    this.tourFamilyKey,
  });

  final Key? tourOverviewKey;
  final Key? tourFamilyKey;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _poolCompact = false;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final u = s.user;
    final hour = DateTime.now().hour;
    final l = AppLocalizations.of(context)!;
    final householdBudgets =
        s.envelopes.where((envelope) => !envelope.isPersonal).toList();
    final isNewHousehold = s.isGuidedHomeActive;
    final greet = hour < 12
        ? l.greetingMorning
        : hour < 19
            ? l.greetingAfternoon
            : l.greetingEvening;
    final syncedFamilyName = s.spaceName?.trim();
    final familyName = syncedFamilyName != null && syncedFamilyName.isNotEmpty
        ? syncedFamilyName
        : s.space.name;

    return SafeArea(
      // G10: the pool card compresses subtly as content scrolls under it.
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is! ScrollUpdateNotification) return false;
          final pixels = n.metrics.pixels;
          final compact = _poolCompact ? pixels > 25 : pixels > 50;
          if (compact != _poolCompact) setState(() => _poolCompact = compact);
          return false;
        },
        child: RefreshIndicator(
            onRefresh: () => s.refresh(),
            child: ListView(
              padding: kTabPageInsets,
              children: [
                // ── Compact Header ──────────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: InkWell(
                        key: widget.tourFamilyKey,
                        onTap: () => _showFamilySpaceSwitcher(context, s),
                        borderRadius: kBRadiusS,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Tooltip(
                                message: 'View profile avatar',
                                child: InkWell(
                                  key: const ValueKey('home_signed_in_avatar'),
                                  customBorder: const CircleBorder(),
                                  onTap: () =>
                                      showProfileAvatarViewer(context, s),
                                  child: MemberAvatar(
                                    radius: 18,
                                    backgroundColor: context.primarySoft,
                                    icon: iconForKey(u.emoji) ??
                                        kFallbackSemanticIcon,
                                    imageUrl: u.avatarUrl,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$greet, ${u.name}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 16.5,
                                        height: 1.15,
                                        fontWeight: FontWeight.w500,
                                        color: context.ink,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            familyName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w400,
                                              color: context.inkSoft,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 1),
                                        Icon(Icons.keyboard_arrow_down_rounded,
                                            size: 16, color: context.inkSoft),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Keep the identity copy visually separate from the action
                    // cluster. Long member/space names stay inside the Expanded
                    // area above and ellipsize before reaching this gutter.
                    SizedBox(
                      width: 8,
                      height: 26,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 1,
                          height: 18,
                          color: context.hairline.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    _PremiumHeaderAction(
                      tooltip: 'Family chat',
                      icon: Icons.chat_bubble_outline_rounded,
                      badgeCount: s.unreadChatCount,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const FamilyChatScreen()),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _PremiumHeaderAction(
                      tooltip: AppLocalizations.of(context)!.remindersTitle,
                      icon: Icons.notifications_none,
                      badgeCount: s.unreadNotificationCount,
                      onTap: () => showRemindersSheet(context),
                    ),
                    const SizedBox(width: 6),
                    _PremiumHeaderAction(
                      tooltip: AppLocalizations.of(context)!.settingsTitle,
                      icon: Icons.settings_outlined,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()),
                      ),
                    ),
                  ],
                ),
                // ── Family-setup nudge (skip-for-now limbo) ────────────────────
                if (s.shouldPromptFamilySetup)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Material(
                      color: context.card,
                      borderRadius: kBRadiusM,
                      child: InkWell(
                        onTap: s.reopenFamilySetup,
                        borderRadius: kBRadiusM,
                        splashColor: context.primarySoft,
                        highlightColor: context.primarySoft,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: kBRadiusM,
                            border:
                                Border.all(color: context.primary, width: 1.2),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.family_restroom,
                                  size: 20, color: context.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  AppLocalizations.of(context)!.setupBanner,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: context.ink,
                                      height: 1.35),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                AppLocalizations.of(context)!.setupBannerCta,
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: context.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 18),

                if (isNewHousehold)
                  KeyedSubtree(
                    key: widget.tourOverviewKey,
                    child: const _FirstStepsCard(),
                  )
                else ...[
                  KeyedSubtree(
                    key: widget.tourOverviewKey,
                    child: AnimatedScale(
                      scale: _poolCompact ? 0.97 : 1.0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      child: const _PoolCard(),
                    ),
                  ),
                  const _CycleBoundaryNotice(),
                  const _MonthlySummary(),
                  const _NeedsAttention(),
                  const _ComingUp(),
                ],
                if (!isNewHousehold) ...[
                  // ── Today Section (Family Tasks due today/overdue) ──────────
                  Builder(
                    builder: (ctx) {
                      final dueTasks = s.familyTasks
                          .where((t) =>
                              !t.isArchived && !t.isDone && t.dueDate != null)
                          .toList()
                        ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
                      final homeTasks = dueTasks.take(2).toList();
                      if (homeTasks.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionLabel(
                            title: 'Tasks coming up',
                            actionLabel: 'See all',
                            onAction: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const FamilyTasksScreen()),
                            ),
                            padding: const EdgeInsets.only(top: 14, bottom: 6),
                          ),
                          for (int i = 0; i < homeTasks.length; i++)
                            _HomeTaskRow(
                              task: homeTasks[i],
                              isLast: i == homeTasks.length - 1,
                            ),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  ),
                ],

                if (s.pendingOps > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 6),
                    child: Row(
                      children: [
                        Icon(Icons.cloud_off,
                            size: 13, color: context.inkFaint),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            l.syncPill(s.pendingOps),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: context.inkFaint,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (!isNewHousehold) _HomeBudgets(budgets: householdBudgets),

                const SizedBox(height: 8),
                const SmartCard(),

                // Activity intentionally closes the page: the current money
                // position and budgets come first, then the audit trail.
                SectionLabel(
                  title: AppLocalizations.of(context)!.recentActivity,
                  actionLabel: AppLocalizations.of(context)!.seeAll,
                  onAction: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ActivityScreen()),
                  ),
                  padding: const EdgeInsets.only(top: 14, bottom: 6),
                ),
                if (s.txs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      AppLocalizations.of(context)!.noActivityYet,
                      style: TextStyle(
                          fontSize: 12.5, color: context.inkSoft, height: 1.4),
                    ),
                  ),
                for (final t in s.txs.take(6)) TxTile(tx: t, surface: false),
                const SizedBox(height: 12),
              ],
            )),
      ),
    );
  }
}

class _CycleBoundaryNotice extends StatelessWidget {
  const _CycleBoundaryNotice();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final startsToday = state.isCycleStartToday;
    final endsTomorrow = state.daysUntilNextCycle == 1;
    if (!startsToday && !endsTomorrow) return const SizedBox.shrink();

    final nextDate = DateFormat.yMMMd().format(state.nextCycleStart);
    final title = startsToday
        ? 'A new budget month starts today'
        : 'Your budget month ends tomorrow';
    final message = startsToday
        ? 'Cycle totals restarted today, so income and spending may show 0 until new activity is recorded. Your available balance, rollover budgets and history are unchanged.'
        : 'Your next cycle starts $nextDate. Income, spending and reset budgets will start fresh; your available balance, rollover budgets and history will remain.';

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: startsToday ? context.infoSoft : context.accentSoft,
          borderRadius: kBRadiusM,
          border: Border.all(
            color: startsToday ? context.information : context.accentDark,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              startsToday
                  ? Icons.refresh_rounded
                  : Icons.event_available_outlined,
              size: 21,
              color: startsToday ? context.information : context.accentDark,
            ),
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
                    message,
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
      ),
    );
  }
}

class _PremiumHeaderAction extends StatelessWidget {
  const _PremiumHeaderAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final badgeLabel = badgeCount > 99 ? '99+' : '$badgeCount';
    final badgeWidth = switch (badgeLabel.length) {
      1 => 22.0,
      2 => 26.0,
      _ => 32.0,
    };
    return Tooltip(
      message: tooltip,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [context.card, context.bg],
              ),
              border: Border.all(color: context.hairline),
              boxShadow: [
                BoxShadow(
                  color: context.shadowColor.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.22),
                  blurRadius: 1,
                  offset: const Offset(-1, -1),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                splashColor: context.primary.withValues(alpha: 0.12),
                child: Center(
                  child: Icon(icon, size: 19, color: context.ink),
                ),
              ),
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              right: -6,
              top: -6,
              child: SizedBox(
                width: badgeWidth,
                height: 22,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.accentDark,
                    shape: badgeLabel.length == 1
                        ? BoxShape.circle
                        : BoxShape.rectangle,
                    borderRadius: badgeLabel.length == 1
                        ? null
                        : BorderRadius.circular(11),
                    border: Border.all(color: context.card, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      badgeLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? context.onSolid
                            : Colors.white,
                        fontSize: 10,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Plain-language monthly overview ─────────────────────────────────────────

class _MonthlySummary extends StatelessWidget {
  const _MonthlySummary();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final income = s.monthIncome;
    final spent = s.monthSpend;
    final saved = s.monthSaved;
    final left = Money(
      income.minor - spent.minor - saved.minor,
      s.displayCurrency,
    );
    final masked = s.hideAmounts;

    String value(Money amount) => masked ? '•••••' : amount.text;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth =
              ((constraints.maxWidth - 16) / 3).clamp(92.0, 180.0);
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(children: [
              _SummaryStat(
                  width: cardWidth,
                  label: 'Income',
                  value: value(income),
                  icon: Icons.arrow_upward_rounded,
                  color: context.incomeGreen),
              const SizedBox(width: 8),
              _SummaryStat(
                  width: cardWidth,
                  label: 'Spent',
                  value: value(spent),
                  icon: Icons.arrow_downward_rounded,
                  color: context.expenseRed),
              const SizedBox(width: 8),
              _SummaryStat(
                  width: cardWidth,
                  label: 'Remaining',
                  value: value(left),
                  icon: Icons.savings_outlined,
                  color: left.minor < 0 ? context.expenseRed : context.primary),
            ]),
          );
        },
      ),
    );
  }
}

class _NeedsAttention extends StatefulWidget {
  const _NeedsAttention();

  @override
  State<_NeedsAttention> createState() => _NeedsAttentionState();
}

class _NeedsAttentionState extends State<_NeedsAttention> {
  final Set<String> _dismissedKeys = {};

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final budgets = s.envelopes.where((e) => !e.isPersonal).toList();
    final issues = [
      for (final budget in budgets)
        if (s.paceOf(budget) == Pace.over || s.paceOf(budget) == Pace.watch)
          (budget, s.paceOf(budget)),
    ]..sort((a, b) {
        if (a.$2 == b.$2) return 0;
        return a.$2 == Pace.over ? -1 : 1;
      });
    final activeKeys = issues.map((issue) => _issueKey(issue.$1, issue.$2));
    _dismissedKeys.removeWhere((key) => !activeKeys.contains(key));
    final visibleIssues = issues
        .where(
            (issue) => !_dismissedKeys.contains(_issueKey(issue.$1, issue.$2)))
        .toList();
    if (visibleIssues.isEmpty) return const SizedBox.shrink();

    final message = visibleIssues.length == 1
        ? _attentionMessage(visibleIssues.single.$1, visibleIssues.single.$2)
        : '${visibleIssues.length}+ budgets need attention';
    final currentIssue = visibleIssues.first;
    final alertColor = context.warningSoft;

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Dismissible(
          key: ValueKey(
              'needs-attention-${_issueKey(currentIssue.$1, currentIssue.$2)}'),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => setState(() {
            _dismissedKeys.add(_issueKey(currentIssue.$1, currentIssue.$2));
          }),
          background: _dismissBackground(context),
          child: Material(
            color: alertColor,
            borderRadius: kBRadiusM,
            child: InkWell(
              onTap: () => _openAttentionIssues(context, visibleIssues),
              borderRadius: kBRadiusM,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 18, color: context.expenseRed),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Needs attention',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: context.inkSoft,
                            ),
                          ),
                          Text(
                            message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Review',
                      style: TextStyle(
                        color: context.primaryDark,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _issueKey(Envelope envelope, Pace pace) =>
      '${envelope.id}:${pace.name}';

  String _attentionMessage(Envelope envelope, Pace pace) => switch (pace) {
        Pace.over => '${envelope.name} is over budget',
        Pace.watch => '${envelope.name} may exceed its budget this cycle',
        Pace.onTrack || Pace.reached => '',
      };

  void _openAttentionIssues(
    BuildContext context,
    List<(Envelope, Pace)> issues,
  ) {
    if (issues.length == 1) {
      showEnvelopeDetailSheet(context, issues.single.$1);
      return;
    }

    showMhuriSheet<void>(
      context: context,
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.75,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Budgets to review',
                style: TextStyle(
                  color: context.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    for (final (envelope, pace) in issues)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(envelope.name),
                        subtitle: Text(_attentionMessage(envelope, pace)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          showEnvelopeDetailSheet(context, envelope);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _dismissBackground(BuildContext context) => Container(
      alignment: AlignmentDirectional.centerEnd,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: context.inkSoft,
        borderRadius: kBRadiusM,
      ),
      child: Icon(Icons.visibility_off_outlined, color: context.onSolid),
    );

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final compact = width < 112;
    return Container(
      width: width,
      height: 104,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 11,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: kBRadiusL,
        border: Border.all(color: context.hairline.withValues(alpha: 0.7)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: compact ? 19 : 21, color: color),
        SizedBox(height: compact ? 5 : 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: compact ? 10.5 : 11.5,
            fontWeight: FontWeight.w500,
            color: context.inkSoft,
          ),
        ),
        const SizedBox(height: 1),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(value,
              style: TextStyle(
                  color: context.ink,
                  fontSize: compact ? 13.5 : 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: compact ? -0.35 : -0.2)),
        ),
      ]),
    );
  }
}

class _FirstStepsCard extends StatelessWidget {
  const _FirstStepsCard();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final householdBudgets =
        s.envelopes.where((envelope) => !envelope.isPersonal).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: kBRadiusL,
        border: Border.all(color: context.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.family_restroom_rounded,
                  size: 22, color: context.primaryDark),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to Mhuri',
                      style: TextStyle(
                        color: context.ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Your family workspace is ready',
                      style: TextStyle(
                        color: context.inkSoft,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Follow these simple steps to start managing money together:',
            style: TextStyle(color: context.inkSoft, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          _stepRow(
            context,
            number: '1',
            title: 'Add money coming in',
            subtitle: 'Log salary, business earnings or family funds.',
            buttonLabel: 'Add income',
            buttonIcon: Icons.add,
            onPressed: () => showQuickAdd(context, initialType: TxType.income),
          ),
          const SizedBox(height: 12),
          _stepRow(
            context,
            number: '2',
            title: 'Set your budgets',
            subtitle: 'Decide how much you want to spend this month.',
            buttonLabel: 'Set up budgets',
            buttonIcon: Icons.tune,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BudgetsScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _stepRow(
            context,
            number: '3',
            title: 'Record what you spend',
            subtitle: 'Keep everyone on the same page as you buy things.',
            buttonLabel: 'Add expense',
            buttonIcon: Icons.receipt_long,
            onPressed: () => showQuickAdd(context, initialType: TxType.expense),
          ),
          if (householdBudgets.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'YOUR BUDGETS',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                      color: context.inkSoft,
                    ),
                  ),
                ),
                Text(
                  '${householdBudgets.length} starter areas',
                  style: TextStyle(fontSize: 11, color: context.inkSoft),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final b in householdBudgets)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: context.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.hairline),
                ),
                child: Row(
                  children: [
                    Icon(iconForKey(b.emoji) ?? kFallbackSemanticIcon,
                        size: 18, color: context.primaryDark),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: context.ink,
                            ),
                          ),
                          Text(
                            b.limit.minor <= 0
                                ? 'No limit set'
                                : '${b.limit.text} limit',
                            style: TextStyle(
                              fontSize: 11,
                              color: b.limit.minor <= 0
                                  ? context.inkSoft
                                  : context.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => showEditEnvelopeSheet(context, s, b),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            b.limit.minor <= 0 ? 'Set amount' : 'Edit',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: context.primary,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.chevron_right,
                              size: 14, color: context.primary),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: () => s.dismissGettingStarted(),
              icon: Icon(Icons.visibility_off_outlined,
                  size: 16, color: context.inkSoft),
              label: Text(
                'Hide getting started',
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepRow(
    BuildContext context, {
    required String number,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required IconData buttonIcon,
    required VoidCallback onPressed,
  }) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.hairline),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Text(
                number,
                style: TextStyle(
                  color: context.primaryDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: context.inkSoft, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              icon: Icon(buttonIcon, size: 14),
              label: Text(buttonLabel),
            ),
          ],
        ),
      );
}

class _HomeBudgets extends StatelessWidget {
  const _HomeBudgets({required this.budgets});

  final List<Envelope> budgets;

  @override
  Widget build(BuildContext context) {
    if (budgets.isEmpty) return const SizedBox.shrink();
    final s = AppScope.of(context);

    // Sort to highlight budgets running out first:
    // 1. Over budget (most negative remaining first)
    // 2. Limited budgets sorted by remaining ratio ascending (least remaining % first)
    // 3. Lowest remaining minor balance
    // 4. Unbudgeted / zero-limit envelopes at the end
    final sorted = List<Envelope>.from(budgets)
      ..sort((a, b) {
        final aRem = s.remainingOn(a).minor;
        final bRem = s.remainingOn(b).minor;
        final aOver = aRem < 0;
        final bOver = bRem < 0;

        // Both over budget: the one over by more comes first
        if (aOver && bOver) return aRem.compareTo(bRem);
        if (aOver != bOver) return aOver ? -1 : 1;

        final aLimit = s.effectiveLimit(a).minor;
        final bLimit = s.effectiveLimit(b).minor;
        final aHasLimit = aLimit > 0;
        final bHasLimit = bLimit > 0;

        // Limited envelopes come before unconfigured ones
        if (aHasLimit && bHasLimit) {
          final aRatio = aRem / aLimit;
          final bRatio = bRem / bLimit;
          final cmp = aRatio.compareTo(bRatio);
          if (cmp != 0) return cmp;
        } else if (aHasLimit != bHasLimit) {
          return aHasLimit ? -1 : 1;
        }

        return aRem.compareTo(bRem);
      });
    final allUnconfigured =
        sorted.every((budget) => s.effectiveLimit(budget).minor <= 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          title: 'Budgets',
          actionLabel: 'See all',
          onAction: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BudgetsScreen()),
          ),
          padding: const EdgeInsets.only(top: 8, bottom: 8),
        ),
        SizedBox(
          height: (allUnconfigured ? 132.0 : 160.0) +
              ((MediaQuery.textScalerOf(context).scale(13) / 13 - 1)
                      .clamp(0.0, 0.8) *
                  44),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, index) => SizedBox(
              width: (MediaQuery.sizeOf(context).width * 0.38)
                  .clamp(136.0, 172.0)
                  .toDouble(),
              child: _HomeBudgetCard(
                budget: sorted[index],
                compactEmpty: allUnconfigured,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _HomeBudgetCard extends StatelessWidget {
  const _HomeBudgetCard({
    required this.budget,
    required this.compactEmpty,
  });

  final Envelope budget;
  final bool compactEmpty;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final spent = s.spentOn(budget);
    final limit = s.effectiveLimit(budget);
    final remaining = s.remainingOn(budget);
    final ratio = limit.minor <= 0 ? 0.0 : spent.minor / limit.minor;
    final over = remaining.minor < 0;
    final hidden = s.hideAmounts;

    return Material(
      color: context.card,
      borderRadius: kBRadiusM,
      child: InkWell(
        onTap: () {
          if (budget.limit.minor <= 0 && s.canEditBudgets) {
            showEditEnvelopeSheet(context, s, budget);
          } else {
            showEnvelopeDetailSheet(context, budget);
          }
        },
        borderRadius: kBRadiusM,
        child: Container(
          padding: EdgeInsets.all(compactEmpty ? 10 : 12),
          decoration: BoxDecoration(
            borderRadius: kBRadiusM,
            border: Border.all(
              color: over
                  ? context.expenseRed.withValues(alpha: 0.3)
                  : context.hairline.withValues(alpha: 0.5),
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Center(
                child: RingProgress(
                  value: ratio,
                  size: compactEmpty ? 44 : 58,
                  stroke: compactEmpty ? 5 : 6,
                  color: over
                      ? context.expenseRed
                      : _paceColor(context, s.paceOf(budget)),
                  child: Text(
                    limit.minor <= 0
                        ? '—'
                        : '${(ratio * 100).clamp(0, 999).round()}%',
                    style: TextStyle(
                      color: over ? context.expenseRed : context.ink,
                      fontSize: compactEmpty ? 12.5 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(height: compactEmpty ? 7 : 9),
              Row(
                children: [
                  Icon(
                    iconForKey(budget.emoji) ?? kFallbackSemanticIcon,
                    size: 18,
                    color: over ? context.expenseRed : context.primaryDark,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      budget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: context.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              SizedBox(height: compactEmpty ? 5 : 8),
              Text(
                limit.minor <= 0
                    ? 'Tap to set a limit'
                    : hidden
                        ? '••••• of •••••'
                        : '${spent.text} / ${limit.text}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.inkSoft, fontSize: 11),
              ),
              if (!compactEmpty) ...[
                const Spacer(),
                MhuriProgress(
                  progress: ratio,
                  height: 5,
                  color: over
                      ? context.expenseRed
                      : _paceColor(context, s.paceOf(budget)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ComingUp extends StatefulWidget {
  const _ComingUp();

  @override
  State<_ComingUp> createState() => _ComingUpState();
}

class _ComingUpState extends State<_ComingUp> {
  final Set<String> _dismissedIds = {};

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final upcoming = s.recurring
        .where((r) => r.active && !_dismissedIds.contains(r.id))
        .toList()
      ..sort((a, b) => a.nextDue.compareTo(b.nextDue));
    if (upcoming.isEmpty) return const SizedBox.shrink();
    final rule = upcoming.first;
    final hiddenCount = upcoming.length - 1;
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(context, 'Coming up'),
          const SizedBox(height: 8),
          Dismissible(
            key: ValueKey('coming-up-${rule.id}'),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => setState(() => _dismissedIds.add(rule.id)),
            background: _dismissBackground(context),
            child: _ComingUpCard(rule: rule),
          ),
          if (hiddenCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 1, bottom: 4),
              child: Text(
                '$hiddenCount more coming up',
                style: TextStyle(fontSize: 11.5, color: context.inkSoft),
              ),
            ),
        ],
      ),
    );
  }
}

class _ComingUpCard extends StatelessWidget {
  const _ComingUpCard({required this.rule});

  final RecurringRule rule;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final days = _daysUntil(rule.nextDue);
    final actionable = days <= 3;
    final due = days < 0
        ? '${-days} ${days == -1 ? 'day' : 'days'} overdue'
        : days == 0
            ? 'due today'
            : 'due in $days ${days == 1 ? 'day' : 'days'}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: days < 0 ? context.dangerSoft : context.card,
        borderRadius: kBRadiusM,
      ),
      child: Row(
        children: [
          Icon(Icons.event_outlined, color: context.primary, size: 21),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rule.name,
                    style: TextStyle(
                        color: context.ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5)),
                Text(
                  '${s.hideAmounts ? '•••••' : rule.amount.text} · $due',
                  style: TextStyle(color: context.inkSoft, fontSize: 11.5),
                ),
              ],
            ),
          ),
          if (actionable) ...[
            const SizedBox(width: 10),
            FilledButton(
              onPressed: () {
                s.postRecurring(rule);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(context)!.postedSnack(rule.name),
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: context.primaryDark,
                foregroundColor: context.onSolid,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                minimumSize: const Size(0, 42),
                shape: RoundedRectangleBorder(borderRadius: kBRadiusM),
              ),
              child: Text(
                AppLocalizations.of(context)!.post,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeTaskRow extends StatelessWidget {
  const _HomeTaskRow({required this.task, this.isLast = false});

  final FamilyTask task;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final assignee = task.assigneeMemberId != null
        ? s.members.cast<Member?>().firstWhere(
              (m) => m?.id == task.assigneeMemberId,
              orElse: () => null,
            )
        : null;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FamilyTasksScreen()),
      ),
      borderRadius: kBRadiusS,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: s.canManageFamilyTasks
                      ? () {
                          HapticFeedback.lightImpact();
                          s.toggleFamilyTaskCompletion(task);
                        }
                      : null,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(
                      task.isDone
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: task.isDone ? context.primary : context.inkSoft,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: task.isDone ? context.inkSoft : context.ink,
                          decoration:
                              task.isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (assignee != null || task.dueDate != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (assignee != null) assignee.name,
                            if (task.dueDate != null)
                              _homeTaskDueLabel(task.dueDate!),
                          ].join(' · '),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.inkSoft,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (task.points > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.accentSoft,
                      borderRadius: kBRadiusXS,
                    ),
                    child: Text(
                      '+${task.points} pts',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.ink,
                      ),
                    ),
                  ),
              ],
            ),
            if (!isLast)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Divider(
                  height: 1,
                  thickness: 0.8,
                  color: context.hairline.withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

int _daysUntil(DateTime date) {
  final today = DateTime.now();
  return DateTime(date.year, date.month, date.day)
      .difference(DateTime(today.year, today.month, today.day))
      .inDays;
}

String _homeTaskDueLabel(DateTime date) {
  final days = _daysUntil(date);
  if (days < 0) return '${-days} ${days == -1 ? 'day' : 'days'} overdue';
  if (days == 0) return 'Due today';
  if (days == 1) return 'Due tomorrow';
  return 'Due ${DateFormat('MMM d').format(date.toLocal())}';
}

Widget _sectionTitle(BuildContext context, String text) => Text(
      text,
      style: TextStyle(
        color: context.ink,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );

// ── Family Pool card ────────────────────────────────────────────────────────

class _PoolCard extends StatelessWidget {
  const _PoolCard();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final primary = s.availableToSpend(s.displayCurrency);
    final hasDual = s.activeCurrencies.length > 1;
    final secondary =
        hasDual ? s.availableToSpend(s.otherCurrency(s.displayCurrency)) : null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPlus = s.hasPlus;
    final gradientColors = isPlus
        ? (isDark
            ? const [Color(0xFF443621), Color(0xFF192333)]
            : const [Color(0xFF17283D), Color(0xFF624C2F)])
        : (isDark
            ? [context.primarySoft, context.card]
            : [context.primaryDark, context.primary]);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ReportsScreen()),
        ),
        borderRadius: kBRadiusL,
        splashColor: Colors.white24,
        highlightColor: Colors.white10,
        child: Container(
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: kBRadiusL,
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: context.primaryDark.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              const Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _BalanceCardPainter()),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          AppLocalizations.of(context)!.availableToSpendLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? context.ink
                                    : Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          tooltip: s.hideAmounts
                              ? AppLocalizations.of(context)!.showAmountsTip
                              : AppLocalizations.of(context)!.hideAmountsTip,
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            s.setHideAmounts(!s.hideAmounts);
                          },
                          icon: Icon(
                            s.hideAmounts
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? context.ink
                                    : Colors.white70,
                            size: 18,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (isPlus) const _PlusMark(),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Simplified hero balance
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: s.hideAmounts
                        ? Text(
                            '•••••',
                            style: MhuriType.display.copyWith(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? context.ink
                                  : Colors.white,
                              fontSize: 31,
                              letterSpacing: -0.8,
                            ),
                          )
                        : CountUpText(
                            amount: primary,
                            style: MhuriType.display.copyWith(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? context.ink
                                  : Colors.white,
                              fontSize: 31,
                              letterSpacing: -0.8,
                            ),
                          ),
                  ),
                  if (hasDual && secondary != null) ...[
                    const SizedBox(height: 4),
                    Semantics(
                      button: true,
                      label: AppLocalizations.of(context)!.swapCurrency,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          s.toggleDisplayCurrency();
                        },
                        borderRadius: kBRadiusXS,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            s.hideAmounts ? '≈ •••••' : '≈ ${secondary.text}',
                            style: TextStyle(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? context.ink
                                  : Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // View details affordance
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          AppLocalizations.of(context)!.viewDetails,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? context.ink
                                    : Colors.white70,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded,
                          size: 14,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? context.ink
                              : Colors.white70),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlusMark extends StatelessWidget {
  const _PlusMark();

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Mhuri Plus active',
        child: Container(
          key: const ValueKey('home_plus_mark'),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: context.accent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.workspace_premium_rounded,
                  size: 13, color: Color(0xFF17283D)),
              SizedBox(width: 4),
              Text(
                'PLUS',
                style: TextStyle(
                  color: Color(0xFF17283D),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      );
}

class _BalanceCardPainter extends CustomPainter {
  const _BalanceCardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          kAccent.withValues(alpha: 0.28),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.92, size.height * 0.16),
        radius: size.width * 0.34,
      ));
    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.16),
      size.width * 0.34,
      glow,
    );

    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final accent = Paint()
      ..color = kAccent.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    final wave = Path()
      ..moveTo(size.width * 0.47, size.height)
      ..cubicTo(
        size.width * 0.65,
        size.height * 0.92,
        size.width * 0.68,
        size.height * 0.36,
        size.width,
        size.height * 0.39,
      );
    canvas.drawPath(wave, line);

    final goldWave = Path()
      ..moveTo(size.width * 0.66, size.height)
      ..cubicTo(
        size.width * 0.79,
        size.height * 0.79,
        size.width * 0.82,
        size.height * 0.48,
        size.width,
        size.height * 0.58,
      );
    canvas.drawPath(goldWave, accent);
  }

  @override
  bool shouldRepaint(_BalanceCardPainter oldDelegate) => false;
}

Color _paceColor(BuildContext context, Pace p) => switch (p) {
      Pace.onTrack => context.primary,
      Pace.watch => context.accent,
      Pace.reached => context.accent,
      Pace.over => context.danger,
    };

// ── Smart card (contextual nudge slot) ──────────────────────────────────────

class SmartCard extends StatelessWidget {
  const SmartCard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);

    // 1. Pending kid request → parent approval flow (spec §3.3)
    KidRequest? pending;
    for (final r in s.requests) {
      if (r.state == RequestState.pending) {
        pending = r;
        break;
      }
    }
    if (pending != null) {
      final kid = s.member(pending.kidId);
      return _card(
        context,
        color: context.warningSoft,
        icon: Icons.volunteer_activism,
        title: AppLocalizations.of(context)!.requestTitle(
            kid?.name ?? AppLocalizations.of(context)!.yourChild,
            pending.amount.text),
        subtitle: pending.reason,
        actionLabel: AppLocalizations.of(context)!.review,
        onTap: () => _reviewRequest(context, s, pending!),
      );
    }

    // 1b. Pending teen proposal (spec H2) → enters the budget on approval
    Proposal? proposal;
    for (final p in s.proposals) {
      if (p.state == RequestState.pending) {
        proposal = p;
        break;
      }
    }
    if (proposal != null) {
      final teen = s.member(proposal.teenId);
      final env = s.envelope(proposal.envelopeId);
      return _card(
        context,
        color: context.infoSoft,
        icon: Icons.confirmation_number,
        title: AppLocalizations.of(context)!
            .proposalTitle(teen?.name ?? 'Zoe', proposal.amount.text),
        subtitle: AppLocalizations.of(context)!.proposalSub(proposal.reason,
            env?.name ?? AppLocalizations.of(context)!.envelopeLabel),
        actionLabel: AppLocalizations.of(context)!.review,
        onTap: () => _reviewProposal(context, s, proposal!),
      );
    }

    // 2. Chores waiting for parent confirmation
    Chore? waiting;
    for (final c in s.chores) {
      if (c.state == ChoreState.waiting) {
        waiting = c;
        break;
      }
    }
    if (waiting != null) {
      return _card(
        context,
        color: context.successSoft,
        icon: Icons.auto_awesome,
        title: AppLocalizations.of(context)!.choreDoneTitle(waiting.name),
        subtitle: AppLocalizations.of(context)!.choreDoneSub(waiting.stars),
        actionLabel: AppLocalizations.of(context)!.confirm,
        onTap: () {
          HapticFeedback.mediumImpact();
          s.confirmChore(waiting!);
          celebrate(context); // G11: stars rain for the kid who did it
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(AppLocalizations.of(context)!.starsGiven(waiting.stars)),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: AppLocalizations.of(context)!.undo,
                onPressed: () => s.unconfirmChore(waiting!),
              ),
            ),
          );
        },
      );
    }

    // 3. Savings circle turn - OPT-IN: hidden until the family turns
    // mukando on (Savings tab or Settings).
    if (!s.mukandoEnabled) return const SizedBox.shrink();
    if (!s.circle.isConfigured) {
      return _card(
        context,
        color: context.violetSoft,
        icon: Icons.autorenew,
        title: 'Mukando savings circle',
        subtitle: 'Configure members, amounts and collection order to start.',
        actionLabel: 'Set up',
        onTap: () {
          DefaultTabController.maybeOf(context)?.animateTo(2);
        },
      );
    }
    final paidCount =
        s.circle.participantIds.where((id) => s.hasMukandoPaid(id)).length;
    final canComplete = s.currentMukandoRoundComplete;

    return _card(
      context,
      color: context.violetSoft,
      icon: Icons.autorenew,
      title: AppLocalizations.of(context)!
          .circleTitle(s.circle.currentRound, s.circle.totalRounds),
      subtitle: AppLocalizations.of(context)!.circleSub(s.circle.nextCollector,
          s.circle.contribution.text, s.circle.roundPot.text),
      actionLabel: canComplete
          ? AppLocalizations.of(context)!.markCollected
          : '$paidCount/${s.circle.participantIds.length} paid',
      onTap: () {
        if (!canComplete) {
          DefaultTabController.maybeOf(context)?.animateTo(2);
          return;
        }
        HapticFeedback.lightImpact();
        s.circleCollect(id: 'mukando_round_${s.circle.currentRound + 1}');
        celebrate(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.roundOk),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: AppLocalizations.of(context)!.undo,
              onPressed: s.undoCircleCollect,
            ),
          ),
        );
      },
    );
  }

  void _reviewRequest(BuildContext context, AppState s, KidRequest r) {
    final kid = s.member(r.kidId);
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final approvedMessage = l.approvedReq(
      r.amount.text,
      kid?.name ?? l.yourChild,
    );
    final inkSoft = context.inkSoft;
    final primary = context.primary;
    final onSolid = context.onSolid;
    bool handled = false;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${kid?.name ?? 'Kid'} requests ${r.amount.text}'),
        content: Text(r.reason),
        actions: [
          TextButton(
            onPressed: () {
              if (handled) return;
              handled = true;
              final navigator = Navigator.of(ctx);
              navigator.pop();
              s.declineRequest(r);
            },
            child: Text(l.notThisWeek, style: TextStyle(color: inkSoft)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: onSolid,
            ),
            onPressed: () {
              if (handled) return;
              handled = true;
              final navigator = Navigator.of(ctx);
              HapticFeedback.lightImpact();
              navigator.pop();
              s.approveRequest(r);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(approvedMessage),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text(l.approve),
          ),
        ],
      ),
    );
  }

  void _reviewProposal(BuildContext context, AppState s, Proposal p) {
    final teen = s.member(p.teenId);
    final env = s.envelope(p.envelopeId);
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final approvedMessage = l.approvedProp(
      p.amount.text,
      env?.name ?? l.envelopeLabel,
    );
    final inkSoft = context.inkSoft;
    final primary = context.primary;
    final onSolid = context.onSolid;
    bool handled = false;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l.proposalTitle(teen?.name ?? 'Zoe', p.amount.text)),
        content: Text(l.declineBody(p.reason, env?.name ?? '-')),
        actions: [
          TextButton(
            onPressed: () {
              if (handled) return;
              handled = true;
              final navigator = Navigator.of(ctx);
              navigator.pop();
              s.declineProposal(p);
            },
            child: Text(l.decline, style: TextStyle(color: inkSoft)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: onSolid,
            ),
            onPressed: () {
              if (handled) return;
              handled = true;
              final navigator = Navigator.of(ctx);
              HapticFeedback.lightImpact();
              navigator.pop();
              s.approveProposal(p);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(approvedMessage),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text(l.approve),
          ),
        ],
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: kBRadiusM,
      ),
      child: Row(
        children: [
          Icon(icon, size: 26, color: context.ink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: context.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: context.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.ink,
              foregroundColor: context.onSolid,
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
