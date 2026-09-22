import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/l10n/localization_delegates.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/core/theme/app_theme.dart';
import 'package:mhuri_money/features/savings/savings_screen.dart';
import 'package:mhuri_money/l10n/generated/app_localizations.dart';

void main() {
  test('a family can create a savings goal', () {
    final state = AppState();
    state.members.add(state.user);
    final before = state.goals.length;

    state.addGoal(
      name: 'Emergency fund',
      target: Money.fromMajor(500, Currency.usd),
    );

    expect(state.goals, hasLength(before + 1));
    expect(state.goals.first.name, 'Emergency fund');
    expect(state.goals.first.target.minor, 50000);
    expect(state.savedOn(state.goals.first).isZero, isTrue);
  });

  testWidgets('goal sheet creates a goal and closes without controller errors',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = AppState();
    state.members.add(state.user);
    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          theme: buildAppTheme(),
          localizationsDelegates: mhuriLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SavingsScreen()),
        ),
      ),
    );

    await tester.tap(find.text('Create savings goal'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Goal name'),
      'Emergency fund',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Target amount'),
      '500',
    );
    await tester.tap(find.text('Create goal'));
    await tester.pumpAndSettle();

    expect(state.goals.single.name, 'Emergency fund');
    expect(find.text('Emergency fund'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
