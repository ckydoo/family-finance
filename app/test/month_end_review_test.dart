import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/planning/month_end_review.dart';
import 'package:mhuri_money/core/state/app_state.dart';

/// 9.6 - month-end review.
///
/// Money left when a cycle closes is never moved silently: the app offers the
/// move once per cycle, only for budgets that would otherwise lose it, and
/// always records the answer so it never nags.
void main() {
  const usd = Currency.usd;

  /// Cycle starts on the 1st; "now" is mid-March, so February is the closed
  /// cycle and the leftover maths only looks at February transactions.
  AppState build({DateTime? now, bool onboarding = true}) {
    final s = AppState(clock: () => now ?? DateTime(2026, 3, 10, 9));
    s.monthStartDay = 1;
    s.onboardingComplete = onboarding;
    return s;
  }

  Envelope env(String id, String name, int limitMinor,
          {Rollover rollover = Rollover.reset}) =>
      Envelope(
        id: id,
        name: name,
        emoji: 'money',
        limit: Money(limitMinor, usd),
        rollover: rollover,
      );

  void spend(AppState s, Envelope e, int minor, DateTime when) {
    s.txs.add(
      Tx(
        id: 'tx_${e.id}_${when.month}_$minor',
        type: TxType.expense,
        amount: Money(minor, usd),
        memberId: 'x',
        method: Method.cash,
        note: 'spend',
        when: when,
        envelopeId: e.id,
      ),
    );
  }

  void earn(AppState s, int minor, DateTime when) {
    s.txs.add(
      Tx(
        id: 'inc_${when.month}_$minor',
        type: TxType.income,
        amount: Money(minor, usd),
        memberId: 'x',
        method: Method.cash,
        note: 'income',
        when: when,
      ),
    );
  }

  Goal goal(AppState s, {bool kidJar = false}) {
    final g = Goal(
      id: kidJar ? 'g_kid' : 'g_save',
      name: kidJar ? 'Tino jar' : 'Emergency fund',
      emoji: 'shield',
      target: const Money(0, usd),
      isKidJar: kidJar,
    );
    s.goals.add(g);
    return g;
  }

  group('review snapshot', () {
    test('shows budget context and totals the real cycle closing balance', () {
      final s = build();
      final groceries = env('e1', 'Groceries', 40000);
      final buffer =
          env('e7', 'Emergency buffer', 50000, rollover: Rollover.roll);
      s.envelopes.addAll([groceries, buffer]);
      spend(s, groceries, 25000, DateTime(2026, 2, 12));
      spend(s, buffer, 20000, DateTime(2026, 2, 14));
      earn(s, 100000, DateTime(2026, 2, 2));

      final review = s.monthEndReview!;
      expect(review.cycleStart, DateTime(2026, 2, 1));
      expect(review.completedAt, DateTime(2026, 3, 1));
      expect(review.lines.length, 2);
      // Biggest leftover first: the buffer kept 300, groceries 150.
      expect(review.lines.first.envelopeId, 'e7');
      expect(review.lines.last.envelopeId, 'e1');
      expect(review.totalLeft.minor, 55000,
          reason: 'closing cash is income less family spending');
      expect(review.carriedLeft.minor, 30000, reason: 'rollover keeps its own');
      expect(review.resetEnvelopes.map((l) => l.envelopeId), ['e1']);
      expect(review.carried.map((l) => l.envelopeId), ['e7']);
    });

    test('overspent budgets produce no line and no negative carry', () {
      final s = build();
      final groceries = env('e1', 'Groceries', 10000);
      s.envelopes.add(groceries);
      spend(s, groceries, 15000, DateTime(2026, 2, 20));

      expect(s.monthEndReview, isNull);
    });

    test('money spent outside the closed cycle is ignored', () {
      final s = build();
      final groceries = env('e1', 'Groceries', 10000);
      s.envelopes.add(groceries);
      // March spend belongs to the current cycle, not the reviewed one.
      spend(s, groceries, 10000, DateTime(2026, 3, 5));

      expect(s.monthEndReview, isNull);
    });

    test('personal and archived budgets stay private', () {
      final s = build();
      final shared = env('e1', 'Groceries', 10000);
      final personal = Envelope(
        id: 'e9',
        name: 'My pocket',
        emoji: 'wallet',
        limit: const Money(5000, usd),
        isPersonal: true,
      );
      final archived = Envelope(
        id: 'e10',
        name: 'Old budget',
        emoji: 'box',
        limit: const Money(5000, usd),
        isArchived: true,
      );
      s.envelopes.addAll([shared, personal, archived]);
      spend(s, shared, 4000, DateTime(2026, 2, 3));
      spend(s, personal, 1000, DateTime(2026, 2, 3));
      spend(s, archived, 1000, DateTime(2026, 2, 3));
      earn(s, 20000, DateTime(2026, 2, 1));

      final review = s.monthEndReview!;
      expect(review.lines.map((l) => l.envelopeId), ['e1']);
    });

    test('no review before onboarding or before a cycle completes', () {
      final fresh = build(onboarding: false);
      fresh.envelopes.add(env('e1', 'Groceries', 10000));
      expect(fresh.monthEndReview, isNull);

      // 1 March is the first day of the very first cycle: nothing closed that
      // the family could have a leftover from yet.
      final firstDay = build(now: DateTime(2026, 3, 1, 8));
      final g = env('e1', 'Groceries', 10000);
      firstDay.envelopes.add(g);
      spend(firstDay, g, 5000, DateTime(2026, 2, 10));
      earn(firstDay, 10000, DateTime(2026, 2, 1));
      expect(firstDay.monthEndReview, isNotNull);
      expect(firstDay.monthEndReview!.totalLeft.minor, 5000);
    });
  });

  group('asking', () {
    test('due once per cycle when closing cash remains available', () {
      final s = build();
      final groceries = env('e1', 'Groceries', 40000);
      s.envelopes.add(groceries);
      spend(s, groceries, 25000, DateTime(2026, 2, 12));
      earn(s, 40000, DateTime(2026, 2, 2));

      expect(s.monthEndReviewDue, isTrue);
      s.markMonthEndReviewed();
      expect(s.monthEndReviewDue, isFalse,
          reason: 'answered for this cycle - never nags twice');

      // The prompt follows actual shared cash, even if the budget remainder
      // happens to be in a rollover envelope.
      final carried = build();
      carried.envelopes
          .add(env('e7', 'Buffer', 50000, rollover: Rollover.roll));
      spend(carried, carried.envelopes.first, 10000, DateTime(2026, 2, 2));
      earn(carried, 20000, DateTime(2026, 2, 1));
      expect(carried.monthEndReviewDue, isTrue);
    });

    test('"never" silences the review until the family opts back in', () {
      final s = build();
      final groceries = env('e1', 'Groceries', 40000);
      s.envelopes.add(groceries);
      spend(s, groceries, 25000, DateTime(2026, 2, 12));
      earn(s, 40000, DateTime(2026, 2, 2));

      s.setMonthEndSweepMode(MonthEndSweepMode.never);
      expect(s.monthEndReviewDue, isFalse);

      s.setMonthEndSweepMode(MonthEndSweepMode.ask);
      expect(s.monthEndReviewDue, isTrue,
          reason: 'switching the preference re-opens the question');
    });

    test('moves the real balance even when only rollover budgets remain', () {
      final s = build();
      final buffer = env('e7', 'Buffer', 50000, rollover: Rollover.roll);
      s.envelopes.add(buffer);
      spend(s, buffer, 10000, DateTime(2026, 2, 2));
      earn(s, 20000, DateTime(2026, 2, 1));
      final target = goal(s);

      expect(s.monthEndReview!.totalLeft.minor, 10000);
      expect(s.sweepMonthEndToGoal(target)!.minor, 10000);
      expect(s.savedOn(target).minor, 10000);
    });
  });

  group('sweeping', () {
    test('moves the leftover into savings and zeroes the budget', () {
      final s = build();
      final groceries = env('e1', 'Groceries', 40000);
      s.envelopes.add(groceries);
      spend(s, groceries, 25000, DateTime(2026, 2, 12));
      final target = goal(s);
      earn(s, 100000, DateTime(2026, 2, 2));
      final cashBefore = s.availableToSpend(usd).minor;

      final movedKind = s.sweepMonthEndToGoal(target)!;

      expect(movedKind.minor, 75000);
      expect(s.savedOn(target).minor, 75000);
      expect(s.availableToSpend(usd).minor, cashBefore - 75000,
          reason: 'swept money leaves the spendable pool');
      // Budget limits are untouched: lowering a limit to 0 would read as
      // "no cap" and quietly unlock unlimited spending.
      expect(groceries.limit.minor, 40000);
      expect(s.monthEndReviewDue, isFalse);
    });

    test('moves all cycle closing cash, including unallocated balance', () {
      final s = build();
      final groceries = env('e1', 'Groceries', 40000);
      final transport = env('e3', 'Transport', 20000);
      s.envelopes.addAll([groceries, transport]);
      spend(s, groceries, 25000, DateTime(2026, 2, 12));
      spend(s, transport, 12000, DateTime(2026, 2, 13));
      earn(s, 100000, DateTime(2026, 2, 2));
      final target = goal(s);

      final moved = s.sweepMonthEndToGoal(target)!;

      expect(moved.minor, 63000);
      expect(s.savedOn(target).minor, 63000);
    });

    test('review amount matches the 33.95 closing balance', () {
      final s = build();
      final groceries = env('e1', 'Groceries', 100000);
      s.envelopes.add(groceries);
      earn(s, 10000, DateTime(2026, 2, 1));
      spend(s, groceries, 6605, DateTime(2026, 2, 28));
      final target = goal(s);

      expect(s.availableToSpend(usd).minor, 3395);
      expect(s.monthEndReview!.totalLeft.minor, 3395);
      expect(s.sweepMonthEndToGoal(target)!.minor, 3395);
      expect(s.availableToSpend(usd).minor, 0);
      expect(s.savedOn(target).minor, 3395);
    });

    test('caps old month-end balance at cash still available today', () {
      final s = build();
      final groceries = env('e1', 'Groceries', 100000);
      s.envelopes.add(groceries);
      earn(s, 10000, DateTime(2026, 2, 1));
      spend(s, groceries, 6605, DateTime(2026, 2, 28));
      spend(s, groceries, 2000, DateTime(2026, 3, 5));
      final target = goal(s);

      expect(s.monthEndReview!.totalLeft.minor, 1395);
      expect(s.sweepMonthEndToGoal(target)!.minor, 1395);
      expect(s.availableToSpend(usd).minor, 0);
    });

    test('never sweeps more cash than the family can still spend', () {
      final s = build();
      final groceries = env('e1', 'Groceries', 40000);
      s.envelopes.add(groceries);
      spend(s, groceries, 10000, DateTime(2026, 2, 12));
      // Nothing came in, so the pool is negative: there is no cash to move.
      final target = goal(s);

      expect(s.sweepMonthEndToGoal(target), isNull);
      expect(s.savedOn(target).minor, 0);
    });

    test('refuses kid jars as a destination', () {
      final s = build();
      final groceries = env('e1', 'Groceries', 40000);
      s.envelopes.add(groceries);
      spend(s, groceries, 25000, DateTime(2026, 2, 12));
      earn(s, 40000, DateTime(2026, 2, 2));
      final jar = goal(s, kidJar: true);

      expect(s.monthEndReviewDue, isTrue);
      expect(s.sweepMonthEndToGoal(jar), isNull);
      expect(s.monthEndSweepGoals, isEmpty);
    });
  });

  group('automatic mode', () {
    test('sweeps once when the family chose "always"', () {
      final s = build();
      final groceries = env('e1', 'Groceries', 40000);
      s.envelopes.add(groceries);
      spend(s, groceries, 25000, DateTime(2026, 2, 12));
      earn(s, 100000, DateTime(2026, 2, 2));
      final target = goal(s);

      s.setMonthEndSweepMode(MonthEndSweepMode.always, goalId: target.id);
      expect(s.monthEndReviewDue, isFalse,
          reason: 'automation replaces asking');

      final moved = s.applyMonthEndAutomation();
      expect(moved?.minor, 75000);
      expect(s.lastMonthEndSweep?.minor, 75000);
      expect(s.savedOn(target).minor, 75000);

      // A second run in the same cycle is a no-op.
      expect(s.applyMonthEndAutomation(), isNull);
      expect(s.savedOn(target).minor, 75000);

      s.clearLastMonthEndSweep();
      expect(s.lastMonthEndSweep, isNull);
    });

    test('does nothing without a chosen goal', () {
      final s = build();
      final groceries = env('e1', 'Groceries', 40000);
      s.envelopes.add(groceries);
      spend(s, groceries, 25000, DateTime(2026, 2, 12));
      earn(s, 40000, DateTime(2026, 2, 2));

      s.setMonthEndSweepMode(MonthEndSweepMode.always);

      expect(s.preferredMonthEndGoal, isNull);
      expect(s.applyMonthEndAutomation(), isNull);
      expect(s.monthEndReviewedCycleKey, isNull);
    });
  });
}
