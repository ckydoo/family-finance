import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/state/app_state.dart';

void main() {
  test('split expense charges each envelope by its allocation', () {
    final state = AppState();
    state.members.add(state.user);
    state.addEnvelope(name: 'Food', limit: const Money(20000, Currency.usd));
    state.addEnvelope(name: 'Home', limit: const Money(20000, Currency.usd));
    final food = state.envelopes[0], home = state.envelopes[1];
    expect(
        state.addTx(
          id: 'split-tx',
          type: TxType.expense,
          amount: const Money(10000, Currency.usd),
          memberId: state.user.id,
          method: Method.cash,
          note: 'Market and cleaning',
          receiptUri: '/receipts/one.jpg',
          allocations: {
            food.id: const Money(6000, Currency.usd),
            home.id: const Money(4000, Currency.usd)
          },
        ),
        isTrue);
    expect(state.spentOn(food).minor, 6000);
    expect(state.spentOn(home).minor, 4000);
    expect(state.txs.single.receiptUri, '/receipts/one.jpg');
  });

  test('split must equal the transaction total', () {
    final state = AppState();
    state.members.add(state.user);
    state.addEnvelope(name: 'Food', limit: const Money(20000, Currency.usd));
    expect(
        state.addTx(
          id: 'bad-split',
          type: TxType.expense,
          amount: const Money(10000, Currency.usd),
          memberId: state.user.id,
          method: Method.cash,
          note: 'Bad split',
          allocations: {
            state.envelopes.single.id: const Money(9000, Currency.usd)
          },
        ),
        isFalse);
    expect(state.txs, isEmpty);
  });
}
