import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/app.dart';
import 'package:mhuri_money/core/auth/auth_controller.dart';
import 'package:mhuri_money/core/state/app_state.dart';

import 'fake_auth.dart';

void main() {
  testWidgets('a bare build boots to the adult Home screen (empty state)',
      (tester) async {
    final env = testEnv();
    final auth = AuthController(env: env, service: FakeAuthService());
    await auth.signIn('test@mhuri.app', '123456');

    final state = AppState(env: env, auth: auth)..onboardingComplete = true;

    await tester.pumpWidget(MhuriMoneyApp(env: env, auth: auth, state: state));
    await tester.pumpAndSettle();

    // A new family gets a short, actionable setup path.
    expect(find.text('Welcome to Mhuri'), findsOneWidget);
    // Bottom navigation shows the five adult destinations.
    expect(find.text('Budgets'), findsOneWidget);
    expect(find.text('Savings'), findsOneWidget);
    expect(find.text('Shopping'), findsOneWidget);

    // Drain the first-run FAB tip timer and snackbar duration.
    await tester.pump(const Duration(seconds: 5));
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
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    // The family app stays hidden behind it.
    expect(find.text('Family Pool'), findsNothing);
  });
}
