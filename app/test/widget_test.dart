import 'package:flutter_test/flutter_test.dart';

import 'package:mhuri_money/app.dart';
import 'package:mhuri_money/core/auth/auth_controller.dart';
import 'package:mhuri_money/core/auth/auth_service.dart';
import 'package:mhuri_money/core/config/app_env.dart';

void main() {
  testWidgets('app boots to the adult Home screen (demo mode)', (tester) async {
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
    final env = AppEnv.parse(
      'APP_ENV=live\n'
      'SUPABASE_URL=https://abcdefgh.supabase.co\n'
      'SUPABASE_ANON_KEY=k\n',
    );
    await tester.pumpWidget(
      MhuriMoneyApp(
        env: env,
        auth: AuthController(env: env, service: DemoAuthService()),
      ),
    );
    await tester.pumpAndSettle();

    // Gate is up.
    expect(find.text('Welcome to Mhuri Money'), findsOneWidget);
    expect(find.text('Send code'), findsOneWidget);
    // The family app stays hidden behind it.
    expect(find.text('Family Pool'), findsNothing);
  });
}
