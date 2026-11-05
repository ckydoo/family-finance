import 'package:flutter/material.dart';

import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/empty_state.dart';
import '../budgets/period_preparation_screen.dart';
import '../commitments/commitments_screen.dart';
import '../reports/financial_health_screen.dart';
import '../savings/advanced_planning_screen.dart';
import 'payday_planner_screen.dart';

/// A single, calm entry point for the planning tools that previously appeared
/// as unrelated destinations. The underlying screens and routes remain intact.
class PlanningHubScreen extends StatelessWidget {
  const PlanningHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final tools = <_PlanningTool>[
      const _PlanningTool(
        feature: 'cash_flow_forecast',
        icon: Icons.timeline_rounded,
        title: 'Cash outlook',
        subtitle: 'See whether your money can cover the days until payday.',
        screen: PaydayPlannerScreen(),
      ),
      const _PlanningTool(
        feature: 'smart_commitments',
        icon: Icons.event_repeat_rounded,
        title: 'Bills and commitments',
        subtitle: 'Track due dates, reminders and partial payments.',
        screen: CommitmentsScreen(),
      ),
      const _PlanningTool(
        feature: 'savings_projections',
        alternateFeature: 'debt_planning',
        icon: Icons.savings_outlined,
        title: 'Savings and debt plan',
        subtitle: 'Compare contribution and payoff timelines.',
        screen: AdvancedPlanningScreen(),
      ),
      const _PlanningTool(
        feature: 'financial_health',
        icon: Icons.health_and_safety_outlined,
        title: 'Financial health',
        subtitle: 'Review practical signals from the current period.',
        screen: FinancialHealthScreen(),
      ),
      const _PlanningTool(
        feature: 'period_preparation',
        icon: Icons.next_plan_outlined,
        title: 'Prepare the next period',
        subtitle: 'Review a suggested plan before applying any changes.',
        screen: PeriodPreparationScreen(),
      ),
    ];
    final available = tools.where((tool) => tool.isAvailable(state)).toList();

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(title: const Text('Plan Ahead')),
      body: SafeArea(
        child: ListView(
          padding: kPageInsets,
          children: [
            Text('Make the next few weeks easier',
                style: MhuriType.titleL.copyWith(color: context.ink)),
            const SizedBox(height: 6),
            Text(
              'Choose the question you want to answer. Nothing changes until you review and confirm it.',
              style: MhuriType.body.copyWith(color: context.inkSoft),
            ),
            const SizedBox(height: 20),
            if (available.isEmpty)
              const EmptyState(
                icon: Icons.event_note_outlined,
                title: 'Planning tools are not available',
                subtitle: 'Check this family’s Plus status and try again.',
              )
            else
              Material(
                color: context.card,
                shape: RoundedRectangleBorder(
                  borderRadius: kBRadiusL,
                  side: BorderSide(color: context.hairline),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var index = 0; index < available.length; index++) ...[
                      _PlanningToolTile(tool: available[index]),
                      if (index < available.length - 1)
                        Divider(height: 1, indent: 68, color: context.hairline),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlanningTool {
  const _PlanningTool({
    required this.feature,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.screen,
    this.alternateFeature,
  });

  final String feature;
  final String? alternateFeature;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget screen;

  bool isAvailable(AppState state) =>
      state.hasPlusFeature(feature) ||
      (alternateFeature != null && state.hasPlusFeature(alternateFeature!));
}

class _PlanningToolTile extends StatelessWidget {
  const _PlanningToolTile({required this.tool});

  final _PlanningTool tool;

  @override
  Widget build(BuildContext context) => ListTile(
        minVerticalPadding: 14,
        leading: SizedBox(
          width: 40,
          height: 40,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.primarySoft,
              borderRadius: kBRadiusM,
            ),
            child: Icon(tool.icon, color: context.primary, size: 21),
          ),
        ),
        title: Text(tool.title,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(tool.subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => tool.screen),
        ),
      );
}
