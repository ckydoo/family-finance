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
    expect(find.text('Primary currency'), findsOneWidget);
    expect(find.textContaining('Create family'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('I have an invite code'));
    await tester.pumpAndSettle();
    expect(find.text('Join your family'), findsOneWidget);
    expect(find.text('Invite code'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
