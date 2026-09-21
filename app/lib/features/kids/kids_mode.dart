import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth/pin_store.dart';
import '../../core/money/money.dart';
import '../../core/models/models.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/ring_progress.dart';

/// Sealed, playful shell for kids 6–12 (spec Module G, §7.8).
/// No family balances, no real money movement — jar, stars, chores, wishes.
/// Exit requires the parent PIN (demo: 1234).
class KidsMode extends StatelessWidget {
  const KidsMode({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final kid = s.user;
    final jar = s.goal('g_jar');
    final saved = jar == null ? const Money(0, Currency.usd) : s.savedOn(jar);
    final pct = (jar == null || jar.target.minor <= 0)
        ? 0
        : ((saved.minor / jar.target.minor) * 100).round().clamp(0, 100);

    return Scaffold(
      backgroundColor: kKidBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            // ── Header ────────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.kidsHi(kid.name),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: kKidInk,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star,
                              size: 19, color: Color(0xFFF4A81D)),
                          const SizedBox(width: 4),
                          Text(
                            '${s.stars} stars',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: kKidInk,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  radius: 26,
                  backgroundColor: kKidCard,
                  child: Icon(
                    iconForKey(kid.emoji) ?? Icons.child_care,
                    size: 26,
                    color: kKidInk,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── My Jar ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: kKidCard,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!.kidsMyJar,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: kKidInk,
                          ),
                        ),
                      ),
                      RingProgress(
                        value: jar == null || jar.target.minor <= 0
                            ? 0
                            : saved.minor / jar.target.minor,
                        size: 60,
                        stroke: 8,
                        color: kKidSky,
                        track: const Color(0xFFF0E9D8),
                        child: const Icon(Icons.directions_bike,
                            size: 24, color: kKidInk),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      saved.text,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: kKidInk,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: jar == null || jar.target.minor <= 0
                          ? 0
                          : (saved.minor / jar.target.minor)
                              .clamp(0.0, 1.0)
                              .toDouble(),
                      minHeight: 12,
                      backgroundColor: const Color(0xFFF0E9D8),
                      color: kKidSky,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      AppLocalizations.of(context)!
                          .kidsGoalSaved('New Bike', pct),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kKidInk,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── My Chores ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.kidsMyChores,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: kKidInk,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final c in s.chores)
                    _ChoreRow(
                      chore: c,
                      onTap: c.state == ChoreState.todo
                          ? () {
                              s.claimChore(c);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    AppLocalizations.of(context)!
                                        .sentKid(c.name),
                                  ),
                                  backgroundColor: kKidInk,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          : null,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Wish list ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: kKidSky.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.sports_soccer,
                        size: 30, color: kKidInk),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.kidsWishList,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: kKidInk,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppLocalizations.of(context)!
                              .kidsWishItem(saved.text),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: kKidInk,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: LinearProgressIndicator(
                            value:
                                (saved.minor / 2500).clamp(0.0, 1.0).toDouble(),
                            minHeight: 10,
                            backgroundColor: const Color(0xFFF0E9D8),
                            color: kKidCoral,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Actions ───────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _bigButton(
                    label: AppLocalizations.of(context)!.kidsAskMoney,
                    color: kKidCoral,
                    onTap: () => _askSheet(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _bigButton(
                    label: AppLocalizations.of(context)!.kidsDoChore,
                    color: context.primary,
                    onTap: () {
                      Chore? next;
                      for (final c in s.chores) {
                        if (c.state == ChoreState.todo) {
                          next = c;
                          break;
                        }
                      }
                      if (next == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text(AppLocalizations.of(context)!.kidsAllDone),
                            backgroundColor: kKidInk,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      s.claimChore(next);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            AppLocalizations.of(context)!.sentKid(next.name),
                          ),
                          backgroundColor: kKidInk,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () => _pinDialog(context),
                icon: const Icon(Icons.lock_outline, size: 18, color: kKidInk),
                label: Text(
                  AppLocalizations.of(context)!.kidsParents,
                  style: TextStyle(
                    color: kKidInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bigButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 3,
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w800, height: 1.2),
      ),
    );
  }

  void _askSheet(BuildContext context) {
    final s = AppScope.of(context);
    final amount = TextEditingController();
    final reason = TextEditingController();
    Currency cur = Currency.usd;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            decoration: const BoxDecoration(
              color: kKidCard,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.kidsAskTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: kKidInk,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amount,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: kKidInk,
                  ),
                  decoration: InputDecoration(
                    prefixText: '${cur.symbol} ',
                    filled: true,
                    fillColor: Colors.white,
                    border:
                        const OutlineInputBorder(borderSide: BorderSide.none),
                    hintText: '0.00',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('USD'),
                      selected: cur == Currency.usd,
                      onSelected: (_) => setSheet(() => cur = Currency.usd),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('ZiG'),
                      selected: cur == Currency.zwg,
                      onSelected: (_) => setSheet(() => cur = Currency.zwg),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reason,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.kidsWhatFor,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    final v = double.tryParse(amount.text.replaceAll(',', ''));
                    if (v == null || v <= 0) return;
                    s.requestMoney(
                      Money.fromMajor(v, cur),
                      reason.text.trim().isEmpty
                          ? AppLocalizations.of(context)!.kidsDefaultReason
                          : reason.text.trim(),
                    );
                    Navigator.pop(sheetCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text(AppLocalizations.of(context)!.sentToParents),
                        backgroundColor: kKidInk,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kKidCoral,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.sendRequest,
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _pinDialog(BuildContext context) {
    final s = AppScope.of(context);
    final pin = TextEditingController();
    int shake = 0; // G13: bumped on a wrong PIN to re-trigger the wiggle

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(children: [
            Icon(Icons.lock, size: 16),
            SizedBox(width: 6),
            Text(AppLocalizations.of(context)!.parentsOnly),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppLocalizations.of(context)!.pinExitLine),
              const SizedBox(height: 12),
              // G13: the field wiggles once per wrong attempt.
              TweenAnimationBuilder<double>(
                key: ValueKey(shake),
                tween: Tween(begin: shake == 0 ? 1.0 : 0.0, end: 0.0),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOut,
                builder: (context, v, child) {
                  final dx = math.sin(v * 6 * math.pi) * 9 * v;
                  return Transform.translate(
                      offset: Offset(dx, 0), child: child);
                },
                child: TextField(
                  controller: pin,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '••••',
                    filled: true,
                    fillColor: context.bg,
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final ok = await s.pinStore
                    .verifyPin(PinStore.parentKey, pin.text.trim());
                if (!ctx.mounted || !context.mounted) return;
                if (ok) {
                  // Find the owner to hand the device back to.
                  Member? owner;
                  for (final m in s.members) {
                    if (m.role == Role.owner) {
                      owner = m;
                      break;
                    }
                  }
                  if (owner != null) s.switchUser(owner);
                  Navigator.pop(ctx);
                } else {
                  HapticFeedback.heavyImpact(); // G13
                  setDialog(() => shake++);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)!.wrongPin),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: Text(AppLocalizations.of(context)!.unlock),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoreRow extends StatelessWidget {
  final Chore chore;
  final VoidCallback? onTap;

  const _ChoreRow({required this.chore, this.onTap});

  @override
  Widget build(BuildContext context) {
    final done = chore.state == ChoreState.confirmed;
    final waiting = chore.state == ChoreState.waiting;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: done ? kKidSky : Colors.white,
                border: Border.all(
                  color: done ? kKidSky : const Color(0xFFD8D2C2),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: done
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                chore.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: done ? context.inkSoft : kKidInk,
                  decoration: done ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (waiting)
              Text(
                'waiting',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.accent,
                ),
              )
            else
              Text(
                '${chore.stars} stars',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: kKidInk,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
