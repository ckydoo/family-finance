import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Local SQLite database (M1 persistence).
///
/// Hand-written schema mirroring `backend/schema.sql` (single family space,
/// local scope). No code generation - everything here is plain Dart/SQL so it
/// can be written and statically verified without a Dart toolchain.
///
/// `open()` returns null on any failure and the app silently falls back to
/// null, so main() can show the setup screen instead of crashing.
class AppDatabase {
  final Database raw;

  AppDatabase._(this.raw);

  /// Public wrapper for tests (sqflite_common_ffi in-memory databases).
  factory AppDatabase.wrap(Database raw) => AppDatabase._(raw);

  static const List<String> _accountTables = [
    'account',
    'envelope',
    'tx',
    'goal',
    'goal_tx',
    'recurring',
    'outbox',
    'shopping_list',
    'list_item',
    'chore',
    'kid_request',
    'proposal',
    'earning',
    'circle',
    'budget_cycle_plan',
    'family_activity',
    'contribution_campaign',
    'contribution_pledge',
    'contribution_payment',
    'family_debt',
    'debt_repayment',
    'tx_allocation',
    'family_chat_message',
    'family_task',
  ];

  static const Set<String> _familyKvKeys = {
    'space_id',
    'space_name',
    'invite_code',
    'default_list_id',
    'members_v1',
    'me_id',
    'onboarding_done',
    'onboarding_stage',
    'onboarding_templates',
    'dismissed_getting_started',
    'month_start_day',
    'primary_currency',
    'secondary_currency',
    'displayCurrency',
    'custom_rate',
    'server_rate',
    'mukando_enabled',
    'profile_edits',
    'stars',
    'request_results_seen',
    'sync_cursor',
    'last_sync_ms',
  };

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
  /// Deletes every user row - kv included; the caller immediately re-flags
  /// the purge. Real adopted data is never present when this may run.
  Future<void> wipeUserData() async {
    for (final t in const [
      'account',
      'envelope',
      'tx',
      'goal',
      'goal_tx',
      'recurring',
      'outbox',
      'list_item',
      'chore',
      'kid_request',
      'proposal',
      'earning',
      'circle',
      'budget_cycle_plan',
      'family_activity',
      'contribution_campaign',
      'contribution_pledge',
      'contribution_payment',
      'family_debt',
      'debt_repayment',
      'tx_allocation',
      'family_chat_message',
      'family_task',
      'kv',
      'account_cache',
    ]) {
      await raw.delete(t);
    }
  }

