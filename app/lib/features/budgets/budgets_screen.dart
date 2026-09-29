import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/utils/ids.dart';

import '../../core/widgets/ui.dart';
import '../../core/money/money.dart';
import '../../core/models/models.dart';
import '../../core/state/app_state.dart';
import '../../core/widgets/app_icons.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/tx_tile.dart';
import 'recurring_ui.dart';

void showEnvelopeDetailSheet(BuildContext context, Envelope envelope) {
  final state = AppScope.of(context);
  showMhuriSheet<void>(
    context: context,
    builder: (_) => _EnvelopeDetail(e: envelope, s: state),
  );
}

/// Envelope budgets (spec Module D, screen §7.3).
class BudgetsScreen extends StatelessWidget {
  final bool standalone;
  const BudgetsScreen({super.key, this.standalone = false});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final l = AppLocalizations.of(context)!;
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final isStandalone = standalone || canPop;
    final language = Localizations.localeOf(context).languageCode;
    final locale =
        const {'es', 'fr', 'pt'}.contains(language) ? language : 'en';
    final cycleEnd = s.nextCycleStart.subtract(const Duration(days: 1));
    final cycleLabel = '${DateFormat.MMMd(locale).format(s.cycleStart)} - '
        '${DateFormat.MMMd(locale).format(cycleEnd)}';

    final datePill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        cycleLabel,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: context.inkSoft,
        ),
      ),
    );

    final left = <Widget>[
      if (!isStandalone)
        Row(
          children: [
            Expanded(
              child: PageHeader(l.budgetsTitle),
            ),
            datePill,
          ],
        )
      else
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: datePill,
          ),
        ),
      const SizedBox(height: 16),

      // ── Envelopes ───────────────────────────────────────────────────
      if (s.envelopes.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: EmptyState(
            icon: Icons.mail_outline,
            title: l.noEnvelopes,
            subtitle: l.envelopesHint,
          ),
        ),
      for (final e in s.envelopes)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _EnvelopeCard(e: e),
        ),
      ElevatedButton.icon(
        onPressed: () => _showNewEnvelopeSheet(context, s),
        style: ElevatedButton.styleFrom(
          backgroundColor: context.primary,
          foregroundColor: context.onSolid,
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
        ),
        icon: const Icon(Icons.add),
        label: Text(l.newEnvelope),
      ),
    ];
    final right = <Widget>[
      Row(
        children: [
          Expanded(
            child: Text(
              l.recurringExpenses,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.ink,
              ),
            ),
          ),
          IconButton(
            tooltip: l.addRecurringTip,
            onPressed: () => showAddRecurringSheet(context),
            icon: Icon(Icons.add_circle, color: context.primary, size: 28),
          ),
        ],
      ),
      Text(
        l.recReviewed,
        style: TextStyle(fontSize: 12, color: context.inkSoft),
      ),
      const SizedBox(height: 12),
      if (s.recurring.isEmpty)
        EmptyState(
          icon: Icons.autorenew,
          title: l.noRecurring,
          subtitle: l.recurringHint,
        )
      else
        for (final r in s.recurring) RecurringRow(rule: r),
    ];
    const pad = kTabPageInsets;

    final Widget content = SafeArea(
      child: RefreshIndicator(
        onRefresh: () => s.refresh(),
        child: LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth >= 900) {
              return Row(
                children: [
                  Expanded(child: ListView(padding: pad, children: left)),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(child: ListView(padding: pad, children: right)),
                ],
              );
            }
            return ListView(
              padding: pad,
              children: [...left, const SizedBox(height: 24), ...right],
            );
          },
        ),
      ),
    );

    if (isStandalone) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l.budgetsTitle),
        ),
        body: content,
      );
    }

    return Material(
      color: Colors.transparent,
      child: content,
    );
  }
}

