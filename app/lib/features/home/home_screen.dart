import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/money/money.dart';
import 'reminders_sheet.dart';
import '../../core/models/models.dart';
import '../../core/state/app_state.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/widgets/app_icons.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/motion.dart';
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
    builder: (sheetContext) => _FamilySpaceSwitcher(state: s),
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
        content: Text(widget.state.sync?.lastError ??
            'Could not switch families. Please try again.'),
      ));
    }
  }

  Future<void> _createFamily() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create another family'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Family name'),
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
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
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
        content:
            Text(widget.state.sync?.lastError ?? 'Could not create family.'),
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
        content: Text(widget.state.sync?.lastError ?? 'Could not join family.'),
      ));
    }
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
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Switch family',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
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
                        onTap: _switching || selected
                            ? null
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
                                          fontWeight: FontWeight.w800,
                                          color: context.ink)),
                                  const SizedBox(height: 2),
                                  Text(
                                    _displayFamilyRole(space.role),
                                    style: TextStyle(
                                        fontSize: 12, color: context.inkSoft),
                                  ),
                                ],
                              ),
                            ),
                            if (selected)
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
                                            fontWeight: FontWeight.w800,
                                            color: context.onSolid)),
                                  ],
                                ),
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
                  fontWeight: FontWeight.w800,
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
            onTap: _switching
                ? null
                : () {
                    Navigator.pop(context);
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const MembersScreen(),
                    ));
                  },
          ),
        ],
      ),
    );
  }
}

