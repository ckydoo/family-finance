import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/db/app_database.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'seed.dart';

/// M4: cycle math, recurring review flow, onboarding/settings persistence,
/// and CSV export failing soft outside a device.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('cycle math (payday-aligned, M4)', () {
    test('day 25 cycle wraps into the previous month', () {
      final s = AppState();
      s.setMonthStartDay(25);
      expect(s.cycleStartFor(DateTime(2026, 9, 21)), DateTime(2026, 8, 25));
      expect(
        s.nextCycleStartFor(DateTime(2026, 9, 21)),
        DateTime(2026, 9, 25),
      );
      // On the start day itself the new cycle is already active.
      expect(s.cycleStartFor(DateTime(2026, 9, 25)), DateTime(2026, 9, 25));
      expect(
        s.nextCycleStartFor(DateTime(2026, 9, 25)),
        DateTime(2026, 10, 25),
      );
    });

    test('day 1 cycle is the calendar month', () {
      final s = AppState();
      s.setMonthStartDay(1);
      expect(s.cycleStartFor(DateTime(2026, 9, 21)), DateTime(2026, 9, 1));
      expect(
        s.nextCycleStartFor(DateTime(2026, 9, 21)),
        DateTime(2026, 10, 1),
      );
    });

    test('setMonthStartDay rejects out-of-range values', () {
      final s = AppState();
      s.setMonthStartDay(31);
      expect(s.monthStartDay, 1);
      s.setMonthStartDay(0);
      expect(s.monthStartDay, 1);
      s.setMonthStartDay(15);
      expect(s.monthStartDay, 15);
    });

    test('rollover envelope gains carry when the previous cycle was clean', () {
      final s = AppState();
      seedMemory(s);
      s.setMonthStartDay(1);
      // Deterministic: pretend nothing was ever spent.
      s.txs.clear();
      final buffer = s.envelope('e7')!; // Emergency buffer, rollover=roll
      expect(s.effectiveLimit(buffer).minor, buffer.limit.minor * 2);
    });
  });

  group('recurring expenses (C7 — reviewed, not silent)', () {
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

    test('due rule posts on review and advances (with catch-up)', () async {
      final s = AppState(db: db);
      await s.ready();
      s.txs.clear();

      s.addRecurring(
        name: 'Water bill',
        emoji: 'water',
        amount: Money.fromMajor(10, Currency.usd),
        memberId: 'm_david',
        method: Method.bankTransfer,
        frequency: Frequency.weekly,
        nextDue: DateTime.now().subtract(const Duration(days: 1)),
        envelopeId: 'e1',
      );
      expect(s.dueRecurring.map((r) => r.name), contains('Water bill'));

      final txCountBefore = s.txs.length;
      final rule = s.dueRecurring.first;
      s.postRecurring(rule);

      // posted exactly one expense
      expect(s.txs.length, txCountBefore + 1);
      expect(s.txs.first.note, 'Water bill (recurring)');
      expect(s.txs.first.amount.minor, 1000);
      expect(s.txs.first.envelopeId, 'e1');

      // schedule advanced into the future
      expect(rule.nextDue.isAfter(DateTime.now()), isTrue);
      await s.flushWrites();

      // restart: rule + posted expense both survive
      final second = AppState(db: db);
      await second.ready();
      expect(second.recurring.any((r) => r.name == 'Water bill'), isTrue);
      expect(
        second.txs.any((t) => t.note == 'Water bill (recurring)'),
        isTrue,
      );
    });

    test('skip advances without posting; toggle pauses', () async {
      final s = AppState(db: db);
      await s.ready();

      s.addRecurring(
        name: 'Airtime',
        emoji: 'airtime',
        amount: Money.fromMajor(5, Currency.usd),
        memberId: 'm_david',
        method: Method.mobileMoney,
        frequency: Frequency.weekly,
        nextDue: DateTime.now(),
      );
      final rule = s.recurring.last;
      final txCount = s.txs.length;

      s.skipRecurring(rule);
      expect(s.txs.length, txCount, reason: 'skip must not post');
      expect(rule.nextDue.isAfter(DateTime.now()), isTrue);

      s.toggleRecurring(rule);
      expect(rule.active, isFalse);
      expect(s.dueRecurring.any((r) => r.id == rule.id), isFalse,
          reason: 'paused rules never surface as due');
      await s.flushWrites();
    });
  });

  group('onboarding & settings persistence', () {
    test('onboarding flag and month start survive a restart', () async {
      final raw = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (d, v) async => AppDatabase.createSchema(d),
        ),
      );
      final db = AppDatabase.wrap(raw);

      final first = AppState(db: db);
      await first.ready();
      expect(first.onboardingComplete, isFalse);
      first.completeOnboarding();
      first.setMonthStartDay(25);
      await first.flushWrites();

      final second = AppState(db: db);
      await second.ready();
      expect(second.onboardingComplete, isTrue);
      expect(second.monthStartDay, 25);
      // Cycles now start on the 25th, whatever today is.
      expect(second.cycleStart.day, 25);

      await db.raw.close();
    });

    test('exportCsv fails soft outside a device (returns null, no throw)',
        () async {
      final s = AppState();
      final path = await s.exportCsv();
      expect(path, isNull);
    });
  });
}
