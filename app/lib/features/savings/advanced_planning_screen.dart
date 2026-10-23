import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/models.dart';
import '../../core/money/money.dart';
import '../../core/planning/savings_debt_planner.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';

class AdvancedPlanningScreen extends StatefulWidget {
  const AdvancedPlanningScreen({super.key});

  @override
  State<AdvancedPlanningScreen> createState() => _AdvancedPlanningScreenState();
}

class _AdvancedPlanningScreenState extends State<AdvancedPlanningScreen> {
  final _amount = TextEditingController(text: '50');
  final _compareAmount = TextEditingController();
  final _whatIfTarget = TextEditingController();
  ContributionFrequency _frequency = ContributionFrequency.monthly;
  Goal? _goal;
  FamilyDebt? _debt;
  DateTime? _whatIfTargetDate;

  @override
  void dispose() {
    _amount.dispose();
    _compareAmount.dispose();
    _whatIfTarget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    _goal ??= state.goals.where((value) => value.status == 'active').firstOrNull;
    _debt ??=
        state.familyDebts.where((value) => value.status != 'archived').firstOrNull;
    final amountMajor = double.tryParse(_amount.text.trim());
    final compareMajor = double.tryParse(_compareAmount.text.trim());
    final targetOverrideMajor = double.tryParse(_whatIfTarget.text.trim());
    PlanProjection? savingsProjection;
    PlanProjection? savingsCompare;
    PlanProjection? debtProjection;
    PlanProjection? debtCompare;
    String? error;
    try {
      if (amountMajor != null && amountMajor > 0 && _goal != null) {
        final effectiveTarget =
            targetOverrideMajor != null && targetOverrideMajor > 0
                ? Money(
                    (targetOverrideMajor * 100).round(),
                    _goal!.target.currency,
                  )
                : _goal!.target;
        final effectiveDeadline = _whatIfTargetDate ?? _goal!.deadline;
        savingsProjection = const SavingsDebtPlanner().projectSavings(
          SavingsPlanInput(
            currentAmount: state.savedOn(_goal!),
            targetAmount: effectiveTarget,
            contributionAmount:
                Money((amountMajor * 100).round(), _goal!.target.currency),
            frequency: _frequency,
            startDate: state.now,
            targetDate: effectiveDeadline,
          ),
        );
        if (compareMajor != null && compareMajor > 0) {
          savingsCompare = const SavingsDebtPlanner().projectSavings(
            SavingsPlanInput(
              currentAmount: state.savedOn(_goal!),
              targetAmount: effectiveTarget,
              contributionAmount:
                  Money((compareMajor * 100).round(), _goal!.target.currency),
              frequency: _frequency,
              startDate: state.now,
              targetDate: effectiveDeadline,
            ),
          );
        }
      }
      if (amountMajor != null && amountMajor > 0 && _debt != null) {
        final paid = state.debtRepayments
            .where((value) =>
                value.debtId == _debt!.id &&
                value.amount.currency == _debt!.principal.currency)
            .fold<int>(0, (sum, value) => sum + value.amount.minor);
        final recordedBalance = Money(
          (_debt!.principal.minor - paid).clamp(0, _debt!.principal.minor),
          _debt!.principal.currency,
        );
        debtProjection = const SavingsDebtPlanner().projectDebt(DebtPlanInput(
          recordedBalance: recordedBalance,
          paymentAmount:
              Money((amountMajor * 100).round(), _debt!.principal.currency),
          frequency: _frequency,
          startDate: state.now,
        ));
        if (compareMajor != null && compareMajor > 0) {
          debtCompare = const SavingsDebtPlanner().projectDebt(DebtPlanInput(
            recordedBalance: recordedBalance,
            paymentAmount:
                Money((compareMajor * 100).round(), _debt!.principal.currency),
            frequency: _frequency,
            startDate: state.now,
          ));
        }
      }
    } on ArgumentError catch (value) {
      error = value.message?.toString() ?? value.toString();
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Savings & debt scenarios')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Explore without posting payments',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Changing these values never changes balances or creates transactions.',
            style: TextStyle(color: context.inkSoft),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration:
                const InputDecoration(labelText: 'Recurring amount per payment'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _compareAmount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Compare alternative payment (optional what-if)',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ContributionFrequency>(
            initialValue: _frequency,
            decoration: const InputDecoration(labelText: 'Frequency'),
            items: ContributionFrequency.values
                .map((value) => DropdownMenuItem(
                    value: value, child: Text(value.name)))
                .toList(),
            onChanged: (value) =>
                setState(() => _frequency = value ?? _frequency),
          ),
          const SizedBox(height: 22),
          _heading(context, 'Savings goal'),
          if (state.goals.isEmpty)
            const Text('Create a savings goal to model contributions.')
          else ...[
            DropdownButtonFormField<Goal>(
              initialValue: _goal,
              items: state.goals
                  .map((value) => DropdownMenuItem(
                      value: value, child: Text(value.name)))
                  .toList(),
              onChanged: (value) => setState(() => _goal = value),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _whatIfTarget,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'What-if target amount (optional)',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _whatIfTargetDate ??
                          _goal?.deadline ??
                          state.now.add(const Duration(days: 180)),
                      firstDate: state.now,
                      lastDate: DateTime(state.now.year + 15),
                    );
                    if (picked != null) {
                      setState(() => _whatIfTargetDate = picked);
                    }
                  },
                  icon: const Icon(Icons.event, size: 16),
                  label: Text(
                    _whatIfTargetDate == null
                        ? 'Target date'
                        : DateFormat.yMMMd().format(_whatIfTargetDate!),
                  ),
                ),
              ],
            ),
            if (savingsProjection != null)
              _result(
                context,
                savingsProjection,
                'Estimated goal completion',
                comparison: savingsCompare,
              ),
          ],
          const SizedBox(height: 22),
          _heading(context, 'Debt repayment'),
          if (state.familyDebts.isEmpty)
            const Text('Add a recorded debt to model repayments.')
          else ...[
            DropdownButtonFormField<FamilyDebt>(
              initialValue: _debt,
              items: state.familyDebts
                  .map((value) => DropdownMenuItem(
                      value: value, child: Text(value.name)))
                  .toList(),
              onChanged: (value) => setState(() => _debt = value),
            ),
            if (debtProjection != null)
              _result(
                context,
                debtProjection,
                'Projected payoff',
                comparison: debtCompare,
              ),
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(error, style: TextStyle(color: context.danger)),
            ),
        ],
      ),
    );
  }

  Widget _heading(BuildContext context, String value) => Text(value,
      style: Theme.of(context).textTheme.titleLarge);

  Widget _result(
    BuildContext context,
    PlanProjection value,
    String heading, {
    PlanProjection? comparison,
  }) =>
      Card(
        margin: const EdgeInsets.only(top: 10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(heading, style: Theme.of(context).textTheme.labelLarge),
            Text(DateFormat.yMMMd().format(value.completionDate),
                style: Theme.of(context).textTheme.headlineSmall),
            Text('${value.paymentCount} payments · final ${value.finalPayment.text}'),
            if (value.meetsTargetDate != null)
              Text(value.meetsTargetDate!
                  ? 'Meets the recorded target date.'
                  : 'Does not meet the recorded target date.'),
            if (comparison != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Alternative comparison: completes ${DateFormat.yMMMd().format(comparison.completionDate)} '
                  '(${comparison.paymentCount} payments, final ${comparison.finalPayment.text}).',
                  style: TextStyle(
                    color: context.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            for (final assumption in value.assumptions)
              Text('• $assumption', style: TextStyle(color: context.inkSoft)),
          ]),
        ),
      );
}
