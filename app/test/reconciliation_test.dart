import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/db/app_database.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'seed.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Phase 2 - Money Workflows & Authoritative Ledger Reconciliation', () {
    late AppDatabase db;
    late AppState s;

    setUp(() async {
      final raw = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (d, v) async => AppDatabase.createSchema(d),
        ),
      );
      db = AppDatabase.wrap(raw);
      s = AppState(db: db);
      await s.ready();
      seedMemory(s);
    });

    tearDown(() async {
      await db.raw.close();
    });

    test('addTx idempotency prevents duplicate transaction on retry/double-tap',
        () {
      final initialTxCount = s.txs.length;
      final openingPool = s.poolCombined(Currency.usd);

      const txId = 'tx-idempotent-001';
      // First submission
      final addedFirst = s.addTx(
        id: txId,
        type: TxType.expense,
        amount: const Money(1500, Currency.usd), // $15.00
        memberId: s.user.id,
        method: Method.cash,
        note: 'Fresh bread and milk',
        envelopeId: s.envelopes.first.id,
      );
      expect(addedFirst, isTrue);
      expect(s.txs.length, initialTxCount + 1);
      final poolAfterFirst = s.poolCombined(Currency.usd);
      expect(poolAfterFirst.minor, openingPool.minor - 1500);

      // Duplicate submission (double tap / retry) with identical id
      final addedSecond = s.addTx(
        id: txId,
        type: TxType.expense,
        amount: const Money(1500, Currency.usd),
        memberId: s.user.id,
        method: Method.cash,
        note: 'Fresh bread and milk',
        envelopeId: s.envelopes.first.id,
      );
      expect(addedSecond, isFalse);

      // Count and pool must remain strictly unchanged
      expect(s.txs.length, initialTxCount + 1);
      expect(s.poolCombined(Currency.usd).minor, poolAfterFirst.minor);
    });

    test('contribute idempotency prevents duplicate savings contributions', () {
      final goal = s.goals.first;
      final initialSaved = s.savedOn(goal);
      const contribId = 'goal-contrib-idempotent-001';

      s.contribute(
        goal,
        const Money(2000, Currency.usd), // $20.00
        id: contribId,
      );

      final savedAfterFirst = s.savedOn(goal);
      expect(savedAfterFirst.minor, initialSaved.minor + 2000);

      // Double-tap / retry
      s.contribute(
        goal,
        const Money(2000, Currency.usd),
        id: contribId,
      );

      expect(s.savedOn(goal).minor, savedAfterFirst.minor);
    });

    test('moveMoney idempotency maintains envelope balance invariants', () {
      expect(s.envelopes.length, greaterThanOrEqualTo(2));
      final envFrom = s.envelopes[0];
      final envTo = s.envelopes[1];

      final fromLimitBefore = s.effectiveLimit(envFrom).minor;
      final toLimitBefore = s.effectiveLimit(envTo).minor;
      final totalLimitsBefore = fromLimitBefore + toLimitBefore;

      const moveId = 'move-money-idempotent-001';
      s.moveMoney(
        envFrom,
        envTo,
        const Money(1000, Currency.usd),
        'Balancing groceries',
        id: moveId,
      );

      expect(s.effectiveLimit(envFrom).minor, fromLimitBefore - 1000);
      expect(s.effectiveLimit(envTo).minor, toLimitBefore + 1000);
      expect(
        s.effectiveLimit(envFrom).minor + s.effectiveLimit(envTo).minor,
        totalLimitsBefore,
      );

      // Double tap move
      s.moveMoney(
        envFrom,
        envTo,
        const Money(1000, Currency.usd),
        'Balancing groceries',
        id: moveId,
      );

      // Invariant remains intact, no second deduction
      expect(s.effectiveLimit(envFrom).minor, fromLimitBefore - 1000);
      expect(s.effectiveLimit(envTo).minor, toLimitBefore + 1000);
    });

    test('Mukando circleCollect idempotency prevents duplicate rounds', () {
      s.setMukandoEnabled(true);
      s.circle = SavingsCircle(
        name: 'Family Mukando',
        contribution: const Money(5000, Currency.usd),
        totalRounds: 6,
        currentRound: 1,
        order: const ['Mama', 'Baba', 'Gogo'],
      );

      final initialRound = s.circle.currentRound;

      s.circleCollect(id: 'mukando_round_${initialRound + 1}');
      expect(s.circle.currentRound, initialRound + 1);

      // Retry / double-tap
      s.circleCollect(id: 'mukando_round_${initialRound + 1}');
      expect(s.circle.currentRound, initialRound + 1);
    });

    test(
        'finishShopping idempotency runs checkout once and ignores re-triggers',
        () {
      final initialTxCount = s.txs.length;

      // Add shopping item
      final item = ListItem(
        id: 'item-recon-001',
        name: 'Maize meal 10kg',
        qty: 1,
        est: const Money(850, Currency.usd),
        state: ItemState.done,
        checkedOut: false,
        addedById: s.user.id,
      );
      s.items.add(item);

      const checkoutTxId = 'checkout-tx-001';
      final total = s.finishShopping(txId: checkoutTxId);
      expect(total.minor, greaterThan(0));
      expect(s.txs.length, initialTxCount + 1);
      expect(item.checkedOut, isTrue);

      // Immediate second call
      final totalSecond = s.finishShopping(txId: checkoutTxId);
      expect(totalSecond.isZero, isTrue);
      expect(s.txs.length, initialTxCount + 1);
    });

    test('approveRequest & declineRequest are strictly once-only', () {
      s.members.add(const Member(
        id: 'm_leo',
        name: 'Leo',
        emoji: 'child',
        role: Role.kid,
      ));

      final req = KidRequest(
        id: 'kid-req-recon-001',
        kidId: 'm_leo',
        amount: const Money(500, Currency.usd),
        reason: 'Drawing book',
      );
      s.requests.insert(0, req);
      final initialGoalTxsCount = s.goalTxs.length;

      s.approveRequest(req);
      expect(req.state, RequestState.approved);
      final goalTxsAfterFirst = s.goalTxs.length;
      expect(goalTxsAfterFirst, initialGoalTxsCount + 1);

      // Attempt second approval
      s.approveRequest(req);
      expect(s.goalTxs.length, goalTxsAfterFirst);

      // Attempt decline on already approved request
      s.declineRequest(req);
      expect(req.state, RequestState.approved);
    });

    test(
        'OverspendPolicy.block strictly halts expenses exceeding envelope limit',
        () {
      s.setOverspendPolicy(OverspendPolicy.block);
      final env = s.envelopes.first;
      final remaining = s.remainingOn(env);

      // Amount larger than remaining
      final excessiveAmount = Money(remaining.minor + 5000, remaining.currency);

      final added = s.addTx(
        type: TxType.expense,
        amount: excessiveAmount,
        memberId: s.user.id,
        method: Method.cash,
        note: 'Excessive item',
        envelopeId: env.id,
      );

      expect(added, isFalse);
      expect(s.txs.any((t) => t.note == 'Excessive item'), isFalse);
    });

    test('Authoritative ledger reconciliation: Pool equals ledger sum', () {
      const cur = Currency.usd;
      final poolInitial = s.poolCombined(cur).minor;

      // Add a series of income and expenses
      s.addTx(
        id: 'tx-recon-inc-1',
        type: TxType.income,
        amount: const Money(20000, Currency.usd), // +$200.00
        memberId: s.user.id,
        method: Method.bankTransfer,
        note: 'Consulting gig',
      );

      s.addTx(
        id: 'tx-recon-exp-1',
        type: TxType.expense,
        amount: const Money(4500, Currency.usd), // -$45.00
        memberId: s.user.id,
        method: Method.cash,
        note: 'Groceries market',
        envelopeId: s.envelopes.first.id,
      );

      s.addTx(
        id: 'tx-recon-exp-2',
        type: TxType.expense,
        amount: const Money(3000, Currency.usd), // -$30.00
        memberId: s.user.id,
        method: Method.mobileMoney,
        note: 'Utility bill',
        envelopeId: s.envelopes[1].id,
      );

      // Total expected pool: initial + 20000 - 4500 - 3000 = initial + 12500
      final expectedPool = poolInitial + 20000 - 4500 - 3000;
      expect(s.poolCombined(cur).minor, expectedPool);
    });

    test('all financial summaries reconcile after edit, savings and delete',
        () {
      s.accounts.clear();
      s.txs.clear();
      s.goalTxs.clear();
      s.envelopes
        ..clear()
        ..add(Envelope(
          id: 'trust-budget',
          name: 'Trust budget',
          emoji: 'money',
          limit: const Money(30000, Currency.usd),
        ));
      s.goals
        ..clear()
        ..add(const Goal(
          id: 'trust-goal',
          name: 'Emergency fund',
          emoji: 'target',
          target: Money(50000, Currency.usd),
        ));

      s.addTx(
        id: 'trust-income',
        type: TxType.income,
        amount: const Money(100000, Currency.usd),
        memberId: s.user.id,
        method: Method.bankTransfer,
        note: 'Salary',
      );
      s.addTx(
        id: 'trust-expense',
        type: TxType.expense,
        amount: const Money(12500, Currency.usd),
        memberId: s.user.id,
        method: Method.cash,
        note: 'Groceries',
        envelopeId: 'trust-budget',
      );
      s.contribute(
        s.goals.single,
        const Money(10000, Currency.usd),
        id: 'trust-saving',
      );

      expect(s.monthIncome.minor, 100000);
      expect(s.monthSpend.minor, 12500);
      expect(s.monthSaved.minor, 10000);
      expect(s.poolCombined(Currency.usd).minor, 87500);
      expect(s.availableToSpend(Currency.usd).minor, 77500);
      expect(s.spentOn(s.envelopes.single).minor, 12500);

      final expense = s.txs.firstWhere((tx) => tx.id == 'trust-expense');
      expect(
        s.updateTx(
          expense,
          amount: const Money(15000, Currency.usd),
          method: Method.mobileMoney,
          note: 'Corrected groceries',
          when: expense.when,
          envelopeId: expense.envelopeId,
        ),
        isTrue,
      );
      expect(s.monthSpend.minor, 15000);
      expect(s.poolCombined(Currency.usd).minor, 85000);
      expect(s.availableToSpend(Currency.usd).minor, 75000);

      final corrected = s.txs.firstWhere((tx) => tx.id == 'trust-expense');
      expect(s.deleteTx(corrected), isTrue);
      expect(s.monthSpend.minor, 0);
      expect(s.poolCombined(Currency.usd).minor, 100000);
      expect(s.availableToSpend(Currency.usd).minor, 90000);
    });
  });
}
