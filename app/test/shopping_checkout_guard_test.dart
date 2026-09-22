import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/state/app_state.dart';

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
}
