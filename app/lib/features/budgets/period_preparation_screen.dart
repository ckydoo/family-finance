import 'package:flutter/material.dart';

import '../../core/money/money.dart';
import '../../core/planning/period_preparation.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ids.dart';
import '../../core/widgets/plus_ui.dart';

class PeriodPreparationScreen extends StatefulWidget {
  const PeriodPreparationScreen({super.key});

  @override
  State<PeriodPreparationScreen> createState() =>
      _PeriodPreparationScreenState();
}

class _PeriodPreparationScreenState extends State<PeriodPreparationScreen> {
  PeriodPreparation? _proposal;
  final _allocationControllers = <String, TextEditingController>{};
  final _incomeController = TextEditingController();
  late Set<String> _commitments;
  late Set<String> _shopping;
  late Set<String> _savings;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final state = AppScope.of(context);
    final operationId = uuidFromSeed(
        'prepare:${state.spaceName ?? state.space.name}:${state.cycleStart.toIso8601String()}');
    _proposal =
        state.previewAdvancedPeriodPreparation(operationId: operationId);
    final proposal = _proposal;
    if (proposal == null) return;
    for (final entry in proposal.allocations.entries) {
      _allocationControllers[entry.key] = TextEditingController(
          text: (entry.value.minor / 100).toStringAsFixed(2));
    }
    _incomeController.text = proposal.expectedIncome == null
        ? ''
        : (proposal.expectedIncome!.minor / 100).toStringAsFixed(2);
    _commitments = proposal.commitmentIds.toSet();
    _shopping = proposal.shoppingItems.map((value) => value.name).toSet();
    _savings = proposal.savings.map((value) => value.goalId).toSet();
  }

  @override
  void dispose() {
    for (final controller in _allocationControllers.values) {
      controller.dispose();
    }
    _incomeController.dispose();
    super.dispose();
  }

  int? _minor(String value) {
    final parsed = double.tryParse(value.trim());
    return parsed == null || parsed < 0 ? null : (parsed * 100).round();
  }

  void _apply(AppState state) {
    final proposal = _proposal!;
    final allocations = <String, Money>{};
    for (final entry in proposal.allocations.entries) {
      final minor = _minor(_allocationControllers[entry.key]!.text);
      if (minor == null) {
        _message('Enter valid non-negative allocation amounts.');
        return;
      }
      allocations[entry.key] = Money(minor, entry.value.currency);
    }
    final incomeMinor = _incomeController.text.trim().isEmpty
        ? null
        : _minor(_incomeController.text);
    if (_incomeController.text.trim().isNotEmpty && incomeMinor == null) {
      _message('Enter a valid expected income.');
      return;
    }
    final updated = proposal.copyWith(
      allocations: allocations,
      expectedIncome: incomeMinor == null
          ? null
          : Money(incomeMinor,
              proposal.expectedIncome?.currency ?? state.primaryCurrency),
      clearExpectedIncome: incomeMinor == null,
      commitmentIds: proposal.commitmentIds
          .where(_commitments.contains)
          .toList(growable: false),
      savings: proposal.savings
          .where((value) => _savings.contains(value.goalId))
          .toList(growable: false),
      shoppingItems: proposal.shoppingItems
          .where((value) => _shopping.contains(value.name))
          .toList(growable: false),
    );
    if (!state.updatePeriodPreparation(updated) ||
        !state.applyAdvancedPeriodPreparation(updated.operationId)) {
      _message('The target period changed. Review it again before applying.');
      return;
    }
    setState(() => _proposal = state.periodPreparations
        .firstWhere((value) => value.operationId == updated.operationId));
    _message('The new period is ready. No transactions were created.');
  }

  void _message(String value) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final proposal = _proposal;
    return Scaffold(
      appBar: AppBar(title: const Text('Prepare next period')),
      body: proposal == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Close or save a previous period first. Nothing has been changed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.inkSoft),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const PlusHero(
                  eyebrow: 'Next period',
                  title: 'Carry forward what still matters',
                  description:
                      'Review the plan below, remove anything you do not need, then prepare the new period. Completed financial history stays untouched.',
                  icon: Icons.next_plan_outlined,
                ),
                const SizedBox(height: 16),
                PlusSectionCard(
                  title: 'Your preparation summary',
                  subtitle:
                      'Everything is selected by default. Uncheck anything you do not want to carry forward.',
                  icon: Icons.checklist_rounded,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                          label:
                              Text('${proposal.allocations.length} budgets')),
                      Chip(
                          label:
                              Text('${proposal.commitmentIds.length} bills')),
                      Chip(
                          label:
                              Text('${proposal.savings.length} savings plans')),
                      Chip(
                          label: Text(
                              '${proposal.shoppingItems.length} shopping items')),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text('1. Check budget amounts',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final entry in proposal.allocations.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: _allocationControllers[entry.key],
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: state.envelope(entry.key)?.name ?? entry.key,
                        prefixText: '${entry.value.currency.short} ',
                      ),
                    ),
                  ),
                TextField(
                  controller: _incomeController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Expected income (optional)'),
                ),
                const SizedBox(height: 18),
                _sectionTitle(context, '2. Choose bills to carry forward'),
                if (proposal.commitmentIds.isEmpty)
                  const Text('No active commitments to prepare.'),
                for (final id in proposal.commitmentIds)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _commitments.contains(id),
                    title: Text(state.financialCommitments
                            .where((value) => value.id == id)
                            .map((value) => value.name)
                            .firstOrNull ??
                        id),
                    onChanged: (selected) => setState(() => selected == true
                        ? _commitments.add(id)
                        : _commitments.remove(id)),
                  ),
                _sectionTitle(context, '3. Choose savings plans'),
                if (proposal.savings.isEmpty)
                  const Text('No prior-period contributions to suggest.'),
                for (final value in proposal.savings)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _savings.contains(value.goalId),
                    title: Text(state.goals
                            .where((goal) => goal.id == value.goalId)
                            .map((goal) => goal.name)
                            .firstOrNull ??
                        value.goalId),
                    subtitle: Text(value.amount.text),
                    onChanged: (selected) => setState(() => selected == true
                        ? _savings.add(value.goalId)
                        : _savings.remove(value.goalId)),
                  ),
                _sectionTitle(context, '4. Choose reusable shopping items'),
                if (proposal.shoppingItems.isEmpty)
                  const Text('No completed items to suggest.'),
                for (final value in proposal.shoppingItems)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _shopping.contains(value.name),
                    title: Text(value.name),
                    subtitle:
                        Text('${value.quantity} × ${value.estimate.text}'),
                    onChanged: (selected) => setState(() => selected == true
                        ? _shopping.add(value.name)
                        : _shopping.remove(value.name)),
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: proposal.status == PreparationStatus.applied
                      ? null
                      : () => _apply(state),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(proposal.status == PreparationStatus.applied
                      ? 'Period prepared'
                      : 'Prepare next period'),
                ),
              ],
            ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 4),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}
