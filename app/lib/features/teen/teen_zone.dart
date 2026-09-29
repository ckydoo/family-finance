import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/money/money.dart';
import '../../core/models/models.dart';
import '../../core/state/app_state.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/ring_progress.dart';
import '../members/members_screen.dart';

/// Teen dashboard for 13–17s (spec Module H, §7.9).
/// Own jar + earnings + proposals; optional read-only peek at one envelope.
class TeenZone extends StatelessWidget {
  const TeenZone({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    // Synced jars use server UUIDs; never depend on the old fixture id.
    final jar = s.teenJarGoal;
    final saved = jar == null ? Money(0, s.displayCurrency) : s.savedOn(jar);
    final schoolFees = s.envelope('e2');

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: ListView(
          padding: kPageInsets,
          children: [
            if (s.isPreviewing) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(12, 5, 6, 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF3DC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE8D39A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.visibility_outlined,
                        size: 17, color: Color(0xFF8A6D1F)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!
                            .previewBanner(s.user.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B5518),
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: s.exitPreview,
                      icon: const Icon(Icons.logout, size: 16),
                      label: Text(AppLocalizations.of(context)!.previewExit),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF8A6D1F),
                        textStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            // ── Header ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 10, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [context.primary, context.primaryDark],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${tStr(context, 'hi')}, ${s.user.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppLocalizations.of(context)!.teenZoneTitle,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: tStr(context, 'family'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MembersScreen()),
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.14),
                    ),
                    icon:
                        const Icon(Icons.family_restroom, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── My jar ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  RingProgress(
                    value: jar == null || jar.target.minor <= 0
                        ? 0
                        : (saved.minor / jar.target.minor)
                            .clamp(0.0, 1.0)
                            .toDouble(),
                    size: 62,
                    color: context.primary,
                    child: Icon(
                      iconForKey(jar?.emoji) ?? Icons.track_changes,
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${tStr(context, 'mySavings')} - '
                          '${jar?.name.split('-').last.trim() ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: context.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          jar == null
                              ? ''
                              : '${saved.text} of ${jar.target.text}',
                          style:
                              TextStyle(fontSize: 12.5, color: context.inkSoft),
                        ),
                        if (jar?.autoSave != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            jar!.autoSave!,
                            style: TextStyle(
                                fontSize: 11.5, color: context.accent),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _contributeSheet(context, s, jar),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.primary,
                      foregroundColor: context.onSolid,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: Text(tStr(context, 'addToJar')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Savings match ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFD9EDE8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.handshake, size: 26, color: context.primaryDark),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tStr(context, 'savingsMatch'),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: context.ink,
                          ),
                        ),
                        Text(
                          tStr(context, 'savingsMatchNote'),
                          style:
                              TextStyle(fontSize: 11.5, color: context.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '+${s.teenMatchTotal.text}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: context.primary,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Earnings ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tStr(context, 'earnings'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: context.ink,
                          ),
                        ),
                      ),
                      Text(
                        '${s.teenEarningsThisMonth.text} · month',
                        style: TextStyle(fontSize: 12, color: context.inkSoft),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (s.teenEarnings.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: EmptyState(
                        icon: Icons.fitness_center,
                        title: AppLocalizations.of(context)!.teenNoEarnings,
                        subtitle: AppLocalizations.of(context)!.teenEarnHint,
                      ),
                    )
                  else if (s.teenEarnings.length == 1)
                    _SingleEarningRow(
                      earning: s.teenEarnings.first,
                      amount: s.teenEarnings.first.amount
                          .inCurrency(s.displayCurrency, s.rate),
                    )
                  else
                    SizedBox(
                      height: 90,
                      child: CustomPaint(
                        size: const Size(double.infinity, 90),
                        painter: _BarsPainter(
                          color: context.primary,
                          lastColor: context.accent,
                          values: s.teenEarnings
                              .take(8)
                              .toList()
                              .reversed
                              .map((e) => e.amount
                                  .inCurrency(s.displayCurrency, s.rate)
                                  .major)
                              .toList(),
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  if (s.teenEarnings.length > 1)
                    Text(
                      s.teenEarnings.first.note,
                      style: TextStyle(fontSize: 11, color: context.inkSoft),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _earningSheet(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.primary,
                      side: BorderSide(color: context.primary),
                      shape: const StadiumBorder(),
                      minimumSize: const Size.fromHeight(44),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(tStr(context, 'logEarning')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Proposals ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tStr(context, 'myProposals'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: context.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final p in s.proposals.take(3)) _ProposalRow(p: p),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _proposeSheet(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.accent,
                      foregroundColor: context.onSolid,
                      minimumSize: const Size.fromHeight(46),
                      shape: const StadiumBorder(),
                    ),
                    icon: const Icon(Icons.send, size: 18),
                    label: Text(
                      tStr(context, 'proposeExpense'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Envelope peek (parent-enabled visibility, H1) - the owner's
            // switch is enforced server-side by RLS (migration 011); this
            // keeps the UI in agreement.
            if (s.teenCanSeeBudget && schoolFees != null) ...[
              _PeekCard(e: schoolFees),
              const SizedBox(height: 12),
            ],

            // ── Spend · Save · Give plan (H5) ─────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tStr(context, 'plan'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: context.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _seg(0.5, context.primary),
                      const SizedBox(width: 4),
                      _seg(0.4, context.accent),
                      const SizedBox(width: 4),
                      _seg(0.1, kKidCoral),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _legend(context.primary,
                          AppLocalizations.of(context)!.teenSpend),
                      const SizedBox(width: 8),
                      _legend(context.accent,
                          AppLocalizations.of(context)!.teenSave),
                      const SizedBox(width: 8),
                      _legend(
                          kKidCoral, AppLocalizations.of(context)!.teenGive),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!
                        .teenSplitHint(s.teenEarningsThisMonth.text),
                    style: TextStyle(fontSize: 11.5, color: context.inkSoft),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seg(double fraction, Color color) => Expanded(
        flex: (fraction * 10).round(),
        child: Container(
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      );

  Widget _legend(Color color, String label) => Expanded(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );

  // ── Sheets ──────────────────────────────────────────────────────────

  Future<void> _contributeSheet(
      BuildContext context, AppState s, Goal? jar) async {
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    var resolvedJar = jar;
    if (resolvedJar == null) {
      try {
        resolvedJar = await s.sync?.ensurePersonalSavingsGoal();
      } catch (_) {
        resolvedJar = null;
      }
      if (!context.mounted) return;
      if (resolvedJar == null) {
        messenger.showSnackBar(SnackBar(
          content: Text(l.teenJarCreateFailed),
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
    }
    final activeJar = resolvedJar;
    final controller = TextEditingController();
    Currency cur = activeJar.target.currency;
    String? jarError;

    await showMhuriSheet<void>(
      context: context,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => MhuriSheetShell(
          title: '${tStr(context, 'addToJar')} - ${activeJar.name}',
          footer: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (jarError != null) ...[
                ErrorNotice(jarError!),
                const SizedBox(height: 10),
              ],
              PrimaryButton(
                label: AppLocalizations.of(context)!.save,
                onPressed: () {
                  final v =
                      double.tryParse(controller.text.replaceAll(',', ''));
                  if (v == null || v <= 0) {
                    setSheet(() => jarError = l.enterAmountFirst);
                    return;
                  }
                  s.contribute(activeJar, Money.fromMajor(v, cur));
                  Navigator.pop(sheetCtx);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(l.teenSavedJar),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: amountInputFormatters,
                onChanged: (_) {
                  if (jarError != null) setSheet(() => jarError = null);
                },
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
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
              const SizedBox(height: 12),
              if (s.activeCurrencies.length > 1)
                Row(
                  children: [
                    for (final c in s.activeCurrencies) ...[
                      ChoiceChip(
                        label: Text(c.short),
                        selected: cur == c,
                        onSelected: (_) => setSheet(() {
                          cur = c;
                          if (jarError != null) jarError = null;
                        }),
                      ),
                      const SizedBox(width: 8),
                    ],
                    const Spacer(),
                    Text(
                      '+ match ${(s.teenMatchRate * 100).round()}%',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: context.primary,
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

  void _earningSheet(BuildContext context) {
    final s = AppScope.of(context);
    final note = TextEditingController();
    final amount = TextEditingController();
    Currency cur = s.displayCurrency;
    String? earnError;

    showMhuriSheet<void>(
      context: context,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => MhuriSheetShell(
          title: tStr(context, 'logEarning'),
          footer: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (earnError != null) ...[
                ErrorNotice(earnError!),
                const SizedBox(height: 10),
              ],
              PrimaryButton(
                label: AppLocalizations.of(context)!.logIt,
                onPressed: () {
                  final v = double.tryParse(amount.text.replaceAll(',', ''));
                  final n = note.text.trim();
                  if (n.isEmpty) {
                    setSheet(() =>
                        earnError = AppLocalizations.of(context)!.teenWhatDid);
                    return;
                  }
                  if (v == null || v <= 0) {
                    setSheet(() => earnError =
                        AppLocalizations.of(context)!.enterAmountFirst);
                    return;
                  }
                  s.addEarning(Money.fromMajor(v, cur), n);
                  Navigator.pop(sheetCtx);
                },
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: note,
                autofocus: true,
                onChanged: (_) {
                  if (earnError != null) setSheet(() => earnError = null);
                },
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.teenWhatDid,
                  filled: true,
                  fillColor: context.card,
                  border: const OutlineInputBorder(borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: amountInputFormatters,
                onChanged: (_) {
                  if (earnError != null) setSheet(() => earnError = null);
                },
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final c in s.activeCurrencies) ...[
                      ChoiceChip(
                        label: Text(c.short),
                        selected: cur == c,
                        onSelected: (_) => setSheet(() {
                          cur = c;
                          if (earnError != null) earnError = null;
                        }),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _proposeSheet(BuildContext context) {
    final s = AppScope.of(context);
    final amount = TextEditingController();
    final reason = TextEditingController();
    Currency cur = s.displayCurrency;
    var envelopeId = 'e6';
    String? propError;

    showMhuriSheet<void>(
      context: context,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => MhuriSheetShell(
          title: tStr(context, 'proposeTitle'),
          footer: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (propError != null) ...[
                ErrorNotice(propError!),
                const SizedBox(height: 10),
              ],
              PrimaryButton(
                label: AppLocalizations.of(context)!.sendProposal,
                onPressed: () {
                  final v = double.tryParse(amount.text.replaceAll(',', ''));
                  final r = reason.text.trim();
                  if (v == null || v <= 0) {
                    setSheet(() => propError =
                        AppLocalizations.of(context)!.enterAmountFirst);
                    return;
                  }
                  if (r.isEmpty) {
                    setSheet(() =>
                        propError = AppLocalizations.of(context)!.kidsWhatFor);
                    return;
                  }
                  final l = AppLocalizations.of(context)!;
                  final messenger = ScaffoldMessenger.of(context);
                  s.proposeExpense(Money.fromMajor(v, cur), envelopeId, r);
                  Navigator.pop(sheetCtx);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(l.sentApproval),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
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
                  if (propError != null) setSheet(() => propError = null);
                },
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
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
                Wrap(
                  spacing: 8,
                  children: [
                    for (final c in s.activeCurrencies)
                      ChoiceChip(
                        label: Text(c.short),
                        selected: cur == c,
                        onSelected: (_) => setSheet(() {
                          cur = c;
                          if (propError != null) propError = null;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: reason,
                onChanged: (_) {
                  if (propError != null) setSheet(() => propError = null);
                },
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.kidsWhatFor,
                  filled: true,
                  fillColor: context.card,
                  border: const OutlineInputBorder(borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context)!.fromEnvelope,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.inkSoft,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in s.envelopes.where((e) => !e.isPersonal))
                    ChoiceChip(
                      label: Row(children: [
                        Icon(iconForKey(e.emoji) ?? Icons.savings,
                            size: 16, color: context.primaryDark),
                        const SizedBox(width: 8),
                        Text(e.name),
                      ]),
                      selected: envelopeId == e.id,
                      onSelected: (_) => setSheet(() => envelopeId = e.id),
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

// ── Earnings bar chart ──────────────────────────────────────────────────────

class _SingleEarningRow extends StatelessWidget {
  const _SingleEarningRow({required this.earning, required this.amount});

  final Earning earning;
  final Money amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: context.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: Icon(Icons.paid_outlined, color: context.primaryDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              earning.note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '+${amount.text}',
            style: TextStyle(
              color: context.primary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final Color lastColor;

  _BarsPainter(
      {required this.values, required this.color, required this.lastColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = values.reduce(math.max);
    final n = values.length;
    final slot = size.width / n;
    // A single/few data points must still look like bars, not giant blocks.
    final barW = math.min(slot * 0.55, 36.0);

    for (var i = 0; i < n; i++) {
      final h = maxV <= 0 ? 0.0 : (values[i] / maxV) * (size.height - 18);
      final rect = Rect.fromLTWH(
        i * slot + (slot - barW) / 2,
        size.height - 14 - h,
        barW,
        h == 0 ? 2 : h,
      );
      final paint = Paint()
        ..color = i == n - 1 ? lastColor : color
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        paint,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: values[i] == values[i].roundToDouble()
              ? values[i].toStringAsFixed(0)
              : values[i].toStringAsFixed(1),
          style: const TextStyle(fontSize: 9, color: Color(0xFF6B7280)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(i * slot + (slot - tp.width) / 2, size.height - 12),
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => old.values != values;
}

// ── Proposal row ────────────────────────────────────────────────────────────

class _ProposalRow extends StatelessWidget {
  final Proposal p;

  const _ProposalRow({required this.p});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final env = s.envelope(p.envelopeId);
    final (chip, color) = switch (p.state) {
      RequestState.pending => (
          AppLocalizations.of(context)!.stWaiting,
          const Color(0xFFFBE7C6)
        ),
      RequestState.approved => (
          AppLocalizations.of(context)!.stApproved,
          const Color(0xFFD9EDE8)
        ),
      RequestState.declined => (
          AppLocalizations.of(context)!.stDeclined,
          const Color(0xFFF9E0DF)
        ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.reason,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: context.ink,
                  ),
                ),
                Text(
                  '${p.amount.text} · ${env?.name ?? ''}',
                  style: TextStyle(fontSize: 11.5, color: context.inkSoft),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              chip,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: context.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Read-only envelope peek (H1) ────────────────────────────────────────────

class _PeekCard extends StatelessWidget {
  final Envelope e;

  const _PeekCard({required this.e});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final spent = s.spentOn(e);
    final value = e.limit.minor <= 0
        ? 0.0
        : (spent.minor / e.limit.minor).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF4F1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(iconForKey(e.emoji) ?? Icons.savings,
                  size: 21, color: context.primaryDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${e.name} - ${spent.text} of ${e.limit.text}',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: context.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 7,
              backgroundColor: context.card,
              color: context.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tStr(context, 'peek'),
            style: TextStyle(fontSize: 11.5, color: context.inkSoft),
          ),
        ],
      ),
    );
  }
}
