import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/core/l10n/localization_delegates.dart';
import 'package:mhuri_money/features/home/home_screen.dart';
import 'package:mhuri_money/l10n/generated/app_localizations.dart';

void main() {
  testWidgets(
      'approving a request closes the dialog without using dead context',
      (tester) async {
    final state = AppState();
    state.requests
      ..clear()
      ..add(
        KidRequest(
          id: 'request-under-test',
          kidId: 'm_leo',
          amount: Money.fromMajor(10, Currency.usd),
          reason: 'School trip',
        ),
      );

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: const MaterialApp(
          localizationsDelegates: mhuriLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SmartCard()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.text('Approve'), findsOneWidget);

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(state.requests.single.state, RequestState.approved);
    expect(find.text('Approve'), findsNothing);
  });
}
