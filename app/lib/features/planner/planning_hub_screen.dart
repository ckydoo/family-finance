import 'package:flutter/material.dart';

import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../budgets/period_preparation_screen.dart';
import '../commitments/commitments_screen.dart';
import '../reports/financial_health_screen.dart';
import '../savings/advanced_planning_screen.dart';
import '../settings/plus_screen.dart';
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
    final visibleTools = available.isNotEmpty ? available : tools;
    final lockedPreview = available.isEmpty;

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
            Material(
              color: context.card,
              shape: RoundedRectangleBorder(
                borderRadius: kBRadiusL,
                side: BorderSide(color: context.hairline),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var index = 0; index < visibleTools.length; index++) ...[
                    _PlanningToolTile(
                      tool: visibleTools[index],
                      locked: lockedPreview &&
                          !visibleTools[index].alwaysOpenScreen,
                    ),
                    if (index < visibleTools.length - 1)
                      Divider(height: 1, indent: 68, color: context.hairline),
                  ],
                ],
              ),
            ),
            if (lockedPreview) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('planning_hub_explore_plus'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PlusScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                  label: const Text('Explore Mhuri Plus'),
                ),
              ),
            ],
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
    this.alwaysOpenScreen = false,
  });

  final String feature;
  final String? alternateFeature;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget screen;
  final bool alwaysOpenScreen;

  bool isAvailable(AppState state) =>
      alwaysOpenScreen ||
      state.hasPlusFeature(feature) ||
      (alternateFeature != null && state.hasPlusFeature(alternateFeature!));
}

class _PlanningToolTile extends StatelessWidget {
  const _PlanningToolTile({required this.tool, this.locked = false});

  final _PlanningTool tool;
  final bool locked;

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
        title: Row(
          children: [
            Expanded(
              child: Text(
                tool.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (locked)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: context.accentSoft,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'PLUS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: context.ink,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(tool.subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => locked ? const PlusScreen() : tool.screen,
          ),
        ),
      );
}