String _displayFamilyRole(String role) => role
    .split('_')
    .map((part) => part.isEmpty
        ? part
        : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
    .join(' ');

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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
                // ── Preview banner ("Preview as…") ──────────────────────────
                if (s.isPreviewing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
                      decoration: BoxDecoration(
                        color: context.warningSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.accentSoft),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.visibility,
                              size: 16, color: context.accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context)!
                                  .previewBanner(u.name),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: context.ink,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => s.exitPreview(),
                            child: Text(
                              AppLocalizations.of(context)!.previewExit,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: context.ink),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // ── Compact Header ──────────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _showFamilySpaceSwitcher(context, s),
                        borderRadius: kBRadiusS,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              MemberAvatar(
                                key: const ValueKey('home_signed_in_avatar'),
                                radius: 18,
                                backgroundColor: context.primarySoft,
                                icon: iconForKey(u.emoji) ?? Icons.person,
                                imageUrl: u.avatarUrl,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            familyName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 17,
                                              height: 1.15,
                                              fontWeight: FontWeight.w700,
                                              color: context.ink,
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        Icon(Icons.keyboard_arrow_down_rounded,
                                            size: 18, color: context.inkSoft),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$greet, ${u.name}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: context.inkSoft,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Quick Chat Icon
                    IconButton(
                      tooltip: 'Family chat',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const FamilyChatScreen()),
                      ),
                      icon: Badge(
                        isLabelVisible: s.unreadChatCount > 0,
                        label: s.unreadChatCount > 0
                            ? Text(s.unreadChatCount > 99
                                ? '99+'
                                : '${s.unreadChatCount}')
                            : null,
                        child: Icon(Icons.chat_bubble_outline_rounded,
                            size: 22, color: context.ink),
                      ),
                    ),
                    // Bell / Notifications
                    IconButton(
                      tooltip: AppLocalizations.of(context)!.remindersTitle,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => showRemindersSheet(context),
                      icon: Badge(
                        isLabelVisible: s.unreadNotificationCount > 0,
                        label: s.unreadNotificationCount > 0
                            ? Text(s.unreadNotificationCount > 99
                                ? '99+'
                                : '${s.unreadNotificationCount}')
                            : null,
                        child: Icon(Icons.notifications_none,
                            size: 22, color: context.ink),
                      ),
                    ),
                    // Settings
                    IconButton(
                      tooltip: AppLocalizations.of(context)!.settingsTitle,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()),
                      ),
                      icon: Icon(Icons.settings_outlined,
                          size: 22, color: context.ink),
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
                                    fontWeight: FontWeight.w800,
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
                  const _FirstStepsCard()
                else ...[
                  AnimatedScale(
                    scale: _poolCompact ? 0.97 : 1.0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    child: const _PoolCard(),
                  ),
                  const _MonthlySummary(),
                  const _NeedsAttention(),
                  const _ComingUp(),
                  // ── Today Section (Family Tasks due today/overdue) ──────────
                  Builder(
                    builder: (ctx) {
                      final now = DateTime.now();
                      final todayTasks = s.familyTasks
                          .where((t) =>
                              !t.isArchived &&
                              !t.isDone &&
                              (t.dueDate == null ||
                                  t.dueDate!.isBefore(DateTime(
                                      now.year, now.month, now.day + 1))))
                          .take(3)
                          .toList();
                      if (todayTasks.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionLabel(
                            title: 'Today\'s tasks',
                            actionLabel: 'See all',
                            onAction: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const FamilyTasksScreen()),
                            ),
                            padding: const EdgeInsets.only(top: 14, bottom: 6),
                          ),
                          for (int i = 0; i < todayTasks.length; i++)
                            _HomeTaskRow(
                              task: todayTasks[i],
                              isLast: i == todayTasks.length - 1,
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
                for (final t in s.txs.take(3)) TxTile(tx: t, surface: false),
                const SizedBox(height: 12),
              ],
            )),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(
            'This month',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: context.ink,
              letterSpacing: -0.2,
            ),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _SummaryStat(
                label: 'Income',
                value: value(income),
                color: context.incomeGreen,
              ),
            ),
            Container(
              height: 28,
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: context.hairline.withValues(alpha: 0.7),
            ),
            Expanded(
              child: _SummaryStat(
                label: 'Spent',
                value: value(spent),
                color: context.expenseRed,
              ),
            ),
            Container(
              height: 28,
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: context.hairline.withValues(alpha: 0.7),
            ),
            Expanded(
              child: _SummaryStat(
                label: 'Remaining',
                value: value(left),
                color: left.minor < 0 ? context.expenseRed : context.ink,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NeedsAttention extends StatelessWidget {
  const _NeedsAttention();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final budgets = s.envelopes.where((e) => !e.isPersonal).toList();
    final over = budgets.where((e) => s.remainingOn(e).minor < 0).toList();
    final close = budgets.where((e) => s.paceOf(e) == Pace.watch).toList();
    final upcoming = s.recurring.where((r) => r.active).toList()
      ..sort((a, b) => a.nextDue.compareTo(b.nextDue));

    String? warning;
    VoidCallback? onTap;

    if (over.isNotEmpty) {
      final b = over.first;
      warning = '${b.name} is over budget';
      onTap = () => showEnvelopeDetailSheet(context, b);
    } else if (close.isNotEmpty) {
      final b = close.first;
      warning = '${b.name} is close to its limit';
      onTap = () => showEnvelopeDetailSheet(context, b);
    } else if (upcoming.isNotEmpty) {
      final r = upcoming.first;
      final days = _daysUntil(r.nextDue);
      if (days <= 0) {
        warning = '${r.name} is due now';
      } else if (days <= 2) {
        warning = '${r.name} is due in $days ${days == 1 ? 'day' : 'days'}';
      }
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: warning == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Material(
                color: context.warningSoft,
                borderRadius: kBRadiusM,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: kBRadiusM,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
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
                                warning,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: context.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (onTap != null)
                          Icon(Icons.chevron_right,
                              size: 18, color: context.inkSoft),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: context.inkSoft,
            ),
          ),
        ],
      );
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
              Icon(Icons.auto_awesome, size: 22, color: context.primaryDark),
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
                        fontWeight: FontWeight.w800,
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
                      fontWeight: FontWeight.w800,
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
                    Icon(iconForKey(b.emoji) ?? Icons.pie_chart_outline,
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
                  fontWeight: FontWeight.w800,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          title: 'Budgets',
          actionLabel: 'See all',
          onAction: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BudgetsScreen()),
          ),
          padding: const EdgeInsets.only(top: 18, bottom: 8),
        ),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, index) => SizedBox(
              width: (MediaQuery.sizeOf(context).width * 0.72)
                  .clamp(240.0, 300.0)
                  .toDouble(),
              child: _HomeBudgetCard(budget: sorted[index]),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _HomeBudgetCard extends StatelessWidget {
  const _HomeBudgetCard({required this.budget});

  final Envelope budget;

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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    iconForKey(budget.emoji) ?? Icons.pie_chart_outline_rounded,
                    size: 16,
                    color: over ? context.expenseRed : context.primaryDark,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      budget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      hidden
                          ? '•••••'
                          : over
                              ? '${Money(-remaining.minor, remaining.currency).text} over'
                              : limit.minor <= 0
                                  ? 'No limit'
                                  : '${remaining.text} left',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: over ? context.expenseRed : context.ink,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              MhuriProgress(
                progress: ratio,
                height: 4,
                color: over
                    ? context.expenseRed
                    : _paceColor(context, s.paceOf(budget)),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      hidden ? '•••••' : '${spent.text} spent',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.inkSoft,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      limit.minor <= 0
                          ? 'Tap to set'
                          : hidden
                              ? 'of •••••'
                              : 'of ${limit.text}',
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: limit.minor <= 0
                            ? context.primary
                            : context.inkSoft,
                        fontSize: 11,
                        fontWeight: limit.minor <= 0
                            ? FontWeight.w600
                            : FontWeight.w400,
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
}

class _ComingUp extends StatelessWidget {
  const _ComingUp();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final upcoming = s.recurring.where((r) => r.active).toList()
      ..sort((a, b) => a.nextDue.compareTo(b.nextDue));
    if (upcoming.isEmpty) return const SizedBox.shrink();
    final rule = upcoming.first;
    final days = _daysUntil(rule.nextDue);
    final due = days < 0
        ? '${-days} ${days == -1 ? 'day' : 'days'} overdue'
        : days == 0
            ? 'due today'
            : 'due in $days ${days == 1 ? 'day' : 'days'}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(context, 'Coming up'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: context.card,
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
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5)),
                      Text(
                        '${s.hideAmounts ? '•••••' : rule.amount.text} · $due',
                        style:
                            TextStyle(color: context.inkSoft, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
                  onTap: () {
                    HapticFeedback.lightImpact();
                    s.toggleFamilyTaskCompletion(task);
                  },
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
                            if (task.dueDate != null) 'Due today',
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

Widget _sectionTitle(BuildContext context, String text) => Text(
      text,
      style: TextStyle(
        color: context.ink,
        fontSize: 16,
        fontWeight: FontWeight.w700,
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
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.primaryDark,
            borderRadius: kBRadiusL,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.availableToSpendLabel,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: s.hideAmounts
                        ? AppLocalizations.of(context)!.showAmountsTip
                        : AppLocalizations.of(context)!.hideAmountsTip,
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      s.setHideAmounts(!s.hideAmounts);
                    },
                    icon: Icon(
                      s.hideAmounts ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white70,
                      size: 19,
                    ),
                  ),
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
                        style: MhuriType.display.copyWith(color: Colors.white),
                      )
                    : CountUpText(
                        amount: primary,
                        style: MhuriType.display.copyWith(color: Colors.white),
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
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              // Available today as clean, quiet supporting line
              InkWell(
                onTap: () => _showFlexibleSpendBreakdown(context, s),
                borderRadius: kBRadiusXS,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          '${s.hideAmounts ? '•••••' : s.safeToSpend.text} Available today',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.info_outline,
                          color: Colors.white60, size: 14),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // View details affordance
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Flexible(
                    child: Text(
                      AppLocalizations.of(context)!.viewDetails,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 14, color: Colors.white70),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showFlexibleSpendBreakdown(BuildContext context, AppState s) {
  final l = AppLocalizations.of(context)!;
  final cur = s.displayCurrency;
  final available = s.availableToSpend(cur);
  final reserved = s.reservedForEnvelopes.inCurrency(cur, s.rate);
  final free = Money(
    math.max(0, available.minor - reserved.minor),
    cur,
  );

  showMhuriSheet<void>(
    context: context,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SheetHeader(
            l.flexibleSpendTitle,
            onClose: () => Navigator.pop(sheetContext),
          ),
          Text(
            l.flexibleSpendExplanation,
            style: TextStyle(color: sheetContext.inkSoft, height: 1.4),
          ),
          const SizedBox(height: 18),
          _breakdownRow(sheetContext, l.availableToSpendLabel, available.text),
          _breakdownRow(
            sheetContext,
            l.reservedForEnvelopes,
            '-${reserved.text}',
          ),
          const Divider(height: 24),
          _breakdownRow(
            sheetContext,
            l.freeAfterCommitments,
            free.text,
          ),
          const SizedBox(height: 4),
          Text(
            l.daysRemaining(s.daysLeftInCycle),
            style: TextStyle(color: sheetContext.inkSoft),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: sheetContext.primarySoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              l.safeToSpend(s.safeToSpend.text),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: sheetContext.primaryDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _breakdownRow(BuildContext context, String label, String value) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
              child: Text(label, style: TextStyle(color: context.inkSoft))),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(color: context.ink, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );

Color _paceColor(BuildContext context, Pace p) => switch (p) {
      Pace.onTrack => context.primary,
      Pace.watch => context.accent,
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

    // 1c. Recurring expense due soon (C7) - review, post or skip
    final dueRule = s.dueRecurring.isEmpty ? null : s.dueRecurring.first;
    if (dueRule != null) {
      return _card(
        context,
        color: context.violetSoft,
        icon: Icons.push_pin,
        title: '${dueRule.name} - ${dueRule.amount.text}',
        subtitle: AppLocalizations.of(context)!.recDueSub(
            dueRule.nextDue.isBefore(DateTime.now())
                ? AppLocalizations.of(context)!.dueNow
                : AppLocalizations.of(context)!.dueSoon),
        actionLabel: AppLocalizations.of(context)!.post,
        onTap: () {
          s.postRecurring(dueRule);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.postedSnack(dueRule.name),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
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
    return _card(
      context,
      color: context.violetSoft,
      icon: Icons.autorenew,
      title: AppLocalizations.of(context)!
          .circleTitle(s.circle.currentRound, s.circle.totalRounds),
      subtitle: AppLocalizations.of(context)!.circleSub(s.circle.nextCollector,
          s.circle.contribution.text, s.circle.potSoFar.text),
      actionLabel: AppLocalizations.of(context)!.markCollected,
      onTap: () {
        HapticFeedback.lightImpact();
        s.circleCollect();
        celebrate(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.roundOk),
            behavior: SnackBarBehavior.floating,
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
                    fontWeight: FontWeight.w800,
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
