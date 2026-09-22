import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/features/activity/activity_screen.dart';
import 'package:mhuri_money/features/budgets/budgets_screen.dart';
import 'package:mhuri_money/features/home/home_screen.dart';
import 'package:mhuri_money/features/lists/lists_screen.dart';
import 'package:mhuri_money/features/onboarding/family_setup_screen.dart';
import 'package:mhuri_money/features/reports/reports_screen.dart';
import 'package:mhuri_money/features/savings/savings_screen.dart';
import 'package:mhuri_money/features/settings/settings_screen.dart';

/// M7 — every main screen pumps against REAL app-created data (no fixtures:
/// the app ships with an empty database) without throwing, and the key
/// content is actually on screen.
void main() {
  Future<AppState> seeded() async {
    final s = AppState(); // no db → in-memory, ready immediately
    s.addEnvelope(name: 'Groceries', limit: Money.fromMajor(150, Currency.usd));
    s.addTx(
      type: TxType.expense,
      amount: Money.fromMajor(12.50, Currency.usd),
      memberId: s.user.id,
      method: Method.cash,
      note: 'FreshMart groceries',
      envelopeId: s.envelopes.first.id,
    );
    s.goals.insert(
      0,
      const Goal(
        id: 'g-school',
        name: 'School Fees',
        emoji: 'school',
        target: Money(30000, Currency.usd),
      ),
    );
    s.addItem('Rice 2kg', 1, Money.fromMajor(10, Currency.usd));
    return s;
  }

  Widget harness(AppState s, Widget child) => AppScope(
        notifier: s,
        child: MaterialApp(home: Scaffold(body: child)),
      );

  void sizeWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('Home renders the pool card and the bell opens reminders',
      (tester) async {
    sizeWindow(tester);
    final s = await seeded();
    tester.pumpWidget(harness(s, HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Family Pool'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.notifications_none));
    await tester.pumpAndSettle();
    expect(find.text('Reminders'), findsOneWidget);
    expect(find.textContaining('Scheduled on this device'), findsOneWidget);
  });

  testWidgets('Budgets renders envelopes and the recurring section',
      (tester) async {
    sizeWindow(tester);
    final s = await seeded();
    tester.pumpWidget(harness(s, BudgetsScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Groceries'), findsAtLeastNWidgets(1));
    expect(find.text('Recurring expenses'), findsOneWidget);
  });

  testWidgets('Activity renders the seeded transactions', (tester) async {
    sizeWindow(tester);
    final s = await seeded();
    tester.pumpWidget(harness(s, ActivityScreen()));
    await tester.pumpAndSettle();

    expect(find.text('No activity yet'), findsNothing);
    expect(find.textContaining('FreshMart'), findsAtLeastNWidgets(1));
  });

  testWidgets('Savings renders the family goals', (tester) async {
    sizeWindow(tester);
    final s = await seeded();
    tester.pumpWidget(harness(s, SavingsScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('School Fees'), findsAtLeastNWidgets(1));
  });

  testWidgets('Reports offers the family meeting and CSV export',
      (tester) async {
    sizeWindow(tester);
    final s = await seeded();
    tester.pumpWidget(harness(s, ReportsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Start the family meeting'), findsOneWidget);
    expect(find.text('Export transactions (CSV)'), findsOneWidget);
  });

  testWidgets('Settings renders notifications, quiet hours and month start',
      (tester) async {
    sizeWindow(tester);
    final s = await seeded();
    tester.pumpWidget(harness(s, SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Reminders on this device'), findsOneWidget);
    expect(find.text('Month starts on'), findsOneWidget);
    expect(find.textContaining('Quiet hours'), findsOneWidget);
  });

  testWidgets('Lists renders the seeded shopping list', (tester) async {
    sizeWindow(tester);
    final s = await seeded();
    tester.pumpWidget(harness(s, ListsScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Rice'), findsAtLeastNWidgets(1));
  });

  testWidgets('Onboarding shows the first slide with the brand mark',
      (tester) async {
    sizeWindow(tester);
    final s = await seeded();
    tester.pumpWidget(harness(s, FamilySetupScreen(state: s)));
    await tester.pumpAndSettle();

    expect(find.text('Money, managed together'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
