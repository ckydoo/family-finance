import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/l10n/localization_delegates.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/features/budgets/budgets_screen.dart';
import 'package:mhuri_money/l10n/generated/app_localizations.dart';

import 'seed.dart';

void main() {
  testWidgets('move-money selectors fit a phone-width envelope sheet',
      (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState();
    seedMemory(state);

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: const MaterialApp(
          localizationsDelegates: mhuriLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: BudgetsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('School fees').first);
    await tester.pumpAndSettle();

    expect(find.text('Move money'), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('New envelope creates an envelope instead of showing a stub',
      (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState();
    final originalCount = state.envelopes.length;

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: const MaterialApp(
          localizationsDelegates: mhuriLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: BudgetsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('New budget'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('New budget'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), 'Rent');
    await tester.enterText(fields.at(1), '350');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(state.envelopes, hasLength(originalCount + 1));
    expect(state.envelopes.last.name, 'Rent');
    expect(tester.takeException(), isNull);
  });

  test(
      'deduplicateEnvelopes merges duplicate envelopes and preserves transactions',
      () {
    final state = AppState();
    state.addEnvelope(
      name: 'Groceries',
      limit: const Money(0, Currency.usd),
      emoji: 'basket',
    );
    // Simulate duplicate envelope coming from server / another source
    final duplicate = Envelope(
      id: 'e_dup_123',
      name: 'groceries', // case variation
      emoji: 'basket',
      limit: const Money(15000, Currency.usd),
    );
    state.envelopes.add(duplicate);

    // Add transaction to the duplicate
    state.txs.add(
      Tx(
        id: 'tx_dup_1',
        memberId: 'm1',
        type: TxType.expense,
        amount: const Money(3000, Currency.usd),
        method: Method.cash,
        note: 'Supermarket',
        when: DateTime.now(),
        envelopeId: 'e_dup_123',
      ),
    );

    expect(state.envelopes.where((e) => e.name.toLowerCase() == 'groceries'),
        hasLength(2));

    state.deduplicateEnvelopes();

    // Exactly one groceries envelope remains
    final groceries = state.envelopes
        .where((e) => e.name.toLowerCase() == 'groceries')
        .toList();
    expect(groceries, hasLength(1));
    // The envelope with the transaction/limit was retained
    expect(groceries.first.id, 'e_dup_123');
    expect(groceries.first.limit.minor, 15000);
    // The transaction's envelopeId is valid and points to the kept envelope
    expect(state.txs.first.envelopeId, groceries.first.id);
  });

  test('addEnvelope updates existing envelope rather than creating duplicates',
      () {
    final state = AppState();
    state.addEnvelope(
      name: 'Transport',
      limit: const Money(0, Currency.usd),
      emoji: 'bus',
    );
    expect(state.envelopes.where((e) => e.name.toLowerCase() == 'transport'),
        hasLength(1));
    final initialId = state.envelopes.first.id;

    // Call addEnvelope again with same name (different case and limit)
    state.addEnvelope(
      name: 'transport',
      limit: const Money(5000, Currency.usd),
      emoji: 'car',
    );

    // Still exactly 1 envelope, updated in-place with new limit
    final transport = state.envelopes
        .where((e) => e.name.toLowerCase() == 'transport')
        .toList();
    expect(transport, hasLength(1));
    expect(transport.first.id, initialId);
    expect(transport.first.limit.minor, 5000);
    expect(transport.first.emoji, 'car');
  });

  testWidgets(
      'tapping unconfigured envelope opens Set Budget sheet directly, configured opens Detail sheet',
      (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState();
    // Add one unconfigured envelope ($0 limit) and one configured envelope ($100 limit)
    state.addEnvelope(
      name: 'Unset Category',
      limit: const Money(0, Currency.usd),
      emoji: 'basket',
    );
    state.addEnvelope(
      name: 'Groceries',
      limit: const Money(10000, Currency.usd),
      emoji: 'basket',
    );

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: const MaterialApp(
          localizationsDelegates: mhuriLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: BudgetsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap unconfigured envelope -> Should show 'Set Unset Category budget' and 'Set budget' button
    await tester.tap(find.text('Unset Category').first);
    await tester.pumpAndSettle();

    expect(find.text('Set Unset Category budget'), findsOneWidget);
    expect(find.text('Set budget'), findsOneWidget);
    expect(find.text('Move money'), findsNothing);

    // Close the sheet
    Navigator.of(tester.element(find.text('Set Unset Category budget'))).pop();
    await tester.pumpAndSettle();

    // Tap configured envelope -> Should show Detail / Move money sheet
    await tester.tap(find.text('Groceries').first);
    await tester.pumpAndSettle();

    expect(find.text('Move money'), findsAtLeastNWidgets(1));
    expect(find.text('Set Groceries budget'), findsNothing);
  });
}

