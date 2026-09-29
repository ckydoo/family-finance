import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/l10n/localization_delegates.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/features/home/home_screen.dart';
import 'package:mhuri_money/l10n/generated/app_localizations.dart';

void main() {
  testWidgets(
      'guided home shows 3 steps and starter envelopes with No limit set',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = AppState();
    // Add starter envelope with 0 limit
    state.addEnvelope(
      name: 'Groceries',
      limit: const Money(0, Currency.usd),
      emoji: 'groceries',
    );

    expect(state.isGuidedHomeActive, isTrue);

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: const MaterialApp(
          localizationsDelegates: mhuriLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: HomeScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Guided card content
    expect(find.text('Welcome to Mhuri'), findsOneWidget);
    expect(find.text('Your family workspace is ready'), findsOneWidget);
    expect(find.text('Add money coming in'), findsOneWidget);
    expect(find.text('Set your budgets'), findsOneWidget);
    expect(find.text('Record what you spend'), findsOneWidget);
    expect(find.text('YOUR BUDGETS'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('No limit set'), findsOneWidget);
    expect(find.text('Set amount'), findsOneWidget);
    expect(find.text('Hide getting started'), findsOneWidget);

    // Tap hide getting started
    await tester.scrollUntilVisible(
      find.text('Hide getting started'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide getting started'));
    await tester.pumpAndSettle();

    expect(state.isGuidedHomeActive, isFalse);
    expect(find.text('Welcome to Mhuri'), findsNothing);
  });
}
