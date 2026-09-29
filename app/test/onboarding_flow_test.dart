import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mhuri_money/app.dart';
import 'package:mhuri_money/core/auth/auth_controller.dart';
import 'package:mhuri_money/core/config/app_env.dart';

import 'fake_auth.dart';

/// Proves the first-run gate end-to-end (live mode):
///   sign in → family setup (create / join choice).
/// The create/join engine paths are covered by the sync tests (create_space /
/// join_space RPCs); here we verify the WIRING and the UI states.
void main() {
  Future<AuthController> signedInAuth(AppEnv env) async {
    final auth = AuthController(env: env, service: FakeAuthService());
    await auth.signIn('david@mhuri.app', '123456');
    return auth;
  }

  void sizeWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('live first run: sign in → family setup is presented',
      (tester) async {
    sizeWindow(tester);
    final env = testEnv();
    final auth = await signedInAuth(env);

    await tester.pumpWidget(MhuriMoneyApp(env: env, auth: auth));
    await tester.pumpAndSettle();

    // Family setup is on screen - the gate is wired.
    expect(find.text('Mhuri'), findsOneWidget);
    expect(find.text('Create your family'), findsOneWidget);
    expect(find.text('Family Pool'), findsNothing);
  });

  testWidgets('create path shows name + family name + working CTA',
      (tester) async {
    sizeWindow(tester);
    final env = testEnv();
    final auth = await signedInAuth(env);

    await tester.pumpWidget(MhuriMoneyApp(env: env, auth: auth));
    await tester.pumpAndSettle();

    expect(find.text('Preferred name'), findsOneWidget);
    expect(find.text('Family name'), findsOneWidget);
    expect(find.text('Continue  →'), findsOneWidget);
  });

  testWidgets('join path shows the invite-code field', (tester) async {
    sizeWindow(tester);
    final env = testEnv();
    final auth = await signedInAuth(env);

    await tester.pumpWidget(MhuriMoneyApp(env: env, auth: auth));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I have an invite code'));
    await tester.pumpAndSettle();

    expect(find.text('Invite code'), findsOneWidget);
    expect(find.text('Join family'), findsOneWidget);
  });
}
