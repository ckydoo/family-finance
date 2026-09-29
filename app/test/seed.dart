import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Minimal REAL-data baseline for tests. The app itself boots empty;
/// tests that exercise math over named envelopes/goals insert exactly the
/// rows they reference - nothing ships from here.
///
/// Two flavors:
///   * [seedDb]   - rows in the local database, so simulated restarts see them.
///   * [seedMemory] - rows in an in-memory state (no-db test states).
Future<void> seedDb(Database raw) async {
  await raw.insert(
    'kv',
    {'k': 'live_purged_v1', 'v': '1'},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
  const envelopes = [
    {
      'id': 'e1', 'name': 'Groceries', 'emoji': 'cart',
      'limit_minor': 40000, 'limit_currency': 'usd',
      'rollover': 'reset', 'is_personal': 0,
    },
    {
      'id': 'e2', 'name': 'School fees', 'emoji': 'school',
      'limit_minor': 25000, 'limit_currency': 'usd',
      'rollover': 'reset', 'is_personal': 0,
    },
    {
      'id': 'e3', 'name': 'Transport', 'emoji': 'bus',
      'limit_minor': 15000, 'limit_currency': 'usd',
      'rollover': 'reset', 'is_personal': 0,
    },
    {
      'id': 'e7', 'name': 'Emergency buffer', 'emoji': 'shield',
      'limit_minor': 50000, 'limit_currency': 'usd',
      'rollover': 'roll', 'is_personal': 0,
    },
  ];
  for (final r in envelopes) {
    await raw.insert('envelope', r);
  }
  const goals = [
    {
      'id': 'g_fees', 'name': 'School fees fund', 'emoji': 'school',
      'target_minor': 90000, 'target_currency': 'usd',
      'auto_save': null, 'is_kid_jar': 0, 'owner_member_id': null,
    },
    {
      'id': 'g_jar', 'name': 'Leo jar', 'emoji': 'jar',
      'target_minor': 5000, 'target_currency': 'usd',
      'auto_save': null, 'is_kid_jar': 1, 'owner_member_id': 'm_leo',
    },
  ];
  for (final r in goals) {
    await raw.insert('goal', r);
  }
}

void seedMemory(AppState s) {
  s.envelopes.addAll([
    Envelope(
        id: 'e1',
        name: 'Groceries',
        emoji: 'cart',
        limit: const Money(40000, Currency.usd)),
    Envelope(
        id: 'e2',
        name: 'School fees',
        emoji: 'school',
        limit: const Money(25000, Currency.usd)),
    Envelope(
        id: 'e3',
        name: 'Transport',
        emoji: 'bus',
        limit: const Money(15000, Currency.usd)),
    Envelope(
        id: 'e7',
        name: 'Emergency buffer',
        emoji: 'shield',
        limit: const Money(50000, Currency.usd),
        rollover: Rollover.roll),
  ]);
  s.goals.addAll(const [
    Goal(
        id: 'g_fees',
        name: 'School fees fund',
        emoji: 'school',
        target: Money(90000, Currency.usd)),
    Goal(
        id: 'g_jar',
        name: 'Leo jar',
        emoji: 'jar',
        target: Money(5000, Currency.usd),
        isKidJar: true,
        ownerMemberId: 'm_leo'),
  ]);
}
