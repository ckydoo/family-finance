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
import '../activity/activity_screen.dart';
import '../members/members_screen.dart';
import '../reports/reports_screen.dart';

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
    final greet =
        hour < 12 ? l.greetingMorning : hour < 19 ? l.greetingAfternoon : l.greetingEvening;

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
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greet, ${u.name}',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: context.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Family switcher: a visible, tappable pill — the
                    // affordance was invisible as a bare avatar row.
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MembersScreen(),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: context.hairline),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < s.members.take(5).length; i++)
                              Transform.translate(
                                offset: Offset(-6.0 * i, 0),
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: _avatarBg(s.members[i].role),
                                  child: Icon(
                                    iconForKey(s.members[i].emoji) ??
                                        Icons.person,
                                    size: 14,
                                    color: context.ink,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 2),
                            Icon(Icons.person_add_alt_1,
                                size: 15, color: context.primary),
                            const SizedBox(width: 4),
                            Text(
                              AppLocalizations.of(context)!.familyCta,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                size: 16, color: context.inkSoft),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Report card: colorful badge — it leads to the app's charts,
              // so the button itself carries the chart colors.
              IconButton(
                tooltip: AppLocalizations.of(context)!.reportCard,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ReportsScreen()),
                ),
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: context.primarySoft, width: 1.4),
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
            ],
          ),

          // ── Offline sync banner (demo of the outbox queue) ─────────────
          if (s.pendingOps > 0) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                s.syncNow();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context)!.allSynced),
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
                  color: const Color(0xFFFDF1DA),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  AppLocalizations.of(context)!.syncPill(s.pendingOps),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A6116),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // ── Family Pool ─────────────────────────────────────────────────
          AnimatedScale(
            scale: _poolCompact ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: const _PoolCard(),
          ), // G10

          const SizedBox(height: 16),

          // ── Envelope chips ──────────────────────────────────────────────
          SizedBox(
            height: 122,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final e in s.envelopes.where((e) => !e.isPersonal).take(4))
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _EnvChip(e: e),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

                    if (s.pendingOps > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.cloud_off, size: 13, color: context.inkFaint),
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.ink),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ActivityScreen()),
                ),
                child: Text(AppLocalizations.of(context)!.seeAll),
              ),
            ],
          ),
          for (final t in s.txs.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TxTile(tx: t),
            ),

          const SizedBox(height: 8),
          const SmartCard(),
        ],
      )),
      ),
    );
  }

  Color _avatarBg(Role role) => switch (role) {
        Role.owner => const Color(0xFFD9EDE8),
        Role.adult => const Color(0xFFFBE7C6),
        Role.teen => const Color(0xFFDCEBFA),
        Role.kid => const Color(0xFFFFF1C9),
        Role.viewer => const Color(0xFFEFE3F7),
      };
}

// ── Family Pool card ────────────────────────────────────────────────────────

