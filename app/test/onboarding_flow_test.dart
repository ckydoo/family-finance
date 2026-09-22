import 'package:flutter_test/flutter_test.dart';

import 'package:mhuri_money/app.dart';
import 'package:mhuri_money/core/auth/auth_controller.dart';
import 'package:mhuri_money/core/auth/auth_service.dart';
import 'package:mhuri_money/core/config/app_env.dart';

import 'fake_auth.dart';

/// Proves the first-run gate end-to-end (live mode):
///   sign in → family setup (welcome → create/join choice) → Skip → Home.
/// The create/join engine paths are covered by the sync tests (create_space /
/// join_space RPCs); here we verify the WIRING and the UI states.
/// Flag persistence is covered in m4_test.
void main() {
  Future<AuthController> signedInAuth(AppEnv env) async {
    final auth = AuthController(env: env, service: FakeAuthService());
    await auth.signIn('david@mhuri.app', '123456');
    return auth;
  }

  testWidgets('live first run: sign in → family setup → skip → Home',
      (tester) async {
    final env = testEnv();
    final auth = await signedInAuth(env);

    await tester.pumpWidget(MhuriMoneyApp(env: env, auth: auth));
    await tester.pumpAndSettle();

    // Family setup is on screen (welcome step) — the gate is wired.
    expect(find.text('Money, managed together'), findsOneWidget);
    expect(find.text('Family Pool'), findsNothing);

    // Welcome → choice.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Set up your family'), findsOneWidget);
    expect(find.text('Create a family'), findsOneWidget);
    expect(find.text('Join with a code'), findsOneWidget);

    // The setup flow always offers an exit that lands in the app.
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(find.text('Family Pool'), findsOneWidget);
    expect(find.text('Set up your family'), findsNothing);
  });

  testWidgets('create path shows name + household type + working CTA',
      (tester) async {
    final env = testEnv();
    final auth = await signedInAuth(env);

    await tester.pumpWidget(MhuriMoneyApp(env: env, auth: auth));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create a family'));
    await tester.pumpAndSettle();

    expect(find.text('Family name'), findsOneWidget);
    expect(find.text('What kind of family?'), findsOneWidget);
    expect(find.text('Couple with kids'), findsOneWidget);
    expect(find.text('Extended family'), findsOneWidget);
    expect(find.text('Create family'), findsOneWidget);
  });

  testWidgets('join path shows the invite-code field', (tester) async {
    final env = testEnv();
    final auth = await signedInAuth(env);

    await tester.pumpWidget(MhuriMoneyApp(env: env, auth: auth));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join with a code'));
    await tester.pumpAndSettle();

    expect(find.text('Invite code'), findsOneWidget);
    expect(find.text('Join family'), findsOneWidget);
  });
}
