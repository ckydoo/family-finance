import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/db/app_database.dart';
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
        onCreate: (db, version) => AppDatabase.createSchema(db),
      ),
    );
    return AppDatabase.wrap(raw);
  }

  test('completed onboarding survives restart with no financial rows',
      () async {
    final db = await freshDb();
    addTearDown(db.raw.close);
    final first = AppState(db: db);
    await first.ready();

    await first.completeOnboarding();
    expect(await db.kvGet('onboarding_done'), '1');

    final restarted = AppState(db: db);
    await restarted.ready();
    expect(restarted.onboardingComplete, isTrue);
  });

  test('an adopted family never returns to create-family after restart',
      () async {
    final db = await freshDb();
    addTearDown(db.raw.close);
    await db.kvSet('space_id', 'family-123');

    final restarted = AppState(db: db);
    await restarted.ready();
    expect(restarted.onboardingComplete, isTrue);
  });
}