Future<void> _showNewEnvelopeSheet(BuildContext context, AppState state) async {
  final l = AppLocalizations.of(context)!;
  final name = TextEditingController();
  final limit = TextEditingController();
  var currency = state.displayCurrency;
  var rollover = Rollover.reset;

  // Unsaved-changes guard: only fires when the user actually typed - an
  // untouched sheet dismisses freely (standing UX rule).
  var guardArmed = false;
  void armGuard() => guardArmed = true;
  String? formError;

  final result = await showMhuriSheet<
      ({String name, double limit, Currency currency, Rollover rollover})>(
    context: context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SheetHeader(
              l.newEnvelope,
              onClose: () async {
                if (!guardArmed ||
                    (name.text.trim().isEmpty && limit.text.trim().isEmpty)) {
                  Navigator.pop(sheetContext);
                  return;
                }
                final leave = await confirmDialog(
                  sheetContext,
                  title: l.discardChangesTitle,
                  body: l.discardChangesBody,
                  confirmLabel: l.leave,
                );
                if (leave && sheetContext.mounted) {
                  Navigator.pop(sheetContext);
                }
              },
            ),
            const SizedBox(height: 12),
            MhuriField(
              controller: name,
              label: l.envelopeLabel,
              onChanged: (_) {
                armGuard();
                if (formError != null) {
                  setSheetState(() => formError = null);
                }
              },
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              fillColor: sheetContext.card,
            ),
            const SizedBox(height: 12),
            MhuriField(
              controller: limit,
              label: l.limitLabel,
              inputFormatters: amountInputFormatters,
              onChanged: (_) {
                armGuard();
                if (formError != null) {
                  setSheetState(() => formError = null);
                }
              },
              currencySymbol: currency.symbol,
              prefixText: '${currency.symbol} ',
              fillColor: sheetContext.card,
            ),
            const SizedBox(height: 12),
            if (state.activeCurrencies.length > 1) ...[
              SegmentedButton<Currency>(
                segments: [
                  for (final c in state.activeCurrencies)
                    ButtonSegment(value: c, label: Text(c.short)),
                ],
                selected: {currency},
                onSelectionChanged: (value) =>
                    setSheetState(() => currency = value.first),
              ),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<Rollover>(
              initialValue: rollover,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: sheetContext.card,
                border: const OutlineInputBorder(borderSide: BorderSide.none),
              ),
              items: [
                DropdownMenuItem(
                  value: Rollover.reset,
                  child: Text(l.rollReset),
                ),
                DropdownMenuItem(
                  value: Rollover.roll,
                  child: Text(l.rollRoll),
                ),
                DropdownMenuItem(
                  value: Rollover.accumulate,
                  child: Text(l.rollAccum),
                ),
              ],
              onChanged: (value) {
                if (value != null) setSheetState(() => rollover = value);
              },
            ),
            if (formError != null) ...[
              const SizedBox(height: 14),
              ErrorNotice(formError!),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                final amount =
                    double.tryParse(limit.text.trim().replaceAll(',', ''));
                if (name.text.trim().isEmpty) {
                  setSheetState(() => formError = l.envelopeLabel);
                  return;
                }
                if (amount == null || amount <= 0) {
                  setSheetState(() => formError = l.enterAmountFirst);
                  return;
                }
                Navigator.pop(
                  sheetContext,
                  (
                    name: name.text.trim(),
                    limit: amount,
                    currency: currency,
                    rollover: rollover,
                  ),
                );
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: const StadiumBorder(),
              ),
              child: Text(l.save),
            ),
          ],
        ),
      ),
    ),
  );
  if (result == null) return;
  state.addEnvelope(
    name: result.name,
    limit: Money.fromMajor(result.limit, result.currency),
    rollover: result.rollover,
  );
}

class _EnvelopeCard extends StatelessWidget {
  final Envelope e;

  const _EnvelopeCard({required this.e});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final spent = s.spentOn(e);
    final effectiveLimit = s.effectiveLimit(e);
    final remaining = s.remainingOn(e);
    final pace = s.paceOf(e);
    final value =
        effectiveLimit.minor <= 0 ? 0.0 : (spent.minor / effectiveLimit.minor);
    final over = remaining.minor < 0;

