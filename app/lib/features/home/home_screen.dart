import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/money/money.dart';
import 'reminders_sheet.dart';
import '../../core/models/models.dart';
import '../../core/state/app_state.dart';
import '../../core/widgets/app_icons.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/tx_tile.dart';
import '../../core/widgets/ui.dart';
import '../activity/activity_screen.dart';
import '../budgets/budgets_screen.dart'
    show BudgetsScreen, showEnvelopeDetailSheet, showEditEnvelopeSheet;
import '../members/members_screen.dart';
import '../quickadd/quick_add_sheet.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';

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
          final compact = n.metrics.pixels > 34;
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
                // ── Header ──────────────────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$greet,',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: context.inkSoft,
                            ),
                          ),
                          Text(
                            u.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 27,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              color: context.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Report card: colorful badge - it leads to the app's charts,
                    // so the button itself carries the chart colors.
                    IconButton(
                      tooltip: AppLocalizations.of(context)!.reportCard,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const ReportsScreen()),
                      ),
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                              color: context.primarySoft, width: 1.4),
                        ),
                        child: _ReportsDonutGlyph(
                          colors: [
                            context.primary,
                            context.accent,
                            context.incomeGreen,
                            context.expenseRed,
                            context.primaryDark,
                            const Color(0xFF7EC8F2),
                            const Color(0xFFFF6B6B),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: AppLocalizations.of(context)!.remindersTitle,
                      onPressed: () => showRemindersSheet(context),
                      icon: Icon(Icons.notifications_none, color: context.ink),
                    ),
                    IconButton(
                      tooltip: AppLocalizations.of(context)!.settingsTitle,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()),
                      ),
                      icon: Icon(Icons.settings_outlined, color: context.ink),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Family is a first-class destination, separate from app
                // settings. Show the actual family name instead of a generic
                // label so its purpose is immediately clear.
                Material(
                  color: context.card,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MembersScreen()),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: context.hairline),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.groups_2_outlined,
                              size: 20, color: context.primary),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.familyTitle,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: context.inkSoft,
                                  ),
                                ),
                                Text(
                                  familyName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: context.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              size: 20, color: context.inkSoft),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Offline sync banner (outbox queue status) ─────────────────
                if (s.pendingOps > 0) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      s.syncNow();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text(AppLocalizations.of(context)!.allSynced),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: context.warningSoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.syncPill(s.pendingOps),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],

                // ── Family-setup nudge (skip-for-now limbo) ────────────────────
                if (!s.hasSpace)
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
                  const SizedBox(height: 22),
                  const _MonthlySummary(),
                  const SizedBox(height: 22),
                  _HomeBudgets(budgets: householdBudgets),
                  const _ComingUp(),
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

                // ── Recent activity ─────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.recentActivity,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: context.ink),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const ActivityScreen()),
                      ),
                      child: Text(AppLocalizations.of(context)!.seeAll),
                    ),
                  ],
                ),
                if (s.txs.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: context.hairline),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.noActivityYet,
                      style: TextStyle(
                          fontSize: 12.5, color: context.inkSoft, height: 1.4),
                    ),
                  ),
                for (final t in s.txs.take(3)) TxTile(tx: t, surface: false),

                const SizedBox(height: 8),
                const SmartCard(),
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
        _sectionTitle(context, 'Your family this month'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: kBRadiusL,
            border: Border.all(color: context.hairline),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SummaryStat(
                      label: 'Income',
                      value: value(income),
                      color: context.incomeGreen,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _SummaryStat(
                      label: 'Spent',
                      value: value(spent),
                      color: context.expenseRed,
                    ),
                  ),
                ],
              ),
              const Divider(height: 26),
              Row(
                children: [
                  Expanded(
                    child: _SummaryStat(
                      label: 'Saved',
                      value: value(saved),
                      color: context.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _SummaryStat(
                      label: 'Net remaining',
                      value: value(left),
                      color: left.minor < 0 ? context.expenseRed : context.ink,
                      emphasize: true,
                    ),
                  ),
                ],
              ),
              if (!masked) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.primarySoft,
                    borderRadius: kBRadiusS,
                  ),
                  child: Text(
                    _monthlyInsight(s),
                    style: TextStyle(
                      color: context.primaryDark,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _monthlyInsight(AppState s) {
    final budgets = s.envelopes.where((e) => !e.isPersonal).toList();
    final over = budgets.where((e) => s.remainingOn(e).minor < 0).toList();
    if (over.isNotEmpty) {
      return '${over.first.name} is over its budget. Open it to review your spending.';
    }
    final close = budgets.where((e) => s.paceOf(e) == Pace.watch).toList();
    if (close.isNotEmpty) {
      return '${close.first.name} is getting close to its limit.';
    }
    final upcoming = s.recurring.where((r) => r.active).toList()
      ..sort((a, b) => a.nextDue.compareTo(b.nextDue));
    if (upcoming.isNotEmpty) {
      final days = _daysUntil(upcoming.first.nextDue);
      return days <= 0
          ? '${upcoming.first.name} is due now.'
          : '${upcoming.first.name} is due in $days ${days == 1 ? 'day' : 'days'}.';
    }
    if (budgets.isNotEmpty) {
      final budget = budgets.first;
      final remaining = s.remainingOn(budget);
      return '${budget.name} has ${remaining.text} left this budget month.';
    }
    return 'Add a budget to give the money coming in a clear job.';
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.color,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool emphasize;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: context.inkSoft)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: emphasize ? 18 : 17,
                fontWeight: FontWeight.w800,
              ),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_awesome,
                    size: 20, color: context.primaryDark),
              ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionTitle(context, 'Your budgets')),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BudgetsScreen()),
              ),
              child: const Text('See all budgets'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
            final cardWidth =
                (constraints.maxWidth * 0.78).clamp(248.0, 320.0).toDouble();
            final carouselHeight =
                (166 + ((textScale - 1).clamp(0, 1) * 34)).toDouble();
            return SizedBox(
              height: carouselHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: budgets.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) => SizedBox(
                  width: cardWidth,
                  child: _HomeBudgetRow(budget: budgets[index]),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _HomeBudgetRow extends StatelessWidget {
  const _HomeBudgetRow({required this.budget});

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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(iconForKey(budget.emoji) ?? Icons.pie_chart_outline,
                      size: 19, color: context.primaryDark),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      budget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
              const SizedBox(height: 10),
              if (limit.minor <= 0 && spent.minor <= 0) ...[
                Text(
                  'No limit set',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.inkSoft,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap to set budget amount',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.primary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else ...[
                Text(
                  hidden
                      ? '••••• left'
                      : over
                          ? '${Money(-remaining.minor, remaining.currency).text} over budget'
                          : '${remaining.text} left',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: over ? context.expenseRed : context.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hidden
                      ? '••••• spent'
                      : '${spent.text} spent of ${limit.text}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.inkSoft, fontSize: 11.5),
                ),
              ],
              const SizedBox(height: 9),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0).toDouble(),
                  minHeight: 7,
                  backgroundColor: context.track,
                  color: over
                      ? context.expenseRed
                      : _paceColor(context, s.paceOf(budget)),
                ),
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

int _daysUntil(DateTime date) {
  final today = DateTime.now();
  return DateTime(date.year, date.month, date.day)
      .difference(DateTime(today.year, today.month, today.day))
      .inDays;
}

Widget _sectionTitle(BuildContext context, String text) => Text(
      text.toUpperCase(),
      style: TextStyle(
        color: context.inkSoft,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.0,
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
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [context.primary, context.primaryDark],
            ),
            borderRadius: kBRadiusL,
            boxShadow: const [
              BoxShadow(
                color: Color(0x470E7C66), // kPrimary @ 28 %
                blurRadius: 26,
                offset: Offset(0, 10),
              ),
            ],
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
              const SizedBox(height: 8),
              _amount(primary, '•••••', s.hideAmounts, s.displayCurrency.short),
              if (hasDual && secondary != null) ...[
                const SizedBox(height: 5),
                Semantics(
                  button: true,
                  label: AppLocalizations.of(context)!.swapCurrency,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      s.toggleDisplayCurrency();
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      child: Text(
                        s.hideAmounts ? '≈ •••••' : '≈ ${secondary.text}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Material(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(30),
                child: InkWell(
                  onTap: () => _showFlexibleSpendBreakdown(context, s),
                  borderRadius: BorderRadius.circular(30),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            'Available today: '
                            '${s.hideAmounts ? '•••••' : s.safeToSpend.text}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.info_outline,
                            color: Colors.white70, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Visible affordance: the whole card opens Reports (eye = hide/show only).
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      AppLocalizations.of(context)!.viewDetails,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      size: 16, color: Colors.white70),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _amount(Money? live, String maskedText, bool masked, String label) =>
      Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: masked || live == null
                ? Text(
                    maskedText,
                    style: MhuriType.display.copyWith(color: Colors.white),
                  )
                : CountUpText(
                    amount: live,
                    style: MhuriType.display.copyWith(color: Colors.white),
                  ),
          ),
        ],
      );
}

// ── Envelope chip ───────────────────────────────────────────────────────────

// ignore: unused_element
class _EnvChip extends StatelessWidget {
  final Envelope e;

  const _EnvChip({required this.e});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final spent = s.spentOn(e);
    final limit = s.effectiveLimit(e);
    final value = limit.minor <= 0 ? 0.0 : spent.minor / limit.minor;
    final pace = s.paceOf(e);

    return Semantics(
      button: true,
      label: e.name,
      child: Material(
        color: context.card,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            if (e.limit.minor <= 0 && s.canEditBudgets) {
              showEditEnvelopeSheet(context, s, e);
            } else {
              showEnvelopeDetailSheet(context, e);
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: 150,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: Icon(
                      iconForKey(e.emoji) ?? Icons.savings,
                      size: 17,
                      color: context.primaryDark,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    e.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.ink),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: value.clamp(0.0, 1.0).toDouble(),
                      minHeight: 6,
                      backgroundColor: context.track,
                      color: _paceColor(context, pace),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${(value * 100).round()}%',
                    style: TextStyle(fontSize: 11, color: context.inkSoft),
                  ),
                ],
              ),
            ),
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
        borderRadius: BorderRadius.circular(20),
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

// ── Reports badge glyph - mini "where the money went" donut ─────────────────
// Same palette, same order as the Reports screen donut; equal arcs with small
// gaps so it reads as a colorful chart at 20px.

class _ReportsDonutGlyph extends StatelessWidget {
  const _ReportsDonutGlyph({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(22),
      painter: _ReportsDonutPainter(colors),
    );
  }
}

class _ReportsDonutPainter extends CustomPainter {
  _ReportsDonutPainter(this.colors);

  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 4.2;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    const gap = 0.14; // radians between segments
    final sweep = (2 * math.pi - gap * colors.length) / colors.length;
    var start = -math.pi / 2;
    for (final c in colors) {
      paint.color = c;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(_ReportsDonutPainter old) => old.colors != colors;
}
