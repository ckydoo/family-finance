import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/l10n/localization_delegates.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/features/onboarding/family_setup_screen.dart';
import 'package:mhuri_money/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('onboarding starts with identity and family fields at 390px',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState();

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          localizationsDelegates: mhuriLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FamilySetupScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.text('Preferred name'), findsOneWidget);
    expect(find.textContaining('Family name'), findsOneWidget);
    expect(find.text('Continue  →'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('I have an invite code'));
    await tester.pumpAndSettle();
    expect(find.text('Join your family'), findsOneWidget);
    expect(find.text('Invite code'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'progresses through wizard: create -> currencies -> spending -> ready',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState();

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          localizationsDelegates: mhuriLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FamilySetupScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Step 1: fill names
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'Simba');
    await tester.enterText(textFields.at(1), 'Moyo Family');
    await tester.tap(find.text('Continue  →'));
    await tester.pumpAndSettle();

    // Step 2: Currencies
    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(find.text('Which currencies do you use?'), findsOneWidget);
    await tester.tap(find.text('Continue  →'));
    await tester.pumpAndSettle();

    // Step 3: Spending areas
    expect(find.text('Step 3 of 3'), findsOneWidget);
    expect(find.text('What do you normally spend money on?'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Rent'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(find.text('+ Add my own'), findsOneWidget);
  });
}
