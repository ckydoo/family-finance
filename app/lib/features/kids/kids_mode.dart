import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth/pin_store.dart';
import '../../core/money/money.dart';
import '../../core/models/models.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/ring_progress.dart';

/// Sealed, playful shell for kids 6–12 (spec Module G, §7.8).
/// No family balances, no real money movement - jar, stars, chores, wishes.
/// Exit requires the parent PIN (factory default: 1234 until changed).
class KidsMode extends StatelessWidget {
  const KidsMode({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final kid = s.user;
    final jar = s.kidJarGoal;
    final saved = jar == null ? Money(0, s.displayCurrency) : s.savedOn(jar);
    final pct = (jar == null || jar.target.minor <= 0)
        ? 0
        : ((saved.minor / jar.target.minor) * 100).round().clamp(0, 100);

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: _KidsPatternBackground(colors: context.mc),
                ),
              ),
            ),
            ListView(
              padding: kPageInsets,
              children: [
                // ── Header ────────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.bg,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Positioned(
                        right: 46,
                        top: -20,
                        child: Icon(Icons.star_rounded,
                            size: 72,
                            color: context.card.withValues(alpha: 0.24)),
                      ),
                      Positioned(
                        right: -20,
                        bottom: -26,
                        child: Icon(Icons.savings_outlined,
                            size: 88,
                            color: context.primaryDark.withValues(alpha: 0.16)),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!
                                      .kidsHi(kid.name),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 28,
                                    height: 1.05,
                                    fontWeight: FontWeight.w900,
                                    color: context.ink,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.card,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.star_rounded,
                                          size: 19, color: context.accentDark),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          '${s.stars} stars',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            color: context.ink,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            iconForKey(kid.emoji) ?? kFallbackSemanticIcon,
                            size: 34,
                            color: context.ink,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── My Jar ────────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: context.hairline),
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
                                color: context.ink,
                              ),
                            ),
                          ),
                          RingProgress(
                            value: jar == null || jar.target.minor <= 0
                                ? 0
                                : saved.minor / jar.target.minor,
                            size: 60,
                            stroke: 8,
                            color: context.information,
                            track: context.surfaceSecondary,
                            child: Icon(Icons.directions_bike,
                                size: 24, color: context.ink),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          saved.text,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: context.ink,
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
                          backgroundColor: context.surfaceSecondary,
                          color: context.information,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          AppLocalizations.of(context)!
                              .kidsGoalSaved(jar?.name ?? '-', pct),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.ink,
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
                    color: context.card,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: context.hairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.task_alt_rounded,
                              color: context.accentDark, size: 26),
                          const SizedBox(width: 9),
                          Text(
                            AppLocalizations.of(context)!.kidsMyChores,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: context.ink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (s.chores.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 4),
                          child: Row(
                            children: [
                              Icon(Icons.celebration_rounded,
                                  size: 34, color: context.danger),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  AppLocalizations.of(context)!.kidsNoChores,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    fontWeight: FontWeight.w600,
                                    color: context.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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
                                      backgroundColor: context.ink,
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
                    color: context.card,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: context.hairline),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 48,
                        child: Icon(Icons.card_giftcard_rounded,
                            size: 32, color: context.danger),
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
                                color: context.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              jar == null
                                  ? AppLocalizations.of(context)!.kidsNoWish
                                  : AppLocalizations.of(context)!
                                      .kidsWishProgress(
                                      jar.name,
                                      jar.target.text,
                                      saved.text,
                                    ),
                              style: TextStyle(
                                fontSize: 12.5,
                                color: context.ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: LinearProgressIndicator(
                                value: (saved.minor / 2500)
                                    .clamp(0.0, 1.0)
                                    .toDouble(),
                                minHeight: 10,
                                backgroundColor: context.surfaceSecondary,
                                color: context.danger,
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
                _bigButton(
                  context: context,
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
                          backgroundColor: context.ink,
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
                        backgroundColor: context.ink,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _askSheet(context),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 19),
                  label: Text(
                    AppLocalizations.of(context)!
                        .kidsAskMoney
                        .replaceAll('\n', ' '),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.danger,
                    side: BorderSide(color: context.danger, width: 1.5),
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton.icon(
                    onPressed: () => _pinDialog(context),
                    icon:
                        Icon(Icons.lock_outline, size: 18, color: context.ink),
                    label: Text(
                      AppLocalizations.of(context)!.kidsParentArea,
                      style: TextStyle(
                        color: context.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bigButton({
    required BuildContext context,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: context.onSolid,
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
    Currency cur = s.displayCurrency;
    String? askError;

    showMhuriSheet<void>(
      context: context,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => MhuriSheetShell(
          title: AppLocalizations.of(context)!.kidsAskTitle,
          footer: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (askError != null) ...[
                ErrorNotice(askError!),
                const SizedBox(height: 10),
              ],
              ElevatedButton(
                onPressed: () {
                  final v = double.tryParse(amount.text.replaceAll(',', ''));
                  if (v == null || v <= 0) {
                    setSheet(() => askError =
                        AppLocalizations.of(context)!.enterAmountFirst);
                    return;
                  }
                  final sent = s.requestMoney(
                    Money.fromMajor(v, cur),
                    reason.text.trim().isEmpty
                        ? AppLocalizations.of(context)!.kidsDefaultReason
                        : reason.text.trim(),
                  );
                  if (!sent) {
                    setSheet(() => askError =
                        'This child profile cannot send a request right now.');
                    return;
                  }
                  Navigator.pop(sheetCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text(AppLocalizations.of(context)!.sentToParents),
                      backgroundColor: context.ink,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.danger,
                  foregroundColor: context.onSolid,
                  minimumSize: const Size.fromHeight(52),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  AppLocalizations.of(context)!.sendRequest,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: amount,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: amountInputFormatters,
                onChanged: (_) {
                  if (askError != null) setSheet(() => askError = null);
                },
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: context.ink,
                ),
                decoration: InputDecoration(
                  prefixText: '${cur.symbol} ',
                  filled: true,
                  fillColor: context.card,
                  border: const OutlineInputBorder(borderSide: BorderSide.none),
                  hintText: '0.00',
                ),
              ),
              if (s.activeCurrencies.length > 1) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final c in s.activeCurrencies)
                      ChoiceChip(
                        label: Text(c.short),
                        selected: cur == c,
                        onSelected: (_) => setSheet(() {
                          cur = c;
                          if (askError != null) askError = null;
                        }),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: reason,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.kidsWhatFor,
                  filled: true,
                  fillColor: context.card,
                  border: const OutlineInputBorder(borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pinDialog(BuildContext context) {
    final s = AppScope.of(context);
    final l = AppLocalizations.of(context)!;
    final pin = TextEditingController();
    int shake = 0; // G13: bumped on a wrong PIN to re-trigger the wiggle
    String? pinError;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(children: [
            const Icon(Icons.lock, size: 16),
            const SizedBox(width: 6),
            Text(l.parentsOnly),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.pinExitLine),
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
                  inputFormatters: pinInputFormatters,
                  onChanged: (_) {
                    if (pinError != null) setDialog(() => pinError = null);
                  },
                  decoration: InputDecoration(
                    hintText: '••••',
                    filled: true,
                    fillColor: context.bg,
                    errorText: pinError,
                    errorStyle: TextStyle(color: context.danger),
                    border:
                        const OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.primary,
                foregroundColor: context.onSolid,
              ),
              onPressed: () async {
                final ok = await s.pinStore
                    .verifyPin(PinStore.parentKey, pin.text.trim());
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
                  if (ctx.mounted) Navigator.pop(ctx);
                } else {
                  HapticFeedback.heavyImpact(); // G13
                  setDialog(() {
                    shake++;
                    pinError = l.wrongPin;
                  });
                }
              },
              child: Text(l.unlock),
            ),
          ],
        ),
      ),
    );
  }
}

/// A quiet illustration layer that keeps Kids Mode playful without competing
/// with balances, labels, or actions.
class _KidsPatternBackground extends StatelessWidget {
  const _KidsPatternBackground({required this.colors});

  final MhuriColors colors;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _KidsPatternPainter(colors));
  }
}

class _KidsPatternPainter extends CustomPainter {
  const _KidsPatternPainter(this.colors);

  final MhuriColors colors;
  static const _symbols = <IconData>[
    Icons.star_rounded,
    Icons.savings_outlined,
    Icons.sports_soccer,
    Icons.celebration_rounded,
    Icons.favorite_rounded,
    Icons.bolt_rounded,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rows = (size.height / 115).ceil() + 1;
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < 3; column++) {
        final icon = _symbols[(row * 3 + column) % _symbols.length];
        final x = column * (size.width / 2) - 8 + (row.isOdd ? 28 : 0);
        final y = 24.0 + row * 115 + (column.isOdd ? 24 : 0);
        final color = switch ((row + column) % 3) {
          0 => colors.ink.withValues(alpha: 0.14),
          1 => colors.danger.withValues(alpha: 0.16),
          _ => colors.accent.withValues(alpha: 0.20),
        };
        final painter = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
              inherit: false,
              fontFamily: icon.fontFamily,
              package: icon.fontPackage,
              fontSize: column == 1 ? 38 : 30,
              color: color,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(canvas, Offset(x, y));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _KidsPatternPainter oldDelegate) =>
      oldDelegate.colors != colors;
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
                color: done ? context.information : context.card,
                border: Border.all(
                  color: done ? context.information : context.hairline,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: done
                  ? Icon(Icons.check, size: 18, color: context.onSolid)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                chore.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: done ? context.inkSoft : context.ink,
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
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: context.ink,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
