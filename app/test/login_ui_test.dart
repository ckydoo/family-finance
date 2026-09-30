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
    expect(find.text('New to Mhuri?'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsNothing);
    expect(find.text('Continue with Facebook'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Already have an account?'), findsOneWidget);
    expect(find.text('Forgot password?'), findsNothing);
    expect(find.text('Sign up with Google'), findsOneWidget);
    expect(find.text('Sign up with Apple'), findsNothing);
    expect(find.text('Sign up with Facebook'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login remains scrollable on a small phone with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

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

    await tester.ensureVisible(find.text('Continue with Facebook'));
    await tester.ensureVisible(find.text('Privacy Policy'));
    expect(find.text('Sign in'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unconfigured social providers never fake authentication',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final auth = AuthController(env: testEnv(), service: FakeAuthService());
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: mhuriLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LoginScreen(auth: auth),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Continue with Facebook'));
    await tester.tap(find.text('Continue with Facebook'));
    await tester.pump();

    expect(find.textContaining('Facebook sign-in is not configured'),
        findsOneWidget);
    expect(auth.isLoggedIn, isFalse);
  });
}