    return InkWell(
      onTap: () => _openDetail(context, s),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                iconForKey(e.emoji) ?? Icons.savings,
                size: 21,
                color: context.primaryDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          e.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (e.isPersonal)
                        Icon(Icons.lock, size: 12, color: context.inkSoft),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          rolloverLabel(
                              AppLocalizations.of(context)!, e.rollover),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 10.5, color: context.inkSoft),
                        ),
                      ),
                    ],
                  ),
                  if (effectiveLimit.minor <= 0 && spent.minor <= 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'No limit set',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.inkSoft,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to set budget amount',
                      style: TextStyle(
                          fontSize: 10.5,
                          color: context.primary,
                          fontWeight: FontWeight.w600),
                    ),
                  ] else ...[
                    const SizedBox(height: 4),
                    Text(
                      s.hideAmounts
                          ? '••••• left'
                          : over
                              ? AppLocalizations.of(context)!.overBy(
                                  Money(-remaining.minor, remaining.currency)
                                      .text)
                              : '${remaining.text} left',
                      style: TextStyle(
                        fontSize: 13,
                        color: over ? context.expenseRed : context.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.hideAmounts
                          ? '••••• spent'
                          : '${spent.text} spent of ${effectiveLimit.text}',
                      style: TextStyle(fontSize: 10.5, color: context.inkSoft),
                    ),
                  ],
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: value.clamp(0.0, 1.0).toDouble(),
                      minHeight: 7,
                      backgroundColor: context.track,
                      color:
                          over ? context.expenseRed : _paceColor(context, pace),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (effectiveLimit.minor <= 0 && spent.minor <= 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: context.track,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'No limit',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.inkSoft,
                  ),
                ),
              )
            else
              _PaceChip(pace: pace),
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, AppState s) {
    if (s.effectiveLimit(e).minor <= 0 && s.canEditBudgets) {
      showEditEnvelopeSheet(context, s, e);
    } else {
      showEnvelopeDetailSheet(context, e);
    }
  }
}

class _PaceChip extends StatelessWidget {
  final Pace pace;

  const _PaceChip({required this.pace});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (pace) {
      Pace.onTrack => (
          AppLocalizations.of(context)!.chipOnTrack,
          const Color(0xFFD9EDE8)
        ),
      Pace.watch => (
          AppLocalizations.of(context)!.watch,
          const Color(0xFFFBE7C6)
        ),
      Pace.over => (
          AppLocalizations.of(context)!.overBudgetLabel,
          const Color(0xFFF9E0DF)
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: context.ink),
      ),
    );
  }
}

// ── Envelope detail + move money (D6/D7) ────────────────────────────────────

class _EnvelopeDetail extends StatefulWidget {
  final Envelope e;
  final AppState s;

  const _EnvelopeDetail({required this.e, required this.s});

  @override
  State<_EnvelopeDetail> createState() => _EnvelopeDetailState();
}

