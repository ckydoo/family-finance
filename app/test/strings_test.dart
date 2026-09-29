import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:mhuri_money/app.dart';
import 'package:mhuri_money/core/auth/auth_controller.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/l10n/generated/app_localizations.dart';

import 'fake_auth.dart';

/// M6 - internationalization: all six ARB languages stay in lockstep, the
/// English template keeps the strings the widget tests assert, and the
/// locale switch actually re-renders the app.
const kLocales = ['en', 'sn', 'nd', 'es', 'fr', 'pt'];

Map<String, dynamic> arb(String code) =>
    jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  group('ARB files (6 languages)', () {
    test('every language has the template key set, with non-empty values', () {
      final en = arb('en');
      final enKeys = en.keys.where((k) => !k.startsWith('@')).toSet();
      expect(enKeys, isNotEmpty);

      for (final code in kLocales.skip(1)) {
        final m = arb(code);
        expect(m['@@locale'], code, reason: 'app_$code.arb @@locale');
        final keys = m.keys.where((k) => !k.startsWith('@')).toSet();
        expect(keys, enKeys, reason: 'app_$code.arb key parity with en');
        for (final k in keys) {
          expect((m[k] as String).trim(), isNotEmpty,
              reason: 'app_$code.arb $k is empty');
        }
      }
      for (final k in enKeys) {
        expect((en[k] as String).trim(), isNotEmpty, reason: 'en $k empty');
      }
    });

    test('placeholder keys declare their placeholders', () {
      final en = arb('en');
      expect(en.containsKey('@safeToSpend'), isTrue,
          reason: 'en template declares @safeToSpend');
      for (final code in kLocales) {
        final m = arb(code);
        final safe = m['safeToSpend'] as String;
        expect(safe.contains('{amount}'), isTrue, reason: code);
        final sched = m['scheduledOn'] as String;
        expect(sched.contains('{from}') && sched.contains('{to}'), isTrue,
            reason: code);
      }
    });

    test('English keeps the exact strings the UI tests assert', () {
      final en = arb('en');
      const asserted = [
        'Family Pool',
        'Regular payments',
        'No activity yet',
        'No goals yet',
        'Shopping',
        'Activity',
        'Start the family meeting',
        'Export transactions (CSV)',
        'Reminders on this device',
        'Quiet hours',
        'Starts on',
        'Money, managed together',
        'Skip',
      ];
      for (final s in asserted) {
        expect(en.values.contains(s), isTrue, reason: 'missing in en: $s');
      }
      expect(
        (en['remindersTitle'] as String).endsWith('Reminders'),
        isTrue,
        reason: 'bell sheet title ends with Reminders (emoji prefix)',
      );
      expect(
        (en['scheduledOn'] as String).startsWith('Scheduled on this device'),
        isTrue,
      );
    });
  });

  testWidgets('switching language re-renders the whole app', (tester) async {
    final env = testEnv();
    final auth = AuthController(env: env, service: FakeAuthService());
    await auth.signIn('test@mhuri.app', '123456');
    final state = AppState(env: env, auth: auth)..onboardingComplete = true;
    state.addEnvelope(
      name: 'Groceries',
      limit: Money.fromMajor(100, Currency.usd),
    );

    await tester.pumpWidget(MhuriMoneyApp(env: env, auth: auth, state: state));
    await tester.pumpAndSettle();
    expect(find.text('Available to spend'), findsOneWidget);

    // Grab the live state from any widget under the app scope.
    final context = tester.element(find.text('Available to spend'));
    final s = AppScope.of(context);
    s.setLocale('es');
    await tester.pumpAndSettle();

    expect(find.text('Presupuestos'), findsOneWidget);
    expect(AppLocalizations.of(context)!.localeName, 'es');

    // And to chiShona.
    s.setLocale('sn');
    await tester.pumpAndSettle();
    expect(find.text('Bhajeti'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
  });
}
