import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:mhuri_money/app.dart';
import 'package:mhuri_money/core/auth/auth_controller.dart';
import 'package:mhuri_money/core/auth/auth_service.dart';
import 'package:mhuri_money/core/config/app_env.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/state/app_state.dart';

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

    await tester.tap(find.text('Savings'));
    await tester.pumpAndSettle();
    expect(find.text("Kids' jars"), findsOneWidget);
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

  testWidgets('Quick Add supports cancel, backdrop, back, and save',
      (tester) async {
    await tester.pumpWidget(const MhuriMoneyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Quick add'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Quick add'), findsNothing);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Quick add'), findsNothing);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Quick add'), findsNothing);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '10');
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Quick add'), findsNothing);
  });

  testWidgets('approving a pending Home card safely closes its dialog',
      (tester) async {
    await tester.pumpWidget(const MhuriMoneyApp());
    await tester.pumpAndSettle();

    final state = AppScope.of(tester.element(find.text('Family Pool')));
    state.proposeExpense(
      Money.fromMajor(15, Currency.usd),
      'e1',
      'Study group',
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Review'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(find.text('Approve'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
