import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/core/theme/app_theme.dart';
import 'package:mhuri_money/features/planner/payday_planner_screen.dart';

void main() {
  testWidgets('planner requires confirmation and renders a scenario outlook',
      (tester) async {
    final state = AppState(clock: () => DateTime(2026, 10, 22));
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: AppScope(notifier: state, child: const PaydayPlannerScreen()),
    ));

    final opening = find.widgetWithText(TextField, 'Money available now');
    await tester.enterText(opening, '500');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -450));
    await tester.pumpAndSettle();
    final income =
        find.widgetWithText(TextField, 'Income expected in this period');
    await tester.ensureVisible(income);
    await tester.enterText(income, '200');
    await tester.ensureVisible(find.text('Optional what-if scenarios'));
    await tester.tap(find.text('Optional what-if scenarios'));
    await tester.pumpAndSettle();
    final purchase =
        find.widgetWithText(TextField, 'What if I make this purchase?');
    await tester.ensureVisible(purchase);
    await tester.enterText(purchase, '150');
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();

    expect(find.text('Projected closing balance'), findsOneWidget);
    expect(find.text('US\$ 550.00'), findsOneWidget);
    expect(find.text('No shortfall found in this scenario.'), findsOneWidget);
  });
}
