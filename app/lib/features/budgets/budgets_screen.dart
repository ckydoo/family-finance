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
class BudgetsScreen extends StatefulWidget {
  final bool standalone;
  const BudgetsScreen({super.key, this.standalone = false});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

enum _BudgetFilter { all, nearLimit, exceeded }

class _BudgetsScreenState extends State<BudgetsScreen> {
  bool _searching = false;
  String _query = '';
  _BudgetFilter _filter = _BudgetFilter.all;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final l = AppLocalizations.of(context)!;
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final isStandalone = widget.standalone || canPop;
    final language = Localizations.localeOf(context).languageCode;
    final locale =
        const {'es', 'fr', 'pt'}.contains(language) ? language : 'en';
    final cycleEnd = s.nextCycleStart.subtract(const Duration(days: 1));
    final cycleLabel = '${DateFormat.MMMd(locale).format(s.cycleStart)} - '
        '${DateFormat.MMMd(locale).format(cycleEnd)}';

    final query = _query.trim().toLowerCase();
    final envelopes = s.envelopes.where((envelope) {
      final matchesQuery =
          query.isEmpty || envelope.name.toLowerCase().contains(query);
      final remaining = s.remainingOn(envelope).minor;
      final matchesFilter = switch (_filter) {
        _BudgetFilter.all => true,
        _BudgetFilter.nearLimit =>
          remaining >= 0 && s.paceOf(envelope) == Pace.watch,
        _BudgetFilter.exceeded => remaining < 0,
      };
      return matchesQuery && matchesFilter;
    }).toList();

    final Widget content = SafeArea(
      child: RefreshIndicator(
        onRefresh: () => s.refresh(),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isStandalone)
                      Row(children: [
                        Expanded(child: PageHeader(l.budgetsTitle)),
                        IconButton(
                          tooltip: 'Search budgets',
                          onPressed: () =>
                              setState(() => _searching = !_searching),
                          icon: const Icon(Icons.search),
                        ),
                        if (s.canEditBudgets)
                          IconButton(
                            tooltip: l.newEnvelope,
                            onPressed: () => _showNewEnvelopeSheet(context, s),
                            icon: Icon(Icons.add_circle_rounded,
                                color: context.primary, size: 30),
                          ),
                      ]),
                    if (_searching) ...[
                      const SizedBox(height: 10),
                      TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search budgets',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            tooltip: 'Close search',
                            onPressed: () => setState(() {
                              _searching = false;
                              _query = '';
                            }),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                        onChanged: (value) => setState(() => _query = value),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _CyclePlanCard(state: s, cycleLabel: cycleLabel),
                    const SizedBox(height: 10),
                    _RegularPaymentsCard(state: s),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: Text('Budgets',
                            style: Theme.of(context).textTheme.titleMedium),
                      ),
                      Text('${envelopes.length}',
                          style: TextStyle(color: context.inkSoft)),
                    ]),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, children: [
                      for (final filter in _BudgetFilter.values)
                        ChoiceChip(
                          label: Text(switch (filter) {
                            _BudgetFilter.all => 'All',
                            _BudgetFilter.nearLimit => 'Near limit',
                            _BudgetFilter.exceeded => 'Exceeded',
                          }),
                          selected: _filter == filter,
                          onSelected: (_) => setState(() => _filter = filter),
                        ),
                    ]),
                    if (s.envelopes.isEmpty)
                      EmptyState(
                        icon: Icons.mail_outline,
                        title: l.noEnvelopes,
                        subtitle: l.envelopesHint,
                      )
                    else if (envelopes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                          child: Text('No budgets match this view.',
                              style: TextStyle(color: context.inkSoft)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.separated(
                itemCount: envelopes.length,
                itemBuilder: (_, index) => _EnvelopeCard(e: envelopes[index]),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.only(bottom: 100),
              sliver: SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
          ],
        ),
      ),
    );

    if (isStandalone) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l.budgetsTitle),
          actions: [
            IconButton(
              tooltip: 'Search budgets',
              onPressed: () => setState(() => _searching = !_searching),
              icon: const Icon(Icons.search),
            ),
            if (s.canEditBudgets)
              IconButton(
                tooltip: l.newEnvelope,
                onPressed: () => _showNewEnvelopeSheet(context, s),
                icon: const Icon(Icons.add_rounded),
              ),
          ],
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

