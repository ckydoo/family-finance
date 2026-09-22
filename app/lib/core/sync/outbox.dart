import 'dart:convert';

import 'package:sqflite/sqflite.dart';

/// The M3 outbox: every live-mode mutation lands here first (ordered,
/// idempotent), and the SyncEngine flushes it to Supabase. Survives restarts
/// and offline stretches; nothing is dropped on failure — attempts increment
/// and the next sync retries.
class Outbox {
  Outbox(this.db);

  final Database db;

  Future<void> enqueue(String entity, String opId, Map<String, Object?> payload) async {
    await db.insert(
      'outbox',
      {
        'entity': entity,
        'op_id': opId,
        'payload': jsonEncode(payload),
        'created_ms': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> count() async {
    final r = await db.rawQuery('SELECT COUNT(*) AS c FROM outbox');
    return Sqflite.firstIntValue(r) ?? 0;
  }

  /// Oldest-first batch. Order matters: same-row writes replay in order.
  Future<List<OutboxOp>> take(int limit) async {
    final rows = await db.query(
      'outbox',
      orderBy: 'id ASC',
      limit: limit,
    );
    return [for (final r in rows) _opFrom(r)];
  }

  /// Held-back ops ([minAttempts] failed pushes or more) — surfaced in
  /// Sync & data with per-item retry/discard; never dropped silently.
  Future<List<OutboxOp>> parked(int minAttempts) async {
    final rows = await db.query(
      'outbox',
      where: 'attempts >= ?',
      whereArgs: [minAttempts],
      orderBy: 'id ASC',
    );
    return [for (final r in rows) _opFrom(r)];
  }

  Future<int> countParked(int minAttempts) async {
    final r = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM outbox WHERE attempts >= ?',
        [minAttempts]);
    return Sqflite.firstIntValue(r) ?? 0;
  }

  /// "Try again": clear the failure count so the next sync pushes it.
  Future<void> resetAttempts(int rowId) async =>
      db.update('outbox', {'attempts': 0},
          where: 'id = ?', whereArgs: [rowId]);

  /// Explicit user discard (confirmed in the UI) — the only way a row
  /// leaves the outbox besides a successful push.
  Future<void> deleteRow(int rowId) async =>
      db.delete('outbox', where: 'id = ?', whereArgs: [rowId]);

  OutboxOp _opFrom(Map<String, Object?> r) => OutboxOp(
        rowId: r['id'] as int,
        entity: r['entity'] as String,
        opId: r['op_id'] as String,
        attempts: (r['attempts'] as int?) ?? 0,
        createdMs: (r['created_ms'] as int?) ?? 0,
        payload: jsonDecode(r['payload'] as String) as Map<String, Object?>,
      );

  Future<void> deleteRows(List<int> rowIds) async {
    if (rowIds.isEmpty) return;
    await db.delete(
      'outbox',
      where: 'id IN (${List.filled(rowIds.length, '?').join(',')})',
      whereArgs: rowIds,
    );
  }

  Future<void> bumpAttempts(List<int> rowIds) async {
    if (rowIds.isEmpty) return;
    await db.execute(
      'UPDATE outbox SET attempts = attempts + 1 '
      'WHERE id IN (${List.filled(rowIds.length, '?').join(',')})',
      rowIds,
    );
  }

  Future<void> clear() async {
    await db.delete('outbox');
  }
}

class OutboxOp {
  final int rowId;
  final String entity;
  final String opId;

  /// Failed-push count (M7: batches park after SyncEngine.maxAttempts).
  final int attempts;

  final Map<String, Object?> payload;

  /// When the change was made (epoch ms) — shown in the parked list.
  final int createdMs;

  const OutboxOp({
    required this.rowId,
    required this.entity,
    required this.opId,
    this.attempts = 0,
    this.createdMs = 0,
    required this.payload,
  });
}
