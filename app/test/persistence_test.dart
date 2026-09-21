import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/db/app_database.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// M1 DoD: "restart the app → everything is still there."
///
/// Simulates two app launches over one database:
///   1. First launch on a fresh DB → demo seed is written through.
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
  });

  tearDown(() async {
    await db.raw.close();
  });

  test('first launch seeds the demo family into the database', () async {
    final first = AppState(db: db);
    await first.ready();

    expect(first.envelopes.length, 8);
    expect(first.txs.length, greaterThan(10));

    // Seeded state is durable: a "second launch" sees the same family.
    final second = AppState(db: db);
    await second.ready();
    expect(second.envelopes.length, first.envelopes.length);
    expect(second.txs.length, first.txs.length);
  });

  test('move money survives a restart', () async {
    final first = AppState(db: db);
    await first.ready();

    final buffer = first.envelope('e7')!; // Emergency buffer
    final fees = first.envelope('e2')!; // School fees
    final before = fees.limit.minor;
    first.moveMoney(buffer, fees, Money.fromMajor(25, Currency.usd), 'fees top-up');
    await first.flushWrites();
    expect(fees.limit.minor, before + 2500);

    final second = AppState(db: db);
    await second.ready();
    expect(second.envelope('e2')!.limit.minor, before + 2500);
    // `buffer` (first launch's object) was also decremented by the move,
    // so the reloaded value must equal it exactly.
    expect(second.envelope('e7')!.limit.minor, buffer.limit.minor);
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
    first.requestMoney(Money.fromMajor(5, Currency.usd), 'Roundtrip request');
    first.addEarning(Money.fromMajor(9, Currency.usd), 'Roundtrip job');
    await first.flushWrites();

    final second = AppState(db: db);
    await second.ready();

    expect(second.txs.any((t) => t.note == 'Roundtrip test expense'), isTrue);
    expect(second.items.any((i) => i.name == 'Roundtrip soap'), isTrue);
    expect(
      second.savedOn(second.goal('g_fees')!).minor,
      first.savedOn(first.goal('g_fees')!).minor,
    );
    expect(
      second.requests.any((r) => r.reason == 'Roundtrip request'),
      isTrue,
    );
    expect(second.earnings.any((e) => e.note == 'Roundtrip job'), isTrue);
  });

  test('kid approval flow persists request state and jar growth', () async {
    final first = AppState(db: db);
    await first.ready();

    first.requestMoney(Money.fromMajor(4, Currency.usd), 'Restart proof');
    await first.flushWrites();
    final r = first.requests.first;
    final jarBefore = first.savedOn(first.goal('g_jar')!).minor;
    first.approveRequest(r);
    await first.flushWrites();

    final second = AppState(db: db);
    await second.ready();
    expect(second.requests.first.state, RequestState.approved);
    expect(
      second.savedOn(second.goal('g_jar')!).minor,
      jarBefore + 400, // + US$4.00 approved into the jar
    );
  });
}
