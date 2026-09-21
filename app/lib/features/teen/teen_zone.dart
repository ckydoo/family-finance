import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/money/money.dart';
import '../../core/models/models.dart';
import '../../core/state/app_state.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/theme/app_theme.dart';
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
    final jar = s.goal('g_teenjar');
    final saved = jar == null ? const Money(0, Currency.usd) : s.savedOn(jar);
    final schoolFees = s.envelope('e2');

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            // ── Header ────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${tStr(context, 'hi')}, ${s.user.name}',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: context.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(context)!.teenZoneTitle,
                        style:
                            TextStyle(fontSize: 12.5, color: context.inkSoft),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: tStr(context, 'family'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MembersScreen()),
                  ),
                  icon: Icon(Icons.family_restroom, color: context.ink),
                ),
              ],
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
                          '${tStr(context, 'mySavings')} — '
                          '${jar?.name.split('—').last.trim() ?? ''}',
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
                      padding: EdgeInsets.only(bottom: 8),
                      child: EmptyState(
                        icon: Icons.fitness_center,
                        title: AppLocalizations.of(context)!.teenNoEarnings,
                        subtitle: AppLocalizations.of(context)!.teenEarnHint,
                      ),
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
                                  .inCurrency(Currency.usd, s.rate)
                                  .major)
                              .toList(),
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    s.teenEarnings.isEmpty ? '' : s.teenEarnings.first.note,
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

            // ── Envelope peek (parent-enabled visibility, H1) ─────────
            if (schoolFees != null) ...[
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
                      _seg(0.5, context.primary,
                          AppLocalizations.of(context)!.teenSpend),
                      const SizedBox(width: 4),
                      _seg(0.4, context.accent,
                          AppLocalizations.of(context)!.teenSave),
                      const SizedBox(width: 4),
                      _seg(0.1, kKidCoral,
                          AppLocalizations.of(context)!.teenGive),
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

  Widget _seg(double fraction, Color color, String label) => Expanded(
        flex: (fraction * 10).round(),
        child: Container(
          height: 26,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );

  // ── Sheets ──────────────────────────────────────────────────────────

  void _contributeSheet(BuildContext context, AppState s, Goal? jar) {
    if (jar == null) return;
    final controller = TextEditingController();
    Currency cur = jar.target.currency;

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
            decoration: BoxDecoration(
              color: context.bg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${tStr(context, 'addToJar')} — ${jar.name}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: context.ink,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: context.ink,
                  ),
                  decoration: InputDecoration(
                    prefixText: '${cur.symbol} ',
                    filled: true,
                    fillColor: context.card,
                    border:
                        const OutlineInputBorder(borderSide: BorderSide.none),
                    hintText: '0.00',
                  ),
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    final v =
                        double.tryParse(controller.text.replaceAll(',', ''));
                    if (v == null || v <= 0) return;
                    final l = AppLocalizations.of(context)!;
                    final messenger = ScaffoldMessenger.of(context);
                    s.contribute(jar, Money.fromMajor(v, cur));
                    Navigator.pop(sheetCtx);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(l.teenSavedJar),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.primary,
                    foregroundColor: context.onSolid,
                    minimumSize: const Size.fromHeight(50),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(AppLocalizations.of(context)!.save),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _earningSheet(BuildContext context) {
    final s = AppScope.of(context);
    final note = TextEditingController();
    final amount = TextEditingController();
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
            decoration: BoxDecoration(
              color: context.bg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tStr(context, 'logEarning'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: context.ink,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: note,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.teenWhatDid,
                    filled: true,
                    fillColor: context.card,
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: context.ink,
                  ),
                  decoration: InputDecoration(
                    prefixText: '${cur.symbol} ',
                    filled: true,
                    fillColor: context.card,
                    border:
                        const OutlineInputBorder(borderSide: BorderSide.none),
                    hintText: '0.00',
                  ),
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    final v = double.tryParse(amount.text.replaceAll(',', ''));
                    final n = note.text.trim();
                    if (v == null || v <= 0 || n.isEmpty) {
                      ScaffoldMessenger.of(sheetCtx).showSnackBar(
                        SnackBar(
                          content:
                              Text(AppLocalizations.of(context)!.logWhatAmount),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    s.addEarning(Money.fromMajor(v, cur), n);
                    Navigator.pop(sheetCtx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.primary,
                    foregroundColor: context.onSolid,
                    minimumSize: const Size.fromHeight(50),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(AppLocalizations.of(context)!.logIt),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _proposeSheet(BuildContext context) {
    final s = AppScope.of(context);
    final amount = TextEditingController();
    final reason = TextEditingController();
    Currency cur = Currency.usd;
    var envelopeId = 'e6';

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
            decoration: BoxDecoration(
              color: context.bg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tStr(context, 'proposeTitle'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: context.ink,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amount,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: context.ink,
                  ),
                  decoration: InputDecoration(
                    prefixText: '${cur.symbol} ',
                    filled: true,
                    fillColor: context.card,
                    border:
                        const OutlineInputBorder(borderSide: BorderSide.none),
                    hintText: '0.00',
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
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
                const SizedBox(height: 12),
                TextField(
                  controller: reason,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.kidsWhatFor,
                    filled: true,
                    fillColor: context.card,
                    border: OutlineInputBorder(borderSide: BorderSide.none),
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
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    final v = double.tryParse(amount.text.replaceAll(',', ''));
                    final r = reason.text.trim();
                    if (v == null || v <= 0 || r.isEmpty) {
                      ScaffoldMessenger.of(sheetCtx).showSnackBar(
                        SnackBar(
                          content: Text(
                              AppLocalizations.of(context)!.amountPurposeFirst),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.primary,
                    foregroundColor: context.onSolid,
                    minimumSize: const Size.fromHeight(50),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(AppLocalizations.of(context)!.sendProposal),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Earnings bar chart ──────────────────────────────────────────────────────

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
    final barW = slot * 0.55;

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
                  '${e.name} — ${spent.text} of ${e.limit.text}',
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