class _PoolCard extends StatelessWidget {
  const _PoolCard();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final primary = s.poolCombined(s.displayCurrency);
    final secondary = s.poolCombined(s.displayCurrency.other);

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
        boxShadow: [
          BoxShadow(
            color: context.primary.withValues(alpha: 0.28),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.familyPool,
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                tooltip: s.hideAmounts ? AppLocalizations.of(context)!.showAmountsTip : AppLocalizations.of(context)!.hideAmountsTip,
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _amount(primary, '•••••', s.hideAmounts, s.displayCurrency.short),
              ),
              IconButton(
                tooltip: AppLocalizations.of(context)!.swapCurrency,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  s.toggleDisplayCurrency();
                },
                icon: const Icon(Icons.swap_horiz, color: Colors.white),
              ),
              Expanded(
                child: _amount(secondary, '•••••', s.hideAmounts, s.displayCurrency.other.short),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              AppLocalizations.of(context)!
                  .safeToSpend(s.hideAmounts ? '•••••' : s.safeToSpend.text),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
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
              const Icon(Icons.chevron_right, size: 16, color: Colors.white70),
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

class _EnvChip extends StatelessWidget {
  final Envelope e;

  const _EnvChip({required this.e});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final spent = s.spentOn(e);
    final value =
        e.limit.minor <= 0 ? 0.0 : spent.minor / e.limit.minor;
    final pace = s.paceOf(e);

    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Color(0xFFEDF4F1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
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
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.ink),
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
            '${(value.clamp(0.0, 1.5) * 100).round()}%',
            style: TextStyle(fontSize: 11, color: context.inkSoft),
          ),
        ],
      ),
    );
  }
}

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
      return _card(context,
        color: const Color(0xFFFBE7C6),
        icon: Icons.volunteer_activism,
        title: AppLocalizations.of(context)!.requestTitle(kid?.name ?? AppLocalizations.of(context)!.yourChild, pending.amount.text),
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
      return _card(context,
        color: const Color(0xFFDCEBFA),
        icon: Icons.confirmation_number,
        title: AppLocalizations.of(context)!.proposalTitle(teen?.name ?? 'Zoe', proposal.amount.text),
        subtitle: AppLocalizations.of(context)!.proposalSub(proposal.reason, env?.name ?? AppLocalizations.of(context)!.envelopeLabel),
        actionLabel: AppLocalizations.of(context)!.review,
        onTap: () => _reviewProposal(context, s, proposal!),
      );
    }

    // 1c. Recurring expense due soon (C7) — review, post or skip
    final dueRule = s.dueRecurring.isEmpty ? null : s.dueRecurring.first;
    if (dueRule != null) {
      return _card(context,
        color: const Color(0xFFE8E4F7),
        icon: Icons.push_pin,
        title: '${dueRule.name} — ${dueRule.amount.text}',
        subtitle: AppLocalizations.of(context)!.recDueSub(dueRule.nextDue.isBefore(DateTime.now()) ? AppLocalizations.of(context)!.dueNow : AppLocalizations.of(context)!.dueSoon),
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
      return _card(context,
        color: const Color(0xFFD9EDE8),
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
              content: Text(AppLocalizations.of(context)!.starsGiven(waiting.stars)),
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

    // 3. Savings circle turn
    return _card(context,
      color: const Color(0xFFEFE3F7),
      icon: Icons.autorenew,
      title:
          AppLocalizations.of(context)!.circleTitle(s.circle.currentRound, s.circle.totalRounds),
      subtitle: AppLocalizations.of(context)!.circleSub(s.circle.nextCollector, s.circle.contribution.text, s.circle.potSoFar.text),
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
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${kid?.name ?? 'Kid'} requests ${r.amount.text}'),
        content: Text(r.reason),
        actions: [
          TextButton(
            onPressed: () {
              s.declineRequest(r);
              Navigator.pop(ctx);
            },
            child: Text(AppLocalizations.of(context)!.notThisWeek, style: TextStyle(color: context.inkSoft)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primary,
              foregroundColor: context.onSolid,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              s.approveRequest(r);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(context)!.approvedReq(r.amount.text, kid?.name ?? AppLocalizations.of(context)!.yourChild),
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text(AppLocalizations.of(context)!.approve),
          ),
        ],
      ),
    );
  }

  void _reviewProposal(BuildContext context, AppState s, Proposal p) {
    final teen = s.member(p.teenId);
    final env = s.envelope(p.envelopeId);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppLocalizations.of(context)!.proposalTitle(teen?.name ?? 'Zoe', p.amount.text)),
        content: Text(AppLocalizations.of(context)!.declineBody(p.reason, env?.name ?? '-')),
        actions: [
          TextButton(
            onPressed: () {
              s.declineProposal(p);
              Navigator.pop(ctx);
            },
            child: Text(AppLocalizations.of(context)!.decline, style: TextStyle(color: context.inkSoft)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primary,
              foregroundColor: context.onSolid,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              s.approveProposal(p);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(context)!.approvedProp(p.amount.text, env?.name ?? AppLocalizations.of(context)!.envelopeLabel),
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text(AppLocalizations.of(context)!.approve),
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

// ── Reports badge glyph — mini "where the money went" donut ─────────────────
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
