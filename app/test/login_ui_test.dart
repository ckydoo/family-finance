import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/auth/auth_controller.dart';
import 'package:mhuri_money/core/l10n/localization_delegates.dart';
import 'package:mhuri_money/features/auth/login_screen.dart';
import 'package:mhuri_money/l10n/generated/app_localizations.dart';

import 'fake_auth.dart';

void main() {
  testWidgets('login is focused, switchable, and fits a 390px viewport',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: mhuriLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LoginScreen(
          auth: AuthController(env: testEnv(), service: FakeAuthService()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('New to Mhuri Hub?'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Already have an account?'), findsOneWidget);
    expect(find.text('Forgot password?'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
