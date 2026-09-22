import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Local SQLite database (M1 persistence).
///
/// Hand-written schema mirroring `backend/schema.sql` (single family space,
/// local scope). No code generation — everything here is plain Dart/SQL so it
/// can be written and statically verified without a Dart toolchain.
///
/// `open()` returns null on any failure and the app silently falls back to
/// null, so main() can show the setup screen instead of crashing.
class AppDatabase {
  final Database raw;

  AppDatabase._(this.raw);

  /// Public wrapper for tests (sqflite_common_ffi in-memory databases).
  factory AppDatabase.wrap(Database raw) => AppDatabase._(raw);

  // ── Key-value helpers (session tokens, PINs, settings) ──────────────────

  Future<String?> kvGet(String key) async {
    try {
      final rows =
          await raw.query('kv', where: 'k = ?', whereArgs: [key], limit: 1);
      if (rows.isEmpty) return null;
      return rows.first['v'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> kvSet(String key, String value) async {
    await raw.insert(
      'kv',
      {'k': key, 'v': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// One-time legacy purge (first live boot): a device upgraded from a
  /// earlier build carries stale rows + markers in its local db.
  /// Deletes every user row — kv included; the caller immediately re-flags
  /// the purge. Real adopted data is never present when this may run.
  Future<void> wipeUserData() async {
    for (final t in const [
      'account', 'envelope', 'tx', 'goal', 'goal_tx', 'recurring', 'outbox',
      'list_item', 'chore', 'kid_request', 'proposal', 'earning', 'circle',
      'kv',
    ]) {
      await raw.delete(t);
    }
  }

  static Future<AppDatabase?> open() async {
    try {
      final dir = await getDatabasesPath();
      final db = await openDatabase(
        p.join(dir, 'mhuri_money.db'),
        version: 3,
        onCreate: (d, version) async => createSchema(d),
        onUpgrade: (d, oldV, newV) async => upgrade(d, oldV),
      );
      return AppDatabase._(db);
    } catch (_) {
      // No database available (tests, web, storage error) → null.
      return null;
    }
  }

  static const List<String> schema = [
    '''
    CREATE TABLE IF NOT EXISTS account (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      emoji TEXT NOT NULL,
      currency TEXT NOT NULL,
      minor INTEGER NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS envelope (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      emoji TEXT NOT NULL,
      limit_minor INTEGER NOT NULL,
      limit_currency TEXT NOT NULL,
      rollover TEXT NOT NULL,
      is_personal INTEGER NOT NULL DEFAULT 0
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS tx (
      id TEXT PRIMARY KEY,
      envelope_id TEXT,
      member_id TEXT NOT NULL,
      type TEXT NOT NULL,
      amount_minor INTEGER NOT NULL,
      currency TEXT NOT NULL,
      method TEXT NOT NULL,
      note TEXT NOT NULL,
      when_ms INTEGER NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS goal (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      emoji TEXT NOT NULL,
      target_minor INTEGER NOT NULL,
      target_currency TEXT NOT NULL,
      auto_save TEXT,
      is_kid_jar INTEGER NOT NULL DEFAULT 0,
      owner_member_id TEXT
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS goal_tx (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      server_id TEXT,
      goal_id TEXT NOT NULL,
      member_id TEXT NOT NULL,
      amount_minor INTEGER NOT NULL,
      currency TEXT NOT NULL,
      at_ms INTEGER NOT NULL
    )
    ''',
    '''
    CREATE UNIQUE INDEX IF NOT EXISTS goal_tx_server_id_idx
      ON goal_tx (server_id) WHERE server_id IS NOT NULL
    ''',
    '''
    CREATE TABLE IF NOT EXISTS recurring (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      emoji TEXT NOT NULL,
      amount_minor INTEGER NOT NULL,
      currency TEXT NOT NULL,
      envelope_id TEXT,
      member_id TEXT NOT NULL,
      method TEXT NOT NULL,
      frequency TEXT NOT NULL,
      next_due_ms INTEGER NOT NULL,
      active INTEGER NOT NULL DEFAULT 1
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS outbox (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      entity TEXT NOT NULL,
      op_id TEXT NOT NULL UNIQUE,
      payload TEXT NOT NULL,
      created_ms INTEGER NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS list_item (
      id TEXT PRIMARY KEY,
      list_id TEXT,
      name TEXT NOT NULL,
      qty INTEGER NOT NULL,
      est_minor INTEGER NOT NULL,
      currency TEXT NOT NULL,
      state TEXT NOT NULL,
      added_by TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS chore (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      stars INTEGER NOT NULL,
      state TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS kid_request (
      id TEXT PRIMARY KEY,
      kid_id TEXT NOT NULL,
      amount_minor INTEGER NOT NULL,
      currency TEXT NOT NULL,
      reason TEXT NOT NULL,
      state TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS proposal (
      id TEXT PRIMARY KEY,
      teen_id TEXT NOT NULL,
      amount_minor INTEGER NOT NULL,
      currency TEXT NOT NULL,
      envelope_id TEXT NOT NULL,
      reason TEXT NOT NULL,
      state TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS earning (
      id TEXT PRIMARY KEY,
      member_id TEXT NOT NULL,
      note TEXT NOT NULL,
      amount_minor INTEGER NOT NULL,
      currency TEXT NOT NULL,
      when_ms INTEGER NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS circle (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      name TEXT NOT NULL,
      contribution_minor INTEGER NOT NULL,
      currency TEXT NOT NULL,
      total_rounds INTEGER NOT NULL,
      current_round INTEGER NOT NULL,
      order_json TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS kv (
      k TEXT PRIMARY KEY,
      v TEXT NOT NULL
    )
    ''',
  ];

  static Future<void> createSchema(Database d) async {
    for (final sql in schema) {
      await d.execute(sql);
    }
  }

  /// Migrations. ALTERs are guarded — re-running is safe.
  /// v2: sync columns + outbox · v3: recurring rules.
  static Future<void> upgrade(Database d, int oldVersion) async {
    if (oldVersion >= 2 && oldVersion < 2) return;
    if (oldVersion < 2) {
      for (final sql in [
        'ALTER TABLE list_item ADD COLUMN list_id TEXT',
        'ALTER TABLE goal_tx ADD COLUMN server_id TEXT',
        'CREATE UNIQUE INDEX IF NOT EXISTS goal_tx_server_id_idx'
            ' ON goal_tx (server_id) WHERE server_id IS NOT NULL',
      ]) {
        try {
          await d.execute(sql);
        } catch (_) {
          // column/index already exists — fine.
        }
      }
    }
    await createSchema(d); // outbox & recurring are CREATE IF NOT EXISTS
  }
}