class _EnvelopeDetailState extends State<_EnvelopeDetail> {
  Envelope? _from;
  Envelope? _to;
  bool _moving = false;
  String? _moveError;
  final _amount = TextEditingController();
  final _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    _from = widget.e;
    for (final x in widget.s.envelopes) {
      if (x.id != widget.e.id) {
        _to = x;
        break;
      }
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final l = AppLocalizations.of(context)!;
    final e = widget.e;
    final spent = s.spentOn(e);
    final remaining = s.remainingOn(e);
    final effectiveLimit = s.effectiveLimit(e);
    final inEnvelope =
        s.txs.where((t) => t.envelopeId == e.id).take(4).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        decoration: BoxDecoration(
          color: context.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  iconForKey(e.emoji) ?? Icons.savings,
                  size: 28,
                  color: context.primaryDark,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    e.name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: context.ink,
                    ),
                  ),
                ),
                Text(
                  e.limit.currency.short,
                  style: TextStyle(fontSize: 12, color: context.inkSoft),
                ),
                if (s.canEditBudgets)
                  PopupMenuButton<String>(
                    tooltip: 'Budget actions',
                    onSelected: (action) async {
                      if (action == 'edit') {
                        await showEditEnvelopeSheet(context, s, e);
                        if (mounted) setState(() {});
                      } else if (action == 'archive') {
                        final ok = await confirmDialog(
                          context,
                          title: 'Archive ${e.name} budget?',
                          body:
                              'It will no longer accept new spending, but previous transactions will remain in your history.',
                          confirmLabel: 'Archive budget',
                          danger: true,
                        );
                        if (!context.mounted) return;
                        if (ok && mounted && s.archiveEnvelope(e)) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Budget archived'),
                                  behavior: SnackBarBehavior.floating));
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'edit', child: Text('Edit budget')),
                      if (s.canAdmin)
                        const PopupMenuItem(
                            value: 'archive', child: Text('Archive budget')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _stat(AppLocalizations.of(context)!.spentLabel, spent.text),
                _stat(
                  remaining.minor < 0
                      ? AppLocalizations.of(context)!.overBudgetLabel
                      : AppLocalizations.of(context)!.remaining,
                  remaining.minor < 0
                      ? Money(-remaining.minor, remaining.currency).text
                      : remaining.text,
                  danger: remaining.minor < 0,
                ),
                _stat(
                  AppLocalizations.of(context)!.limitLabel,
                  effectiveLimit.text,
                  onTap: s.canEditBudgets
                      ? () async {
                          await showEditEnvelopeSheet(context, s, e);
                          if (mounted) setState(() {});
                        }
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              AppLocalizations.of(context)!.moveMoney,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: context.ink),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<Envelope>(
                    initialValue: _from,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l.transferFrom,
                      filled: true,
                      fillColor: context.card,
                      border:
                          const OutlineInputBorder(borderSide: BorderSide.none),
                    ),
                    items: [
                      for (final x in s.envelopes)
                        DropdownMenuItem(
                          value: x,
                          child: Row(
                            children: [
                              Icon(
                                iconForKey(x.emoji) ?? Icons.savings,
                                size: 16,
                                color: context.primaryDark,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  x.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      _from = v;
                      if (_to == _from) _to = null;
                    }),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward,
                      size: 18, color: context.inkSoft),
                ),
                Expanded(
                  child: DropdownButtonFormField<Envelope>(
                    initialValue: _to,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l.transferTo,
                      filled: true,
                      fillColor: context.card,
                      border:
                          const OutlineInputBorder(borderSide: BorderSide.none),
                    ),
                    items: [
                      for (final x
                          in s.envelopes.where((x) => x.id != _from?.id))
                        DropdownMenuItem(
                          value: x,
                          child: Row(
                            children: [
                              Icon(
                                iconForKey(x.emoji) ?? Icons.savings,
                                size: 16,
                                color: context.primaryDark,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  x.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _to = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: amountInputFormatters,
                    onChanged: (_) {
                      if (_moveError != null) setState(() => _moveError = null);
                    },
                    decoration: InputDecoration(
                      labelText:
                          'Amount (${_from?.limit.currency.symbol ?? ''})',
                      filled: true,
                      fillColor: context.card,
                      border:
                          const OutlineInputBorder(borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MhuriField(
                    controller: _reason,
                    label: l.transferWhy,
                  ),
                ),
              ],
            ),
            if (_moveError != null) ...[
              const SizedBox(height: 10),
              ErrorNotice(_moveError!),
            ],
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _moving
                  ? null
                  : () {
                      final v =
                          double.tryParse(_amount.text.replaceAll(',', ''));
                      if (_from == null || _to == null) {
                        setState(() => _moveError =
                            AppLocalizations.of(context)!.pickFirst);
                        return;
                      }
                      if (v == null || v <= 0) {
                        setState(() => _moveError =
                            AppLocalizations.of(context)!.enterAmountFirst);
                        return;
                      }
                      setState(() => _moving = true);
                      try {
                        final messenger = ScaffoldMessenger.of(context);
                        s.moveMoney(
                          _from!,
                          _to!,
                          Money.fromMajor(v, _from!.limit.currency),
                          _reason.text.isEmpty ? 're-plan' : _reason.text,
                          id: newUuid(),
                        );
                        Navigator.pop(context);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Moved ${Money.fromMajor(v, _from!.limit.currency).text}'
                              ' → ${_to!.name} ✓',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } finally {
                        if (mounted) setState(() => _moving = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.primary,
                foregroundColor: context.onSolid,
                minimumSize: const Size.fromHeight(50),
                shape: const StadiumBorder(),
              ),
              child: _moving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator.adaptive(
                        strokeWidth: 2,
                      ),
                    )
                  : Text(AppLocalizations.of(context)!.moveMoney),
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context)!.recentInEnv,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: context.ink),
            ),
            const SizedBox(height: 10),
            if (inEnvelope.isEmpty)
              Text(
                AppLocalizations.of(context)!.nothingLogged,
                style: TextStyle(fontSize: 13, color: context.inkSoft),
              )
            else
              for (final t in inEnvelope)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TxTile(tx: t, dense: true),
                ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, {bool danger = false, VoidCallback? onTap}) => Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label,
                          style: TextStyle(fontSize: 11, color: context.inkSoft)),
                      if (onTap != null) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.edit, size: 10, color: context.primary),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: danger ? context.expenseRed : context.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

Future<void> showEditEnvelopeSheet(
    BuildContext context, AppState state, Envelope envelope) async {
  final name = TextEditingController(text: envelope.name);
  final amount = TextEditingController(
      text: envelope.limit.minor <= 0
          ? ''
          : (envelope.limit.minor / 100).toStringAsFixed(2));
  var rollover = envelope.rollover;
  String? error;
  final isNew = envelope.limit.minor <= 0;
  await showMhuriSheet<void>(
    context: context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheet) => MhuriSheetShell(
        title: isNew ? 'Set ${envelope.name} budget' : 'Edit budget',
        footer: PrimaryButton(
          label: isNew ? 'Set budget' : 'Save changes',
          onPressed: () {
            final parsed = double.tryParse(amount.text.replaceAll(',', ''));
            if (name.text.trim().isEmpty || parsed == null || parsed <= 0) {
              setSheet(() => error = 'Enter a valid budget amount.');
              return;
            }
            state.updateEnvelope(
              envelope,
              name: name.text,
              limit: Money.fromMajor(parsed, envelope.limit.currency),
              rollover: rollover,
            );
            final messenger = ScaffoldMessenger.of(context);
            Navigator.pop(sheetContext);
            messenger.showSnackBar(SnackBar(
                content: Text(isNew
                    ? '${envelope.name} budget set to ${envelope.limit.currency.symbol}${parsed.toStringAsFixed(2)}'
                    : 'Budget updated'),
                behavior: SnackBarBehavior.floating));
          },
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              autofocus: isNew,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: amountInputFormatters,
              decoration: InputDecoration(
                  labelText:
                      'Monthly budget (${envelope.limit.currency.symbol})'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Rollover>(
              initialValue: rollover,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Period'),
              items: [
                for (final value in Rollover.values)
                  DropdownMenuItem(value: value, child: Text(value.label))
              ],
              onChanged: (value) {
                if (value != null) setSheet(() => rollover = value);
              },
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              ErrorNotice(error!)
            ],
          ],
        ),
      ),
    ),
  );
}

Color _paceColor(BuildContext context, Pace p) => switch (p) {
      Pace.onTrack => context.primary,
      Pace.watch => context.accent,
      Pace.over => context.danger,
    };
