import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/db/app_database.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Future<AppDatabase> freshDb() async {
    final raw = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        singleInstance: false,
        onCreate: (db, version) => AppDatabase.createSchema(db),
      ),
    );
    return AppDatabase.wrap(raw);
  }

  test('applyFamilySetupSettings without primary preserves secondaryCurrency and custom rate',
      () async {
    final db = await freshDb();
    addTearDown(db.raw.close);
    final s = AppState(db: db);
    await s.ready();

    s.setPrimaryCurrency(Currency.usd);
    s.setSecondaryCurrency(Currency.zwg);
    s.setCustomRate(28.75);

    await s.applyFamilySetupSettings(
      stage: 'complete',
      templates: const [
        {'key': 'groceries', 'name': 'Groceries', 'icon': 'cart'},
      ],
    );

    expect(s.primaryCurrency, Currency.usd);
    expect(s.secondaryCurrency, Currency.zwg);
    expect(s.rate, closeTo(28.75, 0.0001));
  });

  test('applyServerRate isolates USD/ZWG pair and inverts when ZWG is primary',
      () async {
    final db = await freshDb();
    addTearDown(db.raw.close);
    final s = AppState(db: db);
    await s.ready();

    // USD -> EUR must never be overwritten by a server usd_zwg snapshot.
    s.setPrimaryCurrency(Currency.usd);
    s.setSecondaryCurrency(Currency.eur);
    final eurRate = s.rate;
    await s.applyServerRate(27.40);
    expect(s.rate, closeTo(eurRate, 0.0001));

    // ZWG -> USD receives the inverted 1 / usd_zwg rate.
    s.setPrimaryCurrency(Currency.zwg);
    s.setSecondaryCurrency(Currency.usd);
    await s.applyServerRate(25.0);
    expect(s.rate, closeTo(0.04, 0.0001));
  });

  test('market rateMode reset restores cached server_rate for USD/ZWG',
      () async {
    final db = await freshDb();
    addTearDown(db.raw.close);
    final s = AppState(db: db);
    await s.ready();

    s.setPrimaryCurrency(Currency.usd);
    s.setSecondaryCurrency(Currency.zwg);
    await s.applyServerRate(27.15);
    expect(s.rate, closeTo(27.15, 0.0001));

    await s.applyFamilySetupSettings(
      stage: 'complete',
      primary: 'USD',
      secondary: 'ZWG',
      customRate: 30.0,
      rateMode: 'custom',
    );
    expect(s.rate, closeTo(30.0, 0.0001));

    await s.applyFamilySetupSettings(
      stage: 'complete',
      primary: 'USD',
      secondary: 'ZWG',
      rateMode: 'market',
    );
    expect(s.rate, closeTo(27.15, 0.0001));
  });
}
