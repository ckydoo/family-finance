import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/db/app_database.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'seed.dart';

/// M1 DoD: "restart the app → everything is still there."
///
/// Simulates two app launches over one database:
///   1. First launch on a fresh DB → the seeded test baseline loads.
///   2. Mutations (move money, expense, item, chore, request, goal…).
///   3. Second launch → every mutation survived the "restart".
///
/// Requires a native SQLite library on the host (sqflite_common_ffi);
/// on Windows keep sqlite3.dll on the PATH if the test reports a load error.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase db;

  setUp(() async {
    final raw = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (d, v) async {
          await AppDatabase.createSchema(d);
        },
      ),
    );
    db = AppDatabase.wrap(raw);
    await seedDb(db.raw);
  });

  tearDown(() async {
    await db.flushWrites();
    await db.raw.close();
  });

  test('first launch loads the baseline; a fresh DB boots empty', () async {
    final first = AppState(db: db);
    await first.ready();

    expect(first.envelopes.length, 4); // the seeded test baseline
    expect(first.txs, isEmpty); // the app itself ships with ZERO rows

    // Baseline is durable: a "second launch" sees the same family.
    final second = AppState(db: db);
    await second.ready();
    expect(second.envelopes.length, first.envelopes.length);
    expect(second.txs.length, first.txs.length);
  });

  test('a locally persisted deletion stays out of balances after restart',
      () async {
    await db.raw.insert('tx', {
      'id': 'deleted-offline-expense',
      'member_id': 'member-a',
      'type': 'expense',
      'amount_minor': 25000,
      'currency': 'usd',
      'method': 'cash',
      'note': 'Removed while offline',
      'when_ms': DateTime(2026, 10, 1).millisecondsSinceEpoch,
      'deleted_at': DateTime(2026, 10, 2).toIso8601String(),
    });

    final restarted = AppState(db: db);
    await restarted.ready();

    expect(restarted.txs, isEmpty);
    expect(restarted.familyTransactions, isEmpty);
    expect(restarted.poolCombined(Currency.usd).minor, 0);
  });

  test('debt repayment and cash entry remain paired after restart', () async {
    final first = AppState(db: db);
    await first.ready();
    first.createDebt(
      name: 'Restart test debt',
      direction: DebtDirection.iOwe,
      principal: const Money(4000, Currency.usd),
    );
    final debt = first.familyDebts.singleWhere(
      (item) => item.name == 'Restart test debt',
    );
    expect(
      first.recordDebtRepayment(
        debt,
        const Money(1500, Currency.usd),
        id: '33333333-3333-4333-8333-333333333333',
      ),
      isTrue,
    );
    await first.flushWrites();

    final restarted = AppState(db: db);
    await restarted.ready();
    expect(restarted.repaidOn(restarted.familyDebts.single).minor, 1500);
    expect(restarted.remainingOnDebt(restarted.familyDebts.single).minor, 2500);
    expect(
      restarted.txs
          .where((tx) => tx.note == 'Debt repayment: Restart test debt'),
      hasLength(1),
    );
    expect(restarted.poolCombined(Currency.usd).minor, -1500);
  });

  test('move money survives a restart', () async {
    final first = AppState(db: db);
    await first.ready();

    final buffer = first.envelope('e7')!; // Emergency buffer
    final fees = first.envelope('e2')!; // School fees
    final before = fees.limit.minor;
    first.moveMoney(
        buffer, fees, Money.fromMajor(25, Currency.usd), 'fees top-up');
    await first.flushWrites();
    expect(fees.limit.minor, before + 2500);

    final second = AppState(db: db);
    await second.ready();
    expect(second.envelope('e2')!.limit.minor, before + 2500);
    // `buffer` (first launch's object) was also decremented by the move,
    // so the reloaded value must equal it exactly.
    expect(second.envelope('e7')!.limit.minor, buffer.limit.minor);
  });

  test('immediate refresh cannot restore a deleted debt or change balance',
      () async {
    final state = AppState(db: db);
    await state.ready();

    state.createDebt(
      name: 'Test debt',
      direction: DebtDirection.iOwe,
      principal: const Money(5000, Currency.usd),
    );
    final debt = state.familyDebts.singleWhere((d) => d.name == 'Test debt');
    state.recordDebtRepayment(
      debt,
      const Money(2500, Currency.usd),
      id: '22222222-2222-4222-8222-222222222222',
    );
    final balanceAfterPayment = state.poolCombined(Currency.usd);
    expect(state.archiveDebt(debt), isTrue);

    // Deliberately do not call flushWrites: refresh itself must serialize the
    // pending transaction, repayment and archived debt writes.
    await state.refresh();

    expect(state.familyDebts.where((d) => d.id == debt.id), isEmpty);
    expect(
      state.poolCombined(Currency.usd).minor,
      balanceAfterPayment.minor,
    );
    expect(
      state.txs.where((tx) => tx.note == 'Debt repayment: Test debt'),
      hasLength(1),
    );
  });

  test('expense, list item, chore, request and goal all survive a restart',
      () async {
    final first = AppState(db: db);
    await first.ready();

    first.addTx(
      type: TxType.expense,
      amount: Money.fromMajor(7.25, Currency.zwg),
      memberId: 'm_maya',
      method: Method.mobileMoney,
      note: 'Roundtrip test expense',
      envelopeId: 'e3',
    );
    first.addItem('Roundtrip soap', 2, Money.fromMajor(1.5, Currency.usd));
    first.contribute(first.goal('g_fees')!, Money.fromMajor(30, Currency.usd));
    first.addGoal(
      name: 'Planned goal',
      target: const Money(75000, Currency.usd),
      deadline: DateTime(2027, 12, 31),
      autoSave: 'US\$ 50.00 monthly',
    );
    final owner = first.realUser;
    const kid = Member(
      id: 'roundtrip-kid',
      name: 'Roundtrip kid',
      emoji: 'child',
      role: Role.kid,
    );
    const teen = Member(
      id: 'roundtrip-teen',
      name: 'Roundtrip teen',
      emoji: 'person',
      role: Role.teen,
    );
    first.members.addAll(const [kid, teen]);
    first.switchUser(kid);
    first.setRealUser(kid);
    first.requestMoney(Money.fromMajor(5, Currency.usd), 'Roundtrip request');
    first.switchUser(teen);
    first.setRealUser(teen);
    first.addEarning(Money.fromMajor(9, Currency.usd), 'Roundtrip job');
    first.switchUser(owner);
    first.setRealUser(owner);
    await first.flushWrites();

    final second = AppState(db: db);
    await second.ready();

    expect(second.txs.any((t) => t.note == 'Roundtrip test expense'), isTrue);
    expect(second.items.any((i) => i.name == 'Roundtrip soap'), isTrue);
    expect(
      second.savedOn(second.goal('g_fees')!).minor,
      first.savedOn(first.goal('g_fees')!).minor,
    );
    final plannedGoal =
        second.goals.singleWhere((g) => g.name == 'Planned goal');
    expect(plannedGoal.deadline, DateTime(2027, 12, 31));
    expect(plannedGoal.autoSave, 'US\$ 50.00 monthly');
    expect(
      second.requests.any((r) => r.reason == 'Roundtrip request'),
      isTrue,
    );
    expect(second.earnings.any((e) => e.note == 'Roundtrip job'), isTrue);
  });

  test('kid approval flow persists request state and jar growth', () async {
    final first = AppState(db: db);
    await first.ready();

    final r = KidRequest(
      id: 'restart-proof-request',
      kidId: 'm_leo',
      amount: Money.fromMajor(4, Currency.usd),
      reason: 'Restart proof',
    );
    first.requests.add(r);
    final jarBefore = first.savedOn(first.goal('g_jar')!).minor;
    first.approveRequest(r);
    await first.flushWrites();

    final second = AppState(db: db);
    await second.ready();
    expect(
      second.requests.singleWhere((r) => r.reason == 'Restart proof').state,
      RequestState.approved,
    );
    expect(
      second.savedOn(second.goal('g_jar')!).minor,
      jarBefore + 400, // + US$4.00 approved into the jar
    );
  });
}
