import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/l10n/localization_delegates.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/features/quickadd/quick_add_sheet.dart';
import 'package:mhuri_money/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('expense over the envelope limit requires confirmation',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = AppState();
    state.members.add(state.user);
    state.addEnvelope(
      name: 'Groceries',
      limit: const Money(30000, Currency.usd),
    );
    final before = state.txs.length;

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          localizationsDelegates: mhuriLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showQuickAdd(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '350');
    await tester.pump();

    expect(find.textContaining('US\$ 50.00 over budget'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('This envelope will be over budget'), findsOneWidget);
    expect(state.txs, hasLength(before));

    await tester.tap(find.text('Adjust amount'));
    await tester.pumpAndSettle();
    expect(find.text('Quick add'), findsOneWidget);
    expect(state.txs, hasLength(before));

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log anyway'));
    await tester.pumpAndSettle();
    expect(state.txs, hasLength(before + 1));
    expect(state.remainingOn(state.envelopes.first).minor, -5000);
    expect(tester.takeException(), isNull);
  });
}
