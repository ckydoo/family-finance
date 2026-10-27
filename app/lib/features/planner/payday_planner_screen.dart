import 'package:flutter/material.dart';

import '../../core/money/money.dart';
import '../../core/planning/commitments.dart';
import '../../core/planning/financial_planner.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/plus_ui.dart';
import '../commitments/commitments_screen.dart';

class PaydayPlannerScreen extends StatefulWidget {
  const PaydayPlannerScreen({super.key});

  @override
  State<PaydayPlannerScreen> createState() => _PaydayPlannerScreenState();
}

class _PaydayPlannerScreenState extends State<PaydayPlannerScreen> {
  final _opening = TextEditingController();
  final _income = TextEditingController();
  final _essential = TextEditingController();
  final _savings = TextEditingController();
  final _purchase = TextEditingController();
  final _essentialDelta = TextEditingController();
  final _extraSavings = TextEditingController();
  final List<({String id, String label, int minor, int dayOffset})>
      _irregularIncomes = [];
  Currency? _currency;
  var _days = 30;
  var _incomeShiftDays = 0;
  var _confirmed = false;
  var _showOptions = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _opening,
      _income,
      _essential,
      _savings,
      _purchase,
      _essentialDelta,
      _extraSavings,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  int? _minor(TextEditingController controller) {
    final value = double.tryParse(controller.text.trim());
    return value == null || value < 0 ? null : (value * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final currency = _currency ?? state.primaryCurrency;
    final start = DateTime.now();
    final end = start.add(Duration(days: _days));
    FinancialForecast? forecast;
    final entries = <PlanningEntry>[
      ...const CommitmentSchedule()
          .toPlanningEntries(
            commitments: state.financialCommitments,
            occurrences: state.commitmentOccurrences,
            payments: state.commitmentPayments,
            periodStart: start,
            periodEnd: end,
          )
          .where((entry) => entry.amount.currency == currency),
    ];
    void addInput(TextEditingController input, String id, String label,
        PlanningValueKind kind, PlanningDirection direction) {
      final minor = _minor(input);
      if (minor == null || minor == 0) return;
      entries.add(PlanningEntry(
        id: id,
        date: start,
        amount: Money(minor, currency),
        kind: kind,
        direction: direction,
        evidence: PlanningEvidence(
          sourceType: 'planner_input',
          sourceId: id,
          label: label,
          isEstimate: true,
        ),
      ));
    }

    addInput(_income, 'expected-income', 'Expected income',
        PlanningValueKind.expectedIncome, PlanningDirection.inflow);
    addInput(_essential, 'planned-essential', 'Essential spending',
        PlanningValueKind.plannedEssential, PlanningDirection.outflow);
    addInput(_savings, 'savings-allocation', 'Savings allocation',
        PlanningValueKind.savingsAllocation, PlanningDirection.outflow);
    for (final item in _irregularIncomes) {
      entries.add(PlanningEntry(
        id: item.id,
        date: start.add(Duration(days: item.dayOffset)),
        amount: Money(item.minor, currency),
        kind: PlanningValueKind.expectedIncome,
        direction: PlanningDirection.inflow,
        evidence: PlanningEvidence(
          sourceType: 'irregular_income',
          sourceId: item.id,
          label: item.label,
          isEstimate: true,
        ),
      ));
    }
    final scenario = <ScenarioChange>[];
    if (_incomeShiftDays != 0 && (_minor(_income) ?? 0) > 0) {
      scenario.add(ScenarioChange(
        id: 'late-income-scenario',
        targetEntryId: 'expected-income',
        dateShift: Duration(days: _incomeShiftDays),
      ));
    }
    final essentialDeltaMinor = _minor(_essentialDelta);
    if (essentialDeltaMinor != null && essentialDeltaMinor > 0) {
      final baseEssentialMinor = _minor(_essential) ?? 0;
      if (baseEssentialMinor > 0) {
        scenario.add(ScenarioChange(
          id: 'higher-essentials-scenario',
          targetEntryId: 'planned-essential',
          replacementAmount:
              Money(baseEssentialMinor + essentialDeltaMinor, currency),
        ));
      } else {
        scenario.add(ScenarioChange(
          id: 'higher-essentials-entry',
          additionalEntry: PlanningEntry(
            id: 'what-if-essentials',
            date: start,
            amount: Money(essentialDeltaMinor, currency),
            kind: PlanningValueKind.scenarioAdjustment,
            direction: PlanningDirection.outflow,
            evidence: const PlanningEvidence(
              sourceType: 'scenario',
              sourceId: 'what-if-essentials',
              label: 'Higher essentials scenario',
              isEstimate: true,
            ),
          ),
        ));
      }
    }
    final extraSavingsMinor = _minor(_extraSavings);
    if (extraSavingsMinor != null && extraSavingsMinor > 0) {
      scenario.add(ScenarioChange(
        id: 'extra-savings-scenario',
        additionalEntry: PlanningEntry(
          id: 'what-if-extra-savings',
          date: start,
          amount: Money(extraSavingsMinor, currency),
          kind: PlanningValueKind.scenarioAdjustment,
          direction: PlanningDirection.outflow,
          evidence: const PlanningEvidence(
            sourceType: 'scenario',
            sourceId: 'what-if-extra-savings',
            label: 'Additional savings scenario',
            isEstimate: true,
          ),
        ),
      ));
    }
    final purchaseMinor = _minor(_purchase);
    if (purchaseMinor != null && purchaseMinor > 0) {
      scenario.add(ScenarioChange(
        id: 'purchase-scenario',
        additionalEntry: PlanningEntry(
          id: 'what-if-purchase',
          date: start,
          amount: Money(purchaseMinor, currency),
          kind: PlanningValueKind.scenarioAdjustment,
          direction: PlanningDirection.outflow,
          evidence: const PlanningEvidence(
            sourceType: 'scenario',
            sourceId: 'what-if-purchase',
            label: 'What-if purchase',
            isEstimate: true,
          ),
        ),
      ));
    }
    final openingMinor = _minor(_opening);
    if (_confirmed && openingMinor != null) {
      try {
        forecast = const FinancialPlanner().forecast(
          periodStart: start,
          periodEnd: end,
          openingBalance: Money(openingMinor, currency),
          openingBalanceConfirmed: true,
          entries: entries,
          scenario: scenario,
        );
        _error = null;
      } on FinancialPlanningException catch (error) {
        _error = error.message;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payday-to-payday planner'),
        actions: [
          IconButton(
            tooltip: 'Smart Commitments',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CommitmentsScreen(),
              ),
            ),
            icon: const Icon(Icons.event_repeat_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const PlusHero(
            eyebrow: 'Payday planner',
            title: 'See the month before it happens',
            description:
                'Explore income, essentials, savings and purchases safely. Nothing here changes your ledger.',
            icon: Icons.insights_rounded,
          ),
          const SizedBox(height: 20),
          Text('Build your outlook',
              style: MhuriType.titleM.copyWith(color: context.ink)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<Currency>(
                initialValue: currency,
                decoration: const InputDecoration(labelText: 'Currency'),
                items: state.activeCurrencies
                    .map((value) => DropdownMenuItem(
                        value: value, child: Text(value.short)))
                    .toList(),
                onChanged: (value) => setState(() {
                  _currency = value;
                  _confirmed = false;
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _days,
                decoration: const InputDecoration(labelText: 'Period'),
                items: const [
                  DropdownMenuItem(value: 30, child: Text('30 days')),
                  DropdownMenuItem(value: 60, child: Text('60 days')),
                  DropdownMenuItem(value: 90, child: Text('90 days')),
                ],
                onChanged: (value) => setState(() => _days = value ?? 30),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          PlusSectionCard(
            title: '1. Start with money available now',
            subtitle: 'Use your recorded balance or enter a different amount.',
            icon: Icons.account_balance_wallet_outlined,
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: state.availableToSpend(currency).minor < 0
                        ? null
                        : () => setState(() {
                              final recorded = state.availableToSpend(currency);
                              _opening.text =
                                  (recorded.minor / 100).toStringAsFixed(2);
                              _confirmed = true;
                            }),
                    icon: const Icon(Icons.auto_fix_high_rounded),
                    label: Text(
                        'Use recorded balance (${state.availableToSpend(currency).text})'),
                  ),
                ),
                const SizedBox(height: 12),
                _amount(_opening, 'Money available now', currency),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _confirmed,
                  title: const Text('This amount is available to plan with'),
                  subtitle: const Text(
                      'Required before Mhuri calculates an outlook.'),
                  onChanged: (value) =>
                      setState(() => _confirmed = value ?? false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PlusSectionCard(
            title: '2. Add what you expect',
            subtitle: 'Rough estimates are enough. You can refine them later.',
            icon: Icons.edit_calendar_outlined,
            child: Column(
              children: [
                _amount(_income, 'Income expected in this period', currency),
                _amount(_essential, 'Essential spending', currency),
                _amount(_savings, 'Amount you want to save', currency),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ExpansionTile(
              initiallyExpanded: _showOptions,
              onExpansionChanged: (value) => _showOptions = value,
              leading: const Icon(Icons.tune_rounded),
              title: const Text('Optional what-if scenarios'),
              subtitle: const Text(
                  'Test a purchase, delayed income or unexpected costs.'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                _amount(_purchase, 'What if I make this purchase?', currency),
                _AdvancedScenarioSection(
                  currency: currency,
                  recordedAvailable: state.availableToSpend(currency),
                  incomeShiftDays: _incomeShiftDays,
                  essentialDeltaController: _essentialDelta,
                  extraSavingsController: _extraSavings,
                  irregularIncomes: _irregularIncomes,
                  onPrefillOpening: () {
                    final recorded = state.availableToSpend(currency);
                    if (recorded.minor >= 0) {
                      setState(() {
                        _opening.text =
                            (recorded.minor / 100).toStringAsFixed(2);
                        _confirmed = true;
                      });
                    }
                  },
                  onShiftChanged: (days) =>
                      setState(() => _incomeShiftDays = days),
                  onAddIrregularIncome: (label, minor, dayOffset) =>
                      setState(() {
                    _irregularIncomes.add((
                      id: 'irregular-${_irregularIncomes.length + 1}',
                      label: label,
                      minor: minor,
                      dayOffset: dayOffset,
                    ));
                  }),
                  onRemoveIrregularIncome: (id) => setState(() {
                    _irregularIncomes.removeWhere((item) => item.id == id);
                  }),
                  onChanged: () => setState(() {}),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_error != null)
            Text(_error!, style: TextStyle(color: context.danger))
          else if (!_confirmed)
            const Text('Confirm the opening amount to calculate the outlook.')
          else if (openingMinor == null)
            const Text('Enter a valid opening amount.')
          else if (forecast != null) ...[
            Text('3. Your outlook',
                style: MhuriType.titleM.copyWith(color: context.ink)),
            const SizedBox(height: 10),
            _ForecastCard(forecast: forecast),
          ],
        ],
      ),
    );
  }

  Widget _amount(
      TextEditingController controller, String label, Currency currency) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration:
            InputDecoration(labelText: label, prefixText: '${currency.short} '),
        onChanged: (_) => setState(() {}),
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.forecast});
  final FinancialForecast forecast;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Projected closing balance',
                style: TextStyle(color: context.inkSoft)),
            Text(forecast.closingBalance.text,
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 10),
            Text('Lowest balance: ${forecast.lowestBalance.text}'),
            Text(forecast.hasShortfall
                ? 'Possible shortfall on ${forecast.shortfalls.first.date.toLocal().toString().split(' ').first}: ${forecast.shortfalls.first.amountBelowZero.text}'
                : 'No shortfall found in this scenario.'),
            const Divider(height: 24),
            Text('${forecast.points.length} dated planning entries included.'),
            const SizedBox(height: 4),
            const Text(
                'Recorded balances, plans, estimates, and scenarios remain separately labelled.'),
            if (forecast.points.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final point in forecast.points)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${point.entry.date.toLocal().toString().split(' ').first} · ${point.entry.evidence.label} (${point.entry.kind.name})',
                          style:
                              TextStyle(fontSize: 12, color: context.inkSoft),
                        ),
                      ),
                      Text(
                        '${point.entry.direction == PlanningDirection.inflow ? '+' : '-'}${point.entry.amount.text} → ${point.balance.text}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ]),
        ),
      );
}

class _AdvancedScenarioSection extends StatelessWidget {
  const _AdvancedScenarioSection({
    required this.currency,
    required this.recordedAvailable,
    required this.incomeShiftDays,
    required this.essentialDeltaController,
    required this.extraSavingsController,
    required this.irregularIncomes,
    required this.onPrefillOpening,
    required this.onShiftChanged,
    required this.onAddIrregularIncome,
    required this.onRemoveIrregularIncome,
    required this.onChanged,
  });

  final Currency currency;
  final Money recordedAvailable;
  final int incomeShiftDays;
  final TextEditingController essentialDeltaController;
  final TextEditingController extraSavingsController;
  final List<({String id, String label, int minor, int dayOffset})>
      irregularIncomes;
  final VoidCallback onPrefillOpening;
  final ValueChanged<int> onShiftChanged;
  final void Function(String label, int minor, int dayOffset)
      onAddIrregularIncome;
  final ValueChanged<String> onRemoveIrregularIncome;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'What-if scenarios & irregular income',
                      style: TextStyle(
                        color: context.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onPrefillOpening,
                    icon: const Icon(Icons.account_balance_wallet_outlined,
                        size: 16),
                    label: Text('Use ledger (${recordedAvailable.text})'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: incomeShiftDays,
                decoration: const InputDecoration(
                  labelText: 'What if expected income arrives late?',
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('On time (0 days)')),
                  DropdownMenuItem(value: 3, child: Text('3 days late')),
                  DropdownMenuItem(value: 7, child: Text('7 days late')),
                  DropdownMenuItem(value: 14, child: Text('14 days late')),
                ],
                onChanged: (next) => onShiftChanged(next ?? 0),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: essentialDeltaController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'What if essentials cost more?',
                  prefixText: '${currency.short} ',
                ),
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: extraSavingsController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'What if we increase savings?',
                  prefixText: '${currency.short} ',
                ),
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Dated / irregular income (${irregularIncomes.length})',
                      style: TextStyle(
                        color: context.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showIrregularIncomeDialog(context),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add dated income'),
                  ),
                ],
              ),
              for (final item in irregularIncomes)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${item.label} · ${Money(item.minor, currency).text}',
                  ),
                  subtitle: Text('Arrives in +${item.dayOffset} days'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => onRemoveIrregularIncome(item.id),
                  ),
                ),
            ],
          ),
        ),
      );

  Future<void> _showIrregularIncomeDialog(BuildContext context) async {
    final labelCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final dayCtrl = TextEditingController(text: '10');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add dated expected income'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(
                labelText: 'Source (e.g. Freelance, Market sales)',
              ),
            ),
            TextField(
              controller: amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount (${currency.code})',
              ),
            ),
            TextField(
              controller: dayCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Days from today (e.g. 10)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(amountCtrl.text.trim());
              final days = int.tryParse(dayCtrl.text.trim()) ?? 0;
              if (labelCtrl.text.trim().isEmpty ||
                  amount == null ||
                  amount <= 0 ||
                  days < 0) {
                return;
              }
              onAddIrregularIncome(
                labelCtrl.text.trim(),
                (amount * 100).round(),
                days,
              );
              Navigator.pop(dialogContext);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
