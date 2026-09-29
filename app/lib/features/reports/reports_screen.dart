import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/state/app_state.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/money/money.dart';
import '../../core/models/models.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/ring_progress.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../meeting/family_meeting_screen.dart';

/// Monthly report card (spec Module I1/I2) - one screen the family can
/// review together at the monthly Family Meeting.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _cycleOffset = 0;

  DateTime _cycleStart(AppState state, int offset) => DateTime(
        state.cycleStart.year,
        state.cycleStart.month - offset,
        state.monthStartDay,
      );

  String _periodLabel(BuildContext context, DateTime start, DateTime end) {
    final language = Localizations.localeOf(context).languageCode;
    final locale =
        const {'es', 'fr', 'pt'}.contains(language) ? language : 'en';
    return '${DateFormat.MMMd(locale).format(start)} – '
        '${DateFormat.yMMMd(locale).format(end.subtract(const Duration(days: 1)))}';
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final periodStart = _cycleStart(s, _cycleOffset);
    final periodEnd = _cycleStart(s, _cycleOffset - 1);
    final periodLabel = _periodLabel(context, periodStart, periodEnd);
    final transactions = s.txs
        .where((tx) =>
            !tx.when.isBefore(periodStart) && tx.when.isBefore(periodEnd))
        .toList();
    final savings = s.goalTxs
        .where(
            (tx) => !tx.at.isBefore(periodStart) && tx.at.isBefore(periodEnd))
        .toList();

    final displayCur = s.displayCurrency;
    final envelopeById = {for (final e in s.envelopes) e.id: e};
    final spentByEnvelope = <String, int>{};
    final spentUsdByEnvelope = <String, int>{};
    var incomeMinor = 0;
    var spentMinor = 0;
    var cashSpent = 0;
    for (final tx in transactions) {
      final inDisplay = tx.amount.inCurrency(displayCur, s.rate).minor;
      if (tx.type == TxType.income) {
        incomeMinor += inDisplay;
        continue;
      }
      spentMinor += inDisplay;
      if (tx.method == Method.cash) cashSpent += inDisplay;
      final envelope = envelopeById[tx.envelopeId];
      if (envelope != null) {
        spentByEnvelope.update(
          envelope.id,
          (value) =>
              value +
              tx.amount.inCurrency(envelope.limit.currency, s.rate).minor,
          ifAbsent: () =>
              tx.amount.inCurrency(envelope.limit.currency, s.rate).minor,
        );
        spentUsdByEnvelope.update(
          envelope.id,
          (value) => value + inDisplay,
          ifAbsent: () => inDisplay,
        );
      }
    }
    final income = Money(incomeMinor, displayCur);
    final spent = Money(spentMinor, displayCur);
    final saved = Money(
      savings.fold(
          0, (sum, tx) => sum + tx.amount.inCurrency(displayCur, s.rate).minor),
      displayCur,
    );
    final cashLeakShare = spent.minor == 0 ? 0.0 : cashSpent / spent.minor;

    final trackedEnvelopes = s.envelopes.where((e) => !e.isPersonal).toList();
    final onTrack = trackedEnvelopes
        .where((e) =>
            (spentByEnvelope[e.id] ?? 0) <=
            (_cycleOffset == 0 ? s.effectiveLimit(e) : e.limit).minor)
        .length;
    final envelopeHealth =
        trackedEnvelopes.isEmpty ? 1.0 : onTrack / trackedEnvelopes.length;
    final days = periodEnd.difference(periodStart).inDays;
    final historicDaily = days <= 0
        ? 0
        : ((income.minor - spent.minor - saved.minor) / days).floor();
    final safePerDay = _cycleOffset == 0
        ? s.safeToSpend
        : Money(historicDaily < 0 ? 0 : historicDaily, displayCur);

    return Scaffold(
      appBar: AppBar(
        title: Text(tStr(context, 'reportTitle')),
        actions: [
          PopupMenuButton<int>(
            tooltip: MaterialLocalizations.of(context).showMenuTooltip,
            icon: const Icon(Icons.tune_rounded),
            initialValue: _cycleOffset,
            onSelected: (value) => setState(() => _cycleOffset = value),
            itemBuilder: (context) => [
              for (var offset = 0; offset < 3; offset++)
                PopupMenuItem<int>(
                  value: offset,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: offset == _cycleOffset
                            ? Icon(Icons.check,
                                size: 19, color: context.primary)
                            : null,
                      ),
                      Expanded(
                        child: Text(
                          _periodLabel(
                            context,
                            _cycleStart(s, offset),
                            _cycleStart(s, offset - 1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
            onRefresh: () => s.refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_month_outlined,
                            size: 17, color: context.primary),
                        const SizedBox(width: 7),
                        Text(
                          periodLabel,
                          style: TextStyle(
                            color: context.inkSoft,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ── Stat grid ────────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _stat(
                        context,
                        tStr(context, 'income'),
                        income.text,
                        context.incomeGreen,
                        Icons.trending_up,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _stat(
                        context,
                        tStr(context, 'spent'),
                        spent.text,
                        context.expenseRed,
                        Icons.trending_down,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _stat(
                        context,
                        tStr(context, 'saved'),
                        saved.text,
                        context.primary,
                        Icons.track_changes,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _stat(
                        context,
                        tStr(context, 'safePerDay'),
                        safePerDay.text,
                        context.ink,
                        Icons.wb_twilight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Envelope health ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      RingProgress(
                        value: envelopeHealth,
                        size: 74,
                        stroke: 9,
                        color: envelopeHealth >= 0.7
                            ? context.primary
                            : context.accent,
                        child: Text(
                          '${(envelopeHealth * 100).round()}%',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: context.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tStr(context, 'envelopeHealth'),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: context.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppLocalizations.of(context)!.reachedMove(
                                onTrack,
                                trackedEnvelopes.length,
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: context.inkSoft,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Cash leak ────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(18),
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
                              tStr(context, 'cashLeak'),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: context.ink,
                              ),
                            ),
                          ),
                          Text(
                            AppLocalizations.of(context)!
                                .cashShare((cashLeakShare * 100).round()),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: context.accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: cashLeakShare,
                          minHeight: 8,
                          backgroundColor: context.track,
                          color: context.accent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)!.cashTrace,
                        style: TextStyle(
                            fontSize: 11.5,
                            color: context.inkSoft,
                            height: 1.35),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Top envelopes ────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.whereMoneyWent,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: context.ink,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _WhereItWent(
                        state: s,
                        spentUsdByEnvelope: spentUsdByEnvelope,
                      ),
                      const SizedBox(height: 14),
                      _TrendCard(state: s),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const FamilyMeetingScreen()),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.primary,
                    foregroundColor: context.onSolid,
                    minimumSize: const Size.fromHeight(52),
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.groups),
                  label: Text(
                    AppLocalizations.of(context)!.meetingCta,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final path = await AppScope.of(context).exportCsv();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          path == null
                              ? AppLocalizations.of(context)!.exportFailed
                              : AppLocalizations.of(context)!.csvSaved(path),
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.primary,
                    side: BorderSide(color: context.primary),
                    minimumSize: const Size.fromHeight(48),
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.table_view, size: 20),
                  label: Text(AppLocalizations.of(context)!.exportCsv),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    AppLocalizations.of(context)!.bringToMeeting,
                    style: TextStyle(fontSize: 11.5, color: context.inkSoft),
                  ),
                ),
              ],
            )),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value, Color color,
          IconData icon) =>
      Container(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.hairline)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: context.primary),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(fontSize: 11.5, color: context.inkSoft),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      );
}

/// ── G4: interactive spend donut ─────────────────────────────────────────────
class _WhereItWent extends StatefulWidget {
  final AppState state;
  final Map<String, int> spentUsdByEnvelope;

  const _WhereItWent({
    required this.state,
    required this.spentUsdByEnvelope,
  });

  @override
  State<_WhereItWent> createState() => _WhereItWentState();
}

class _WhereItWentState extends State<_WhereItWent> {
  int _sel = 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final palette = [
      context.primary,
      context.accent,
      context.incomeGreen,
      context.expenseRed,
      context.primaryDark,
      const Color(0xFF7EC8F2),
      const Color(0xFFFF6B6B),
    ];

    final spent = <MapEntry<String, (double, Color)>>[
      for (var i = 0; i < s.envelopes.length; i++)
        if (!s.envelopes[i].isPersonal &&
            (widget.spentUsdByEnvelope[s.envelopes[i].id] ?? 0) > 0)
          MapEntry(
            s.envelopes[i].name,
            (
              (widget.spentUsdByEnvelope[s.envelopes[i].id] ?? 0) / 100.0,
              palette[i % palette.length],
            ),
          ),
    ]..sort((a, b) => b.value.$1.compareTo(a.value.$1));

    if (spent.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          AppLocalizations.of(context)!.donutEmpty,
          style: TextStyle(fontSize: 12.5, color: context.inkSoft, height: 1.4),
        ),
      );
    }

    // Top 6 slices, rest folded into "Other".
    var rows = spent.take(6).toList();
    final restTotal = spent.skip(6).fold<double>(0, (a, e) => a + e.value.$1);
    if (restTotal > 0) {
      rows = [
        ...rows,
        MapEntry('Other', (restTotal, context.track)),
      ];
    }
    final total = rows.fold<double>(0, (a, e) => a + e.value.$1);
    if (_sel >= rows.length) _sel = 0;

    final selName = rows[_sel].key;
    final selAmount = rows[_sel].value.$1;
    final selShare = total > 0 ? (selAmount / total * 100).round() : 0;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Semantics(
              label: AppLocalizations.of(context)!.donutA11y(selName, selShare),
              child: DonutChart(
                segments: [
                  for (final r in rows) (r.key, r.value.$1, r.value.$2),
                ],
                selected: _sel,
                onTap: (i) => setState(() => _sel = i),
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selName,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$selShare%',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: context.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _sel = i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: rows[i].value.$2,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                rows[i].key,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: i == _sel
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: context.ink,
                                ),
                              ),
                            ),
                            Text(
                              '${(rows[i].value.$1 / total * 100).round()}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: context.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// ── G4: six-month net trend ─────────────────────────────────────────────────
class _TrendCard extends StatelessWidget {
  final AppState state;

  const _TrendCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final s = state;
    final now = DateTime.now();
    final firstMonth = DateTime(now.year, now.month - 5, 1);
    final afterLastMonth = DateTime(now.year, now.month + 1, 1);
    final totals = <int, double>{};
    for (final tx in s.txs) {
      if (tx.when.isBefore(firstMonth) || !tx.when.isBefore(afterLastMonth)) {
        continue;
      }
      final key = tx.when.year * 12 + tx.when.month;
      final amt = tx.amount.inCurrency(s.displayCurrency, s.rate).minor / 100.0;
      totals.update(
        key,
        (value) => value + (tx.type == TxType.income ? amt : -amt),
        ifAbsent: () => tx.type == TxType.income ? amt : -amt,
      );
    }
    final bars = <(String, double)>[];
    for (var i = 5; i >= 0; i--) {
      final start = DateTime(now.year, now.month - i, 1);
      final key = start.year * 12 + start.month;
      bars.add((DateFormat('MMM').format(start), totals[key] ?? 0));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.sixMonthNet,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: context.ink,
          ),
        ),
        const SizedBox(height: 10),
        TrendBars(
          bars: bars,
          positive: context.incomeGreen,
          negative: context.expenseRed,
          track: context.track,
          labelColor: context.inkSoft,
        ),
      ],
    );
  }
}
