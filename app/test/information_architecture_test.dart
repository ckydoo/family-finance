import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/l10n/localization_delegates.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/features/budgets/budgets_screen.dart';
import 'package:mhuri_money/features/quickadd/quick_add_sheet.dart';
import 'package:mhuri_money/features/savings/savings_screen.dart';
import 'package:mhuri_money/l10n/generated/app_localizations.dart';

void main() {
  Widget harness(AppState state, Widget child) => AppScope(
        notifier: state,
        child: MaterialApp(
          localizationsDelegates: mhuriLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      );

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('global quick add exposes exactly the five product actions',
      (tester) async {
    phone(tester);
    final state = AppState()..members.add(AppState().user);
    await tester.pumpWidget(harness(
      state,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showQuickAddMenu(context),
            child: const Text('Open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    for (final label in [
      'Expense',
      'Income',
      'Shopping item',
      'Task',
      'Contribution'
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('budgets lazily handles 100 records and can search the last one',
      (tester) async {
    phone(tester);
    final state = AppState();
    for (var index = 1; index <= 100; index++) {
      state.addEnvelope(
        name: 'Budget $index',
        limit: Money(10000 + index, Currency.usd),
      );
    }
    await tester.pumpWidget(harness(state, const BudgetsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('100'), findsOneWidget);
    expect(find.text('Budget 100'), findsNothing);
    await tester.tap(find.byTooltip('Search budgets'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'Budget 100');
    await tester.pump();
    expect(find.text('Budget 100'), findsNWidgets(2));
  });

  testWidgets('savings separates goals contributions and debts',
      (tester) async {
    phone(tester);
    final state = AppState();
    state.goals.add(const Goal(
      id: 'goal',
      name: 'Emergency fund',
      emoji: 'savings',
      target: Money(10000, Currency.usd),
    ));
    state.contributionCampaigns.add(ContributionCampaign(
      id: 'campaign',
      name: 'Christmas',
      target: const Money(60000, Currency.usd),
      deadline: DateTime(2030),
      createdById: state.user.id,
    ));
    state.familyDebts.add(FamilyDebt(
      id: 'debt',
      name: 'School loan',
      direction: DebtDirection.iOwe,
      principal: const Money(20000, Currency.usd),
      createdById: state.user.id,
    ));
    await tester.pumpWidget(harness(state, const SavingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Emergency fund'), findsOneWidget);
    expect(find.text('Christmas'), findsNothing);
    await tester.tap(find.text('Contributions'));
    await tester.pumpAndSettle();
    expect(find.text('Christmas'), findsOneWidget);
    expect(find.text('Emergency fund'), findsNothing);
    await tester.tap(find.text('Debts'));
    await tester.pumpAndSettle();
    expect(find.text('School loan'), findsOneWidget);
    expect(find.text('Christmas'), findsNothing);
  });
}
