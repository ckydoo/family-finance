import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/l10n/localization_delegates.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/core/theme/app_theme.dart';
import 'package:mhuri_money/features/lists/lists_screen.dart';
import 'package:mhuri_money/l10n/generated/app_localizations.dart';

void main() {
  test('a completed shopping trip can only create one expense', () {
    final state = AppState();
    state.members.add(state.user);
    state.addEnvelope(
      name: 'Groceries',
      limit: Money.fromMajor(300, Currency.usd),
    );
    state.addItem('Rice', 2, Money.fromMajor(5, Currency.usd));
    state.addItem('Cooking oil', 1, Money.fromMajor(8, Currency.usd));
    for (final item in state.items) {
      item.state = ItemState.done;
    }

    final before = state.txs.length;
    expect(state.finishShopping().minor, 1800);
    expect(state.txs, hasLength(before + 1));
    expect(state.items.every((item) => item.checkedOut), isTrue);

    expect(state.finishShopping().isZero, isTrue);
    expect(state.txs, hasLength(before + 1));
  });

  test('moving a logged item back to to-buy starts a new shopping cycle', () {
    final state = AppState();
    state.members.add(state.user);
    state.addItem('Milk', 1, Money.fromMajor(2, Currency.usd));
    final item = state.items.single..state = ItemState.done;

    state.finishShopping();
    expect(item.checkedOut, isTrue);

    state.advanceItem(item);
    expect(item.state, ItemState.tobuy);
    expect(item.checkedOut, isFalse);
  });

  test('checkout uses actual prices, selected budget, method and purchaser',
      () {
    final state = AppState();
    state.members.add(state.user);
    state.addEnvelope(
      name: 'Household',
      limit: Money.fromMajor(200, Currency.usd),
    );
    final envelope = state.envelopes.single;
    state.addItem(
      'Soap',
      2,
      Money.fromMajor(4, Currency.usd),
      assignedToId: state.user.id,
    );
    final item = state.items.single
      ..state = ItemState.done
      ..actual = Money.fromMajor(5, Currency.usd);

    expect(
      state
          .finishShopping(
            envelopeId: envelope.id,
            method: Method.mobileMoney,
          )
          .minor,
      1000,
    );
    expect(state.txs.single.envelopeId, envelope.id);
    expect(state.txs.single.method, Method.mobileMoney);
    expect(item.assignedToId, state.user.id);
    expect(item.purchasedById, state.user.id);
  });

  test(
      'items without estimated prices do not get checked out at zero and deduct properly when customTotal is supplied',
      () {
    final state = AppState();
    state.members.add(state.user);
    state.addTx(
      type: TxType.income,
      amount: Money.fromMajor(100, Currency.usd),
      memberId: state.user.id,
      method: Method.cash,
      note: 'Salary',
    );
    state.addEnvelope(
      name: 'Groceries',
      limit: const Money(0, Currency.usd),
    );
    state.setOverspendPolicy(OverspendPolicy.block);
    final groceries = state.envelopes.single;

    state.addItem('Bread', 1, const Money(0, Currency.usd));
    final bread = state.items.single..state = ItemState.incart;

    // Without an estimate or customTotal, finishShopping must not mark the item
    // as checked out or create a $0 transaction.
    expect(state.finishShopping().isZero, isTrue);
    expect(bread.checkedOut, isFalse);

    // With customTotal entered at checkout, the expense is recorded and
    // deducted from both the budget and availableToSpend.
    final logged = state.finishShopping(
      envelopeId: groceries.id,
      method: Method.cash,
      customTotal: Money.fromMajor(12.50, Currency.usd),
    );
    expect(logged.minor, 1250);
    expect(bread.checkedOut, isTrue);
    expect(bread.actual?.minor, 1250);
    expect(state.spentOn(groceries).minor, 1250);
    expect(state.availableToSpend(Currency.usd).minor, 8750);
  });

  testWidgets(
      'ListsScreen checkout records expense for unpriced items and deducts from budget and pool',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = AppState();
    state.members.add(state.user);
    state.addTx(
      type: TxType.income,
      amount: Money.fromMajor(200, Currency.usd),
      memberId: state.user.id,
      method: Method.cash,
      note: 'Salary',
    );
    state.addEnvelope(
      name: 'Groceries',
      limit: Money.fromMajor(100, Currency.usd),
    );
    final groceries = state.envelopes.single;
    state.addItem('Veggies', 1, const Money(0, Currency.usd));

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          theme: buildAppTheme(),
          localizationsDelegates: mhuriLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ListsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Check off Veggies -> moves to incart and stays visible on the To buy view
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('Veggies'), findsOneWidget);

    // Tap "Record shopping expense"
    await tester.tap(find.text('Record shopping expense'));
    await tester.pumpAndSettle();

    // Enter the checkout amount in the total field
    await tester.enterText(
      find.byKey(const ValueKey('shopping_checkout_amount')),
      '15.00',
    );
    await tester.tap(find.text('Record expense'));
    await tester.pumpAndSettle();

    expect(state.spentOn(groceries).minor, 1500);
    expect(state.remainingOn(groceries).minor, 8500);
    expect(state.availableToSpend(Currency.usd).minor, 18500);
    expect(find.textContaining('Deducted from Groceries:'), findsOneWidget);
  });
}
