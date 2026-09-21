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
    return [
      for (final r in rows)
        OutboxOp(
          rowId: r['id'] as int,
          entity: r['entity'] as String,
          opId: r['op_id'] as String,
          attempts: (r['attempts'] as int?) ?? 0,
          payload: jsonDecode(r['payload'] as String) as Map<String, Object?>,
        ),
    ];
  }

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

  const OutboxOp({
    required this.rowId,
    required this.entity,
    required this.opId,
    this.attempts = 0,
    required this.payload,
  });
}
