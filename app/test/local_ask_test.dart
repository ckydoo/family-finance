import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/ai/local_ask.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/state/app_state.dart';

/// Ask Mhuri's offline path.
///
/// When the AI function is not configured, unreachable or failing, the four
/// questions Mhuri itself suggests must still get a truthful answer computed
/// from the family's own records - and anything outside that set must return
/// null so the app keeps its "couldn't answer" path instead of guessing.
void main() {
  const usd = Currency.usd;

  AppState build({DateTime? now}) {
    final state = AppState(clock: () => now ?? DateTime(2026, 11, 10, 9));
    state.monthStartDay = 1;
    state.onboardingComplete = true;
    return state;
  }

  void earn(AppState s, int minor, DateTime when, {String id = 'inc'}) {
    s.txs.add(Tx(
      id: '${id}_$minor',
      type: TxType.income,
      amount: Money(minor, usd),
      memberId: 'x',
      method: Method.cash,
      note: 'income',
      when: when,
    ));
  }

  void spend(AppState s, Envelope e, int minor, DateTime when) {
    s.txs.add(Tx(
      id: 'sp_${e.id}_$minor',
      type: TxType.expense,
      amount: Money(minor, usd),
      memberId: 'x',
      method: Method.cash,
      note: 'spend',
      when: when,
      envelopeId: e.id,
    ));
  }

  Envelope envelope(String id, String name, int limit) {
    final value = Envelope(
      id: id,
      name: name,
      emoji: 'money',
      limit: Money(limit, usd),
    );
    return value;
  }

  group('answers from records', () {
    test('affordability separates cash from bills still due', () {
      final s = build(now: DateTime(2026, 11, 10));
      earn(s, 100000, DateTime(2026, 11, 2));
      final food = envelope('e1', 'Groceries', 40000);
      s.envelopes.add(food);
      spend(s, food, 25000, DateTime(2026, 11, 5));

      final answer = answerFromRecords(
          s, 'Can we afford something extra this month?');
      expect(answer, isNotNull);
      expect(answer!.text, contains('available to spend'));
      expect(answer.text.toLowerCase(), contains('estimate'));
      expect(answer.facts['available_to_spend'], isNotNull);
    });

    test('bills list what is coming up and totals it', () {
      final s = build(now: DateTime(2026, 11, 10));
      earn(s, 200000, DateTime(2026, 11, 1));
      s.recurring.add(RecurringRule(
        id: 'r1',
        name: 'Rent',
        emoji: 'home',
        amount: const Money(50000, usd),
        memberId: 'x',
        method: Method.bankTransfer,
        frequency: Frequency.monthly,
        nextDue: DateTime(2026, 11, 20),
      ));

      final answer = answerFromRecords(s, 'What bills are coming up?');
      expect(answer, isNotNull);
      expect(answer!.text, contains('Rent'));
      expect(answer.facts['due_before_next_cycle'], isNotNull);
    });

    test('spending ranks the biggest budget first', () {
      final s = build();
      final food = envelope('e1', 'Groceries', 50000);
      final travel = envelope('e2', 'Transport', 30000);
      s.envelopes.addAll([food, travel]);
      spend(s, food, 30000, DateTime(2026, 11, 4));
      spend(s, travel, 5000, DateTime(2026, 11, 4));

      final answer = answerFromRecords(s, 'Where are we spending the most?');
      expect(answer, isNotNull);
      expect(answer!.facts['top_category'], 'Groceries');
      final groceriesAt = answer.text.indexOf('Groceries');
      final transportAt = answer.text.indexOf('Transport');
      expect(groceriesAt, lessThan(transportAt),
          reason: 'biggest budget listed first');
    });

    test('savings reports progress and a weekly amount when a deadline exists',
        () {
      final s = build(now: DateTime(2026, 11, 10));
      s.goals.add(Goal(
        id: 'g1',
        name: 'School fees',
        emoji: 'school',
        target: const Money(100000, usd),
        deadline: DateTime(2027, 1, 19),
      ));

      final answer = answerFromRecords(s, 'How much can we save toward a goal?');
      expect(answer, isNotNull);
      expect(answer!.text, contains('School fees'));
      expect(answer.text, contains('a week'));
    });

    test('budget leftovers are labelled budget room, not cash', () {
      final s = build();
      final food = envelope('e1', 'Groceries', 40000);
      s.envelopes.add(food);
      spend(s, food, 10000, DateTime(2026, 11, 5));

      final answer = answerFromRecords(s, 'What is left in our budgets?');
      expect(answer, isNotNull);
      expect(answer!.text, contains('Groceries'));
      expect(answer.text, contains('not cash'));
    });

    test('empty records stay honest instead of inventing figures', () {
      final s = build();
      expect(answerFromRecords(s, 'Can we afford something extra?'), isNull,
          reason: 'nothing recorded - no cash estimate to give');
      expect(answerFromRecords(s, 'Where are we spending the most?'), isNull);
    });

    test('questions outside the offline set return null', () {
      final s = build();
      earn(s, 50000, DateTime(2026, 11, 1));
      for (final question in [
        'Should we invest in bitcoin?',
        'What is the meaning of life?',
        'Tell me a joke',
      ]) {
        expect(answerFromRecords(s, question), isNull, reason: question);
      }
    });
  });
}
