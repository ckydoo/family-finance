import 'package:flutter_test/flutter_test.dart';

import 'package:mhuri_money/app.dart';
import 'package:mhuri_money/core/auth/auth_controller.dart';
import 'package:mhuri_money/core/auth/auth_service.dart';
import 'package:mhuri_money/core/config/app_env.dart';

/// Proves the first-run gate end-to-end (live mode):
///   login → sign in → onboarding (slide 1 copy visible) → skip → Home.
/// State persistence of the flag itself is covered in m4_test.
void main() {
  testWidgets('live first run: sign in → onboarding → skip → Home',
      (tester) async {
    final env = AppEnv.parse(
      'APP_ENV=live\n'
      'SUPABASE_URL=https://abcdefgh.supabase.co\n'
      'SUPABASE_ANON_KEY=k\n',
    );
    final auth = AuthController(env: env, service: DemoAuthService());
    await auth.signIn('david@mhuri.app', '123456');

    await tester.pumpWidget(MhuriMoneyApp(env: env, auth: auth));
    await tester.pumpAndSettle();

    // Onboarding slide 1 is on screen — the gate is wired.
    expect(find.text('Money, managed together'), findsOneWidget);
    expect(find.text('Family Pool'), findsNothing);

    // Skipping completes onboarding and reveals the app.
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Family Pool'), findsOneWidget);
    expect(find.text('Money, managed together'), findsNothing);
  });

  testWidgets('final CTA uses the localized label on the last slide',
      (tester) async {
    final env = AppEnv.parse(
      'APP_ENV=live\n'
      'SUPABASE_URL=https://abcdefgh.supabase.co\n'
      'SUPABASE_ANON_KEY=k\n',
    );
    final auth = AuthController(env: env, service: DemoAuthService());
    await auth.signIn('david@mhuri.app', '123456');

    await tester.pumpWidget(MhuriMoneyApp(env: env, auth: auth));
    await tester.pumpAndSettle();

    // Walk to the last slide.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text("Let's get started"), findsOneWidget);
    expect(find.text('Gentle reminders'), findsOneWidget);
  });
}
