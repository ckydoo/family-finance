import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/db/app_database.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'seed.dart';

/// M7 — the five core family flows (START_HERE's spine), end to end through
/// real AppState + SQLite:
///   1. money in & out → envelopes + pool
///   2. goal contribution → milestone nudge
///   3. kid request → parent approval → jar + no more pending nudge
///   4. shopping run → posted to the Groceries envelope
///   5. recurring bill → reviewed post → survives a restart
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase db;

  setUp(() async {
    final raw = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (d, v) async => AppDatabase.createSchema(d),
      ),
    );
    db = AppDatabase.wrap(raw);
  });

  tearDown(() async {
    await db.raw.close();
  });

  Future<AppState> fresh() async {
    final s = AppState(db: db);
    await s.ready();
    seedMemory(s);
    return s;
  }

  test('flow 1 — money in & out hits envelopes and the family pool', () async {
    final s = await fresh();
    s.txs.clear();
    final groceries = s.envelopes.firstWhere(
      (e) => e.name.toLowerCase().contains('grocer'),
    );
    final spentBefore = s.spentOn(groceries).minor;
    final poolBefore = s.poolCombined(Currency.usd).minor;

    s.addTx(
      type: TxType.expense,
      amount: Money.fromMajor(12.50, Currency.usd),
      memberId: 'm_david',
      method: Method.bankCard,
      note: 'FreshMart run',
      envelopeId: groceries.id,
    );
    expect(s.spentOn(groceries).minor, spentBefore + 1250);
    expect(s.txs.first.note, 'FreshMart run');

    s.addTx(
      type: TxType.income,
      amount: Money.fromMajor(100, Currency.usd),
      memberId: 'm_david',
      method: Method.bankTransfer,
      note: 'Side hustle',
    );
    expect(s.poolCombined(Currency.usd).minor, poolBefore + 10000);
  });

  test('flow 2 — goal contribution saves and nudges a milestone', () async {
    final s = await fresh();
    s.goalTxs.clear();
    final g = s.goal('g_fees')!; // seeded: US$900 target

    s.contribute(g, Money.fromMajor(450, Currency.usd));
    expect(s.savedOn(g).minor, 45000);
    expect(s.goalTxs, hasLength(1));
    expect(
      s.planReminders().any((r) => r.key.startsWith('milestone_g_fees')),
      isTrue,
      reason: 'crossing 25% and 50% fires a goal nudge (J2)',
    );
    await s.flushWrites();
  });

  test('flow 3 — kid asks, parent approves, jar and nudges follow', () async {
    final s = await fresh();
    final jar = s.kidJarGoal!;
    final jarBefore = s.savedOn(jar).minor;

    final req = KidRequest(
      id: 'kr_flow3',
      kidId: 'm_leo',
      amount: Money.fromMajor(5, Currency.usd),
      reason: 'Soccer ball',
    );
    s.requests.add(req);

    // While pending, parents get nudged (J2).
    expect(
      s.planReminders().any((r) => r.key == 'kid_kr_flow3'),
      isTrue,
    );

    s.approveRequest(req);
    expect(req.state, RequestState.approved);
    expect(s.savedOn(jar).minor, jarBefore + 500);
    expect(
      s.planReminders().any((r) => r.key == 'kid_kr_flow3'),
      isFalse,
      reason: 'answered requests stop nudging',
    );
  });

  test('flow 4 — shopping run posts to the Groceries envelope', () async {
    final s = await fresh();
    s.items.clear();
    s.addItem('Rice', 2, Money.fromMajor(5, Currency.usd));
    s.addItem('Cooking oil', 1, Money.fromMajor(8, Currency.usd));
    for (final i in s.items) {
      i.state = ItemState.done;
    }
    s.txs.clear();

    final total = s.finishShopping();
    expect(total.minor, 1800);
    expect(s.txs.first.note, 'Groceries run — FreshMart');
    expect(s.txs.first.envelopeId, isNotNull);
    final target = s.envelope(s.txs.first.envelopeId)!;
    expect(target.name.toLowerCase().contains('grocer'), isTrue);
  });

  test('flow 5 — recurring bill is posted on review and survives a restart',
      () async {
    final s = await fresh();
    s.addRecurring(
      name: 'Rent',
      emoji: 'home',
      amount: Money.fromMajor(250, Currency.usd),
      memberId: 'm_david',
      method: Method.bankTransfer,
      frequency: Frequency.monthly,
      nextDue: DateTime.now().subtract(const Duration(days: 1)),
    );
    final rule = s.recurring.last;

    // Review step: post → expense recorded + schedule advances.
    s.postRecurring(rule);
    expect(rule.nextDue.isAfter(DateTime.now()), isTrue);
    expect(
      s.txs.any((t) => t.note == 'Rent (recurring)'),
      isTrue,
    );
    await s.flushWrites();

    final s2 = AppState(db: db);
    await s2.ready();
    expect(
      s2.txs.any((t) => t.note == 'Rent (recurring)'),
      isTrue,
      reason: 'the posted expense is persisted',
    );
    expect(
      s2.recurring
          .firstWhere((r) => r.name == 'Rent')
          .nextDue
          .isAfter(DateTime.now()),
      isTrue,
      reason: 'the advanced schedule is persisted',
    );
  });
}
