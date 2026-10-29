import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/billing/entitlement.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/core/theme/app_theme.dart';
import 'package:mhuri_money/features/settings/plus_screen.dart';

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
    expect(find.textContaining('Purchases are not enabled'), findsNothing);
  });
}