  static Future<AppDatabase?> open() async {
    try {
      final dir = await getDatabasesPath();
      final db = await openDatabase(
        p.join(dir, 'mhuri_money.db'),
        version: 14,
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
      ,is_archived INTEGER NOT NULL DEFAULT 0
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
      ,deleted_at TEXT
      ,receipt_uri TEXT
      ,recurring_rule_id TEXT
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
      ,status TEXT NOT NULL DEFAULT 'active'
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
      ,is_archived INTEGER NOT NULL DEFAULT 0
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
      added_by TEXT NOT NULL,
      checked_out INTEGER NOT NULL DEFAULT 0,
      assigned_to_id TEXT,
      actual_minor INTEGER,
      actual_currency TEXT,
      purchased_by_id TEXT,
      deleted_at TEXT
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS shopping_list (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'active',
      deleted_at TEXT
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS chore (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      stars INTEGER NOT NULL,
      state TEXT NOT NULL
      ,assignee_member_id TEXT
      ,is_archived INTEGER NOT NULL DEFAULT 0
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
    '''
    CREATE TABLE IF NOT EXISTS account_cache (
      user_id TEXT PRIMARY KEY,
      payload TEXT NOT NULL,
      updated_ms INTEGER NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS budget_cycle_plan (
      id TEXT PRIMARY KEY,
      cycle_start TEXT NOT NULL UNIQUE,
      income_mode TEXT NOT NULL,
      expected_income_minor INTEGER,
      currency TEXT NOT NULL,
      allocations_json TEXT NOT NULL,
      is_closed INTEGER NOT NULL DEFAULT 0,
      closed_at TEXT,
      copied_from TEXT
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS family_activity (
      id TEXT PRIMARY KEY,
      actor_id TEXT NOT NULL,
      action TEXT NOT NULL,
      entity TEXT NOT NULL,
      entity_id TEXT,
      detail_json TEXT NOT NULL,
      at_ms INTEGER NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS contribution_campaign (
      id TEXT PRIMARY KEY, name TEXT NOT NULL,
      target_minor INTEGER NOT NULL, currency TEXT NOT NULL,
      deadline_ms INTEGER NOT NULL, created_by_id TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'active'
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS contribution_pledge (
      id TEXT PRIMARY KEY, campaign_id TEXT NOT NULL,
      member_id TEXT NOT NULL, amount_minor INTEGER NOT NULL,
      currency TEXT NOT NULL, created_at_ms INTEGER NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS contribution_payment (
      id TEXT PRIMARY KEY, campaign_id TEXT NOT NULL,
      member_id TEXT NOT NULL, amount_minor INTEGER NOT NULL,
      currency TEXT NOT NULL, paid_at_ms INTEGER NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS family_debt (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, direction TEXT NOT NULL,
      principal_minor INTEGER NOT NULL, currency TEXT NOT NULL,
      counterparty_member_id TEXT, due_date_ms INTEGER,
      status TEXT NOT NULL, created_by_id TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS debt_repayment (
      id TEXT PRIMARY KEY, debt_id TEXT NOT NULL, member_id TEXT NOT NULL,
      amount_minor INTEGER NOT NULL, currency TEXT NOT NULL,
      paid_at_ms INTEGER NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS tx_allocation (
      id TEXT PRIMARY KEY, tx_id TEXT NOT NULL, envelope_id TEXT NOT NULL,
      amount_minor INTEGER NOT NULL, currency TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS family_chat_message (
      id TEXT PRIMARY KEY,
      family_id TEXT NOT NULL,
      sender_id TEXT NOT NULL,
      text TEXT NOT NULL,
      created_at_ms INTEGER NOT NULL,
      is_system INTEGER NOT NULL DEFAULT 0,
      sender_name TEXT,
      sender_avatar TEXT,
      status TEXT NOT NULL DEFAULT 'sent',
      reference_type TEXT,
      reference_id TEXT,
      reference_title TEXT,
      reference_meta TEXT,
      deleted INTEGER NOT NULL DEFAULT 0
    )
    ''',
    '''
    CREATE INDEX IF NOT EXISTS family_chat_message_family_created_idx
      ON family_chat_message (family_id, created_at_ms DESC)
    ''',
    '''
    CREATE TABLE IF NOT EXISTS family_task (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      note TEXT,
      assignee_member_id TEXT,
      created_by_member_id TEXT,
      created_at_ms INTEGER NOT NULL,
      due_at_ms INTEGER,
      status TEXT NOT NULL DEFAULT 'open',
      points INTEGER NOT NULL DEFAULT 1,
      is_archived INTEGER NOT NULL DEFAULT 0
    )
    ''',
    '''
    CREATE INDEX IF NOT EXISTS family_task_due_idx
      ON family_task (due_at_ms, created_at_ms DESC)
    ''',
  ];

  bool _isFamilyKv(String key) =>
      _familyKvKeys.contains(key) || key.startsWith('sync_cursor_');

  /// Parks the active account's complete family cache, including its outbox.
  /// The snapshot never contains auth tokens or device-wide preferences.
  Future<void> parkAccountData(String userId) async {
    if (userId.isEmpty) return;
    await raw.transaction((txn) async {
      final tables = <String, List<Map<String, Object?>>>{};
      for (final table in _accountTables) {
        tables[table] = await txn.query(table);
      }
      final kvRows = await txn.query('kv');
      final familyKv = [
        for (final row in kvRows)
          if (_isFamilyKv(row['k']?.toString() ?? '')) row,
      ];
      final payload = jsonEncode({'tables': tables, 'kv': familyKv});
      await txn.insert(
        'account_cache',
        {
          'user_id': userId,
          'payload': payload,
          'updated_ms': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// Restores a previously parked account partition. Returns false for a
  /// first-time account on this device.
  Future<bool> restoreAccountData(String userId) async {
    if (userId.isEmpty) return false;
    final rows = await raw.query(
      'account_cache',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final decoded = jsonDecode(rows.first['payload']! as String);
    if (decoded is! Map) return false;
    final tables = decoded['tables'];
    final kvRows = decoded['kv'];
    if (tables is! Map || kvRows is! List) return false;

    await raw.transaction((txn) async {
      for (final table in _accountTables) {
        await txn.delete(table);
      }
      final currentKv = await txn.query('kv');
      for (final row in currentKv) {
        final key = row['k']?.toString() ?? '';
        if (_isFamilyKv(key)) {
          await txn.delete('kv', where: 'k = ?', whereArgs: [key]);
        }
      }
      for (final table in _accountTables) {
        final storedRows = tables[table];
        if (storedRows is! List) continue;
        for (final stored in storedRows.whereType<Map>()) {
          final row = <String, Object?>{
            for (final entry in stored.entries)
              entry.key.toString(): entry.value,
          };
          if (table == 'outbox' || table == 'goal_tx') row.remove('id');
          await txn.insert(
            table,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      for (final stored in kvRows.whereType<Map>()) {
        final key = stored['k']?.toString();
        final value = stored['v']?.toString();
        if (key == null || value == null || !_isFamilyKv(key)) continue;
        await txn.insert(
          'kv',
          {'k': key, 'v': value},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    return true;
  }

  Future<void> clearActiveAccountData() async {
    await raw.transaction((txn) async {
      for (final table in _accountTables) {
        await txn.delete(table);
      }
      final currentKv = await txn.query('kv');
      for (final row in currentKv) {
        final key = row['k']?.toString() ?? '';
        if (_isFamilyKv(key)) {
          await txn.delete('kv', where: 'k = ?', whereArgs: [key]);
        }
      }
    });
  }

  Future<void> deleteAccountCache(String userId) async {
    if (userId.isEmpty) return;
    await raw.delete(
      'account_cache',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  /// Family-scoped values currently loaded into the active partition.
  /// Callers use this to keep alternate key-value adapters in step after a
  /// cached account is restored.
  Future<Map<String, String>> activeFamilyKv() async {
    final rows = await raw.query('kv');
    return {
      for (final row in rows)
        if (_isFamilyKv(row['k']?.toString() ?? ''))
          row['k']!.toString(): row['v']!.toString(),
    };
  }

  static Future<void> createSchema(Database d) async {
    for (final sql in schema) {
      await d.execute(sql);
    }
  }

  /// Migrations. ALTERs are guarded - re-running is safe.
  /// v2: sync columns + outbox · v3: recurring rules · v4: checkout guard ·
  /// v5: shopping-list header table + item tombstones · v7: per-user cache
  /// · v8: cycle plans · v9: activity · v10: shopping
  /// · v11: contributions · v12: debts · v13: receipts/splits
  /// · v14: recurring bill payment links.
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
          // column/index already exists - fine.
        }
      }
    }
    if (oldVersion < 4) {
      try {
        await d.execute(
          'ALTER TABLE list_item ADD COLUMN checked_out INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {
        // Column already exists - fine.
      }
    }
    if (oldVersion < 5) {
      try {
        await d.execute('ALTER TABLE list_item ADD COLUMN deleted_at TEXT');
      } catch (_) {
        // Column already exists - fine.
      }
    }
    if (oldVersion < 6) {
      for (final sql in const [
        'ALTER TABLE envelope ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0',
        'ALTER TABLE tx ADD COLUMN deleted_at TEXT',
        "ALTER TABLE goal ADD COLUMN status TEXT NOT NULL DEFAULT 'active'",
        'ALTER TABLE recurring ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0',
        'ALTER TABLE chore ADD COLUMN assignee_member_id TEXT',
        'ALTER TABLE chore ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0',
      ]) {
        try {
          await d.execute(sql);
        } catch (_) {
          // Column already exists.
        }
      }
    }
    if (oldVersion < 10) {
      for (final sql in const [
        'ALTER TABLE list_item ADD COLUMN assigned_to_id TEXT',
        'ALTER TABLE list_item ADD COLUMN actual_minor INTEGER',
        'ALTER TABLE list_item ADD COLUMN actual_currency TEXT',
        'ALTER TABLE list_item ADD COLUMN purchased_by_id TEXT',
      ]) {
        try {
          await d.execute(sql);
        } catch (_) {
          // Column already exists.
        }
      }
    }
    if (oldVersion < 13) {
      try {
        await d.execute('ALTER TABLE tx ADD COLUMN receipt_uri TEXT');
      } catch (_) {}
    }
    if (oldVersion < 14) {
      try {
        await d.execute('ALTER TABLE tx ADD COLUMN recurring_rule_id TEXT');
      } catch (_) {}
    }
    await createSchema(d); // shopping_list & others are CREATE IF NOT EXISTS
  }
}
