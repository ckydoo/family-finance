import 'package:flutter_test/flutter_test.dart';

import 'package:mhuri_money/app.dart';
import 'package:mhuri_money/core/auth/auth_controller.dart';
import 'package:mhuri_money/core/auth/auth_service.dart';
import 'package:mhuri_money/core/config/app_env.dart';

import 'fake_auth.dart';

void main() {
  testWidgets('a bare build boots to the adult Home screen (empty state)', (tester) async {
    await tester.pumpWidget(const MhuriMoneyApp());
    await tester.pumpAndSettle();

    // Family Pool card renders on Home.
    expect(find.text('Family Pool'), findsOneWidget);
    // Bottom navigation shows the five adult destinations.
    expect(find.text('Budgets'), findsOneWidget);
    expect(find.text('Savings'), findsOneWidget);
    expect(find.text('Lists'), findsOneWidget);
  });

  testWidgets('live mode without a session shows the login gate',
      (tester) async {
    final env = testEnv();
    await tester.pumpWidget(
      MhuriMoneyApp(
        env: env,
        auth: AuthController(env: env, service: FakeAuthService()),
      ),
    );
    await tester.pumpAndSettle();

    // Gate is up.
    expect(find.text('Welcome to Mhuri Hub'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    // The family app stays hidden behind it.
    expect(find.text('Family Pool'), findsNothing);
  });
}