class _RegularPaymentsCard extends StatelessWidget {
  const _RegularPaymentsCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final active = state.recurring.where((rule) => rule.active).length;
    return Material(
      color: context.card,
      borderRadius: kBRadiusM,
      child: InkWell(
        borderRadius: kBRadiusM,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const _RegularPaymentsScreen(),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: kBRadiusM,
            border: Border.all(color: context.hairline.withValues(alpha: 0.7)),
          ),
          child: Row(children: [
            SizedBox(
              width: 38,
              height: 38,
              child: Center(
                child: Icon(Icons.autorenew_rounded,
                    size: 22, color: context.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.recurringExpenses,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: context.ink)),
                  const SizedBox(height: 2),
                  Text(
                    state.recurring.isEmpty
                        ? l.noRecurring
                        : '$active active ${active == 1 ? 'payment' : 'payments'}',
                    style: TextStyle(fontSize: 12, color: context.inkSoft),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 21, color: context.inkSoft),
          ]),
        ),
      ),
    );
  }
}

class _RegularPaymentsScreen extends StatelessWidget {
  const _RegularPaymentsScreen();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.recurringExpenses),
        actions: [
          IconButton(
            tooltip: l.addRecurringTip,
            onPressed: () => showAddRecurringSheet(context),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: state.recurring.isEmpty
          ? EmptyState(
              icon: Icons.autorenew,
              title: l.noRecurring,
              subtitle: l.recurringHint,
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              itemCount: state.sortedBills.length,
              itemBuilder: (_, index) =>
                  RecurringRow(rule: state.sortedBills[index]),
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: context.hairline),
            ),
    );
  }
}

class _CyclePlanCard extends StatelessWidget {
  const _CyclePlanCard({required this.state, required this.cycleLabel});
  final AppState state;
  final String cycleLabel;

  @override
  Widget build(BuildContext context) {
    final plan = state.currentBudgetPlan;
    final allocated = state.envelopes.fold<int>(
        0,
        (sum, e) =>
            sum + e.limit.inCurrency(state.displayCurrency, state.rate).minor);
    final allocation = Money(allocated, state.displayCurrency);
    final expected =
        plan?.expectedIncome?.inCurrency(state.displayCurrency, state.rate);
    final expectedLabel = plan == null
        ? 'Not set'
        : plan.incomeMode == IncomePlanMode.knownMonthly
            ? expected?.text ?? '—'
            : 'As earned';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.primaryDark, context.primary],
        ),
        borderRadius: kBRadiusL,
        boxShadow: [
          BoxShadow(
            color: context.primary.withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: Icon(Icons.event_note_outlined,
                  color: Colors.white, size: 23),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
              child: Text('This month\'s plan',
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Colors.white))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Text(
              plan == null ? 'Not set' : (plan.isClosed ? 'Closed' : 'Active'),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.date_range_outlined,
                size: 15, color: Colors.white.withValues(alpha: 0.72)),
            const SizedBox(width: 6),
            Text(
              cycleLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.78),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.10),
            borderRadius: kBRadiusM,
          ),
          child: Row(children: [
            Expanded(
                child: _PlanMetric(label: 'Expected', value: expectedLabel)),
            Container(
              width: 1,
              height: 34,
              color: Colors.white.withValues(alpha: 0.20),
            ),
            Expanded(
              child: _PlanMetric(
                  label: 'Allocated', value: allocation.text, alignEnd: true),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (!(plan?.isClosed ?? false))
            FilledButton.icon(
              onPressed: state.canEditBudgets
                  ? () => _showPlanSheet(context, state)
                  : null,
              icon: Icon(plan == null ? Icons.add : Icons.edit_outlined,
                  size: 18),
              label: Text(plan == null ? 'Set up plan' : 'Edit plan'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: context.primaryDark,
              ),
            ),
          if (plan == null && state.previousBudgetPlan != null)
            OutlinedButton.icon(
              onPressed: state.canEditBudgets
                  ? () {
                      state.useLastMonthPlan();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content:
                              Text('Last month\'s plan is ready to review.')));
                    }
                  : null,
              icon: const Icon(Icons.content_copy_outlined, size: 18),
              label: const Text('Use last month'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
              ),
            ),
          if (plan != null && !plan.isClosed)
            OutlinedButton.icon(
              onPressed: state.canEditBudgets
                  ? () async {
                      final ok = await confirmDialog(context,
                          title: 'Close this month?',
                          body:
                              'This locks the agreed plan as a monthly record. Transactions remain unchanged.',
                          confirmLabel: 'Close month');
                      if (ok) state.closeCurrentBudgetPlan();
                    }
                  : null,
              icon: const Icon(Icons.lock_outline_rounded, size: 17),
              label: const Text('Close month'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
              ),
            ),
        ]),
      ]),
    );
  }
}

