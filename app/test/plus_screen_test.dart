import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/billing/entitlement.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/core/theme/app_theme.dart';
import 'package:mhuri_money/features/settings/plus_screen.dart';
import 'package:mhuri_money/features/planner/planning_hub_screen.dart';

void main() {
  testWidgets('active Plus does not show the disabled-purchases warning',
      (tester) async {
    final state = AppState();
    state.members.add(state.user);
    state.familyEntitlement = const FamilyEntitlement(
      familyId: 'active-family',
      status: EntitlementStatus.active,
      features: kPlusV2Features,
    );

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const PlusScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Your whole family has Plus'), findsOneWidget);
    expect(find.text('Plan Ahead'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Smart Insights'), 300);
    expect(find.text('Smart Insights'), findsOneWidget);
    expect(find.text('More Family Capacity'), findsOneWidget);
    expect(find.textContaining('Purchases are not enabled'), findsNothing);
  });

  testWidgets('active Plus opens one planning hub with all implemented tools',
      (tester) async {
    final state = AppState();
    state.members.add(state.user);
    state.familyEntitlement = const FamilyEntitlement(
      familyId: 'active-family',
      status: EntitlementStatus.active,
      features: kPlusV2Features,
    );

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const PlusScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Plan Ahead').first);
    await tester.pumpAndSettle();

    expect(find.byType(PlanningHubScreen), findsOneWidget);
    for (final label in [
      'Cash outlook',
      'Bills and commitments',
      'Savings and debt plan',
      'Financial health',
      'Prepare the next period',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('Cash outlook'));
    await tester.pumpAndSettle();
    expect(find.text('Payday-to-payday planner'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(PlanningHubScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(PlusScreen), findsOneWidget);
  });
}