class _PlanMetric extends StatelessWidget {
  const _PlanMetric({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.68))),
          const SizedBox(height: 2),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ],
      );
}

Future<void> _showPlanSheet(BuildContext context, AppState state) async {
  var mode = state.currentBudgetPlan?.incomeMode ?? IncomePlanMode.knownMonthly;
  final expected = TextEditingController(
      text: state.currentBudgetPlan?.expectedIncome?.major.toStringAsFixed(2) ??
          '');
  String? error;
  await showMhuriSheet<void>(
    context: context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 4, 20, 20 + MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SheetHeader('Plan this month',
                  onClose: () => Navigator.pop(sheetContext)),
              const SizedBox(height: 8),
              Text('How does your family receive income?',
                  style: TextStyle(color: sheetContext.inkSoft)),
              const SizedBox(height: 12),
              SegmentedButton<IncomePlanMode>(
                segments: const [
                  ButtonSegment(
                      value: IncomePlanMode.knownMonthly,
                      label: Text('Known monthly')),
                  ButtonSegment(
                      value: IncomePlanMode.asEarned,
                      label: Text('As I earn it')),
                ],
                selected: {mode},
                onSelectionChanged: (value) => setSheetState(() {
                  mode = value.first;
                  error = null;
                }),
              ),
              if (mode == IncomePlanMode.knownMonthly) ...[
                const SizedBox(height: 16),
                MhuriField(
                  controller: expected,
                  label: 'Expected income',
                  currencySymbol: state.displayCurrency.symbol,
                  prefixText: '${state.displayCurrency.symbol} ',
                  inputFormatters: amountInputFormatters,
                  fillColor: sheetContext.card,
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 12),
                ErrorNotice(error!),
              ],
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
                onPressed: () {
                  final value =
                      double.tryParse(expected.text.replaceAll(',', '').trim());
                  final ok = state.saveCurrentBudgetPlan(
                    incomeMode: mode,
                    expectedIncome:
                        mode == IncomePlanMode.knownMonthly && value != null
                            ? Money.fromMajor(value, state.displayCurrency)
                            : null,
                  );
                  if (!ok) {
                    setSheetState(() =>
                        error = 'Enter an expected income greater than zero.');
                    return;
                  }
                  Navigator.pop(sheetContext);
                },
                child: const Text('Save plan'),
              ),
            ]),
      ),
    ),
  );
  // Do not dispose here: showModalBottomSheet can complete its Future before
  // the reverse transition has rendered its final frame. The field may still
  // read the controller during that frame, which causes a use-after-dispose.
  // With no surviving references the controller is collected with the sheet.
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
                shape: RoundedRectangleBorder(borderRadius: kBRadiusM),
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
      onLongPress: s.canAdmin ? () => _confirmRemove(context, s) : null,
      borderRadius: kBRadiusM,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: kBRadiusM,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 38,
              height: 38,
              child: Icon(
                iconForKey(e.emoji) ?? Icons.savings_outlined,
                size: 20,
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
                      Expanded(
                        child: Text(
                          e.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: context.ink,
                          ),
                        ),
                      ),
                      if (e.isPersonal) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.lock_outline,
                            size: 12, color: context.inkSoft),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (effectiveLimit.minor <= 0 && spent.minor <= 0) ...[
                    Text(
                      'No limit set · Tap to set budget amount',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.primaryDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.hideAmounts
                                ? '••••• spent'
                                : '${spent.text} of ${effectiveLimit.text}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.inkSoft,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          s.hideAmounts
                              ? '•••••'
                              : over
                                  ? AppLocalizations.of(context)!.overBy(Money(
                                          -remaining.minor, remaining.currency)
                                      .text)
                                  : '${remaining.text} left',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: over ? context.expenseRed : context.ink,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    MhuriProgress(
                      progress: value,
                      color:
                          over ? context.expenseRed : _paceColor(context, pace),
                      height: 4,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (s.canAdmin)
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: PopupMenuButton<String>(
                      tooltip: 'Budget actions',
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.more_horiz,
                          size: 20, color: context.inkSoft),
                      onSelected: (action) async {
                        if (action == 'edit') {
                          await showEditEnvelopeSheet(context, s, e);
                        } else if (action == 'remove') {
                          await _confirmRemove(context, s);
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Edit budget'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'remove',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline,
                                  size: 18, color: context.expenseRed),
                              const SizedBox(width: 8),
                              Text('Remove budget',
                                  style: TextStyle(color: context.expenseRed)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (pace != Pace.onTrack &&
                    (effectiveLimit.minor > 0 || spent.minor > 0)) ...[
                  const SizedBox(height: 4),
                  _PaceChip(pace: pace),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, AppState s) async {
    final ok = await confirmDialog(
      context,
      title: 'Remove ${e.name} budget?',
      body:
          'This budget will be removed from your budget list. Previous transactions will remain in your history.',
      confirmLabel: 'Remove budget',
      danger: true,
    );
    if (!context.mounted) return;
    if (ok && s.archiveEnvelope(e)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${e.name} budget removed'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
    final (label, background, foreground) = switch (pace) {
      Pace.onTrack => (
          AppLocalizations.of(context)!.chipOnTrack,
          context.successSoft,
          context.primaryDark,
        ),
      Pace.watch => (
          AppLocalizations.of(context)!.watch,
          context.warningSoft,
          context.ink,
        ),
      Pace.over => (
          AppLocalizations.of(context)!.overBudgetLabel,
          context.dangerSoft,
          context.expenseRed,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
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
  String? _fromId;
  String? _toId;
  bool _moving = false;
  String? _moveError;
  final _amount = TextEditingController();
  final _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fromId = widget.e.id;
    for (final x in widget.s.envelopes) {
      if (x.id != widget.e.id) {
        _toId = x.id;
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
    final from = s.envelope(_fromId);
    final to = s.envelope(_toId);

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
                          title: 'Remove ${e.name} budget?',
                          body:
                              'This budget will be removed from your budget list. Previous transactions will remain in your history.',
                          confirmLabel: 'Remove budget',
                          danger: true,
                        );
                        if (!context.mounted) return;
                        if (ok && mounted && s.archiveEnvelope(e)) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('${e.name} budget removed'),
                              behavior: SnackBarBehavior.floating));
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Edit budget'),
                            ],
                          )),
                      if (s.canAdmin)
                        PopupMenuItem(
                          value: 'archive',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline,
                                  size: 18, color: context.expenseRed),
                              const SizedBox(width: 8),
                              Text('Remove budget',
                                  style: TextStyle(color: context.expenseRed)),
                            ],
                          ),
                        ),
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
                  child: DropdownButtonFormField<String>(
                    initialValue: s.envelopes.any((x) => x.id == _fromId)
                        ? _fromId
                        : null,
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
                        DropdownMenuItem<String>(
                          value: x.id,
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
                      _fromId = v;
                      if (_toId == _fromId) _toId = null;
                    }),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward,
                      size: 18, color: context.inkSoft),
                ),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: s.envelopes.any((x) => x.id == _toId) &&
                            _toId != _fromId
                        ? _toId
                        : null,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l.transferTo,
                      filled: true,
                      fillColor: context.card,
                      border:
                          const OutlineInputBorder(borderSide: BorderSide.none),
                    ),
                    items: [
                      for (final x in s.envelopes.where((x) => x.id != _fromId))
                        DropdownMenuItem<String>(
                          value: x.id,
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
                    onChanged: (v) => setState(() => _toId = v),
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
                          'Amount (${from?.limit.currency.symbol ?? ''})',
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
                      if (from == null || to == null) {
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
                          from,
                          to,
                          Money.fromMajor(v, from.limit.currency),
                          _reason.text.isEmpty ? 're-plan' : _reason.text,
                          id: newUuid(),
                        );
                        Navigator.pop(context);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Moved ${Money.fromMajor(v, from.limit.currency).text}'
                              ' → ${to.name} ✓',
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
                shape: RoundedRectangleBorder(borderRadius: kBRadiusM),
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

  Widget _stat(String label, String value,
          {bool danger = false, VoidCallback? onTap}) =>
      Expanded(
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
                          style:
                              TextStyle(fontSize: 11, color: context.inkSoft)),
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
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PrimaryButton(
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
            if (state.canAdmin) ...[
              const SizedBox(height: 8),
              SecondaryButton(
                label: 'Remove budget',
                icon: Icons.delete_outline,
                danger: true,
                onPressed: () async {
                  final ok = await confirmDialog(
                    context,
                    title: 'Remove ${envelope.name} budget?',
                    body:
                        'This budget will be removed from your budget list. Previous transactions will remain in your history.',
                    confirmLabel: 'Remove budget',
                    danger: true,
                  );
                  if (!sheetContext.mounted) return;
                  if (ok && state.archiveEnvelope(envelope)) {
                    Navigator.pop(sheetContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${envelope.name} budget removed'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            ],
          ],
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
