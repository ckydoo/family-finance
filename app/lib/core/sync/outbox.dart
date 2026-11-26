import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'sync_mappers.dart' show pushOrderIndex;

/// The M3 outbox: every live-mode mutation lands here first (ordered,
/// idempotent), and the SyncEngine flushes it to Supabase. Survives restarts
/// and offline stretches; nothing is dropped on failure - attempts increment
/// and the next sync retries.
class Outbox {
  Outbox(this.db);

  final Database db;

  Future<void> enqueue(
    String entity,
    String opId,
    Map<String, Object?> payload, {
    Map<String, Object?>? basePayload,
    String? groupId,
  }) async {
    await db.insert(
      'outbox',
      {
        'entity': entity,
        'op_id': opId,
        'group_id': groupId,
        'payload': jsonEncode(payload),
        'base_payload': basePayload == null ? null : jsonEncode(basePayload),
        'created_ms': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Atomically enqueue related operations whose server rows must stay in
  /// step (for example, a debt repayment and its cash-ledger transaction).
  /// Operations within the batch are ordered topologically by FK dependency
  /// and stamped with a shared [groupId] for server-side savepoint atomicity.
  Future<void> enqueueBatch(
    List<
        ({
          String entity,
          String opId,
          Map<String, Object?> payload,
          Map<String, Object?>? basePayload,
        })> operations, {
    Future<void> Function(Transaction txn)? persist,
    String? groupId,
  }) async {
    if (operations.isEmpty) return;
    final ordered = List.of(operations)
      ..sort(
        (a, b) => pushOrderIndex(a.entity).compareTo(pushOrderIndex(b.entity)),
      );
    await db.transaction((txn) async {
      await persist?.call(txn);
      final createdAt = DateTime.now().millisecondsSinceEpoch;
      final sharedGroupId = operations.length > 1
          ? (groupId ?? 'grp_${createdAt}_${ordered.first.opId}')
          : groupId;
      for (final operation in ordered) {
        await txn.insert(
          'outbox',
          {
            'entity': operation.entity,
            'op_id': operation.opId,
            'group_id': sharedGroupId,
            'payload': jsonEncode(operation.payload),
            'base_payload': operation.basePayload == null
                ? null
                : jsonEncode(operation.basePayload),
            'created_ms': createdAt,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<int> count() async {
    final r = await db.rawQuery('SELECT COUNT(*) AS c FROM outbox');
    return Sqflite.firstIntValue(r) ?? 0;
  }

  /// Oldest-first batch. Order matters: same-row writes replay in order.
  Future<List<OutboxOp>> take(int limit) async {
    final rows = await db.query(
      'outbox',
      where: 'conflict_reason IS NULL',
      orderBy: 'id ASC',
      limit: limit,
    );
    return [for (final r in rows) _opFrom(r)];
  }

  /// Active unpushed row IDs grouped by entity so server pulls never clobber
  /// dirty local records before they push and merge.
  Future<Map<String, Set<String>>> dirtyIdsByEntity() async {
    final rows = await db.query(
      'outbox',
      columns: ['entity', 'payload'],
      where: 'conflict_reason IS NULL',
    );
    final out = <String, Set<String>>{};
    for (final row in rows) {
      final entity = row['entity']?.toString();
      final rawPayload = row['payload']?.toString();
      if (entity == null || rawPayload == null) continue;
      try {
        final decoded = jsonDecode(rawPayload);
        if (decoded is Map) {
          final id = decoded['id']?.toString();
          if (id != null && id.isNotEmpty) {
            out.putIfAbsent(entity, () => <String>{}).add(id);
          }
        }
      } catch (_) {}
    }
    return out;
  }

  Future<Set<String>> dirtyRowIdsForEntity(String entity) async {
    final rows = await db.query(
      'outbox',
      columns: ['payload'],
      where: 'entity = ? AND conflict_reason IS NULL',
      whereArgs: [entity],
    );
    final out = <String>{};
    for (final row in rows) {
      final rawPayload = row['payload']?.toString();
      if (rawPayload == null) continue;
      try {
        final decoded = jsonDecode(rawPayload);
        if (decoded is Map) {
          final id = decoded['id']?.toString();
          if (id != null && id.isNotEmpty) out.add(id);
        }
      } catch (_) {}
    }
    return out;
  }

  /// Rewrites queued outbox payloads that still reference a local [oldId]
  /// after natural-key deduplication adopted canonical server [newId].
  Future<void> rewriteEntityIdReferences(
    String entity,
    String oldId,
    String newId,
  ) async {
    if (oldId.isEmpty || newId.isEmpty || oldId == newId) return;
    final rows = await db.query('outbox');
    if (rows.isEmpty) return;

    await db.transaction((txn) async {
      for (final row in rows) {
        final rowId = row['id'] as int?;
        final rowEntity = row['entity']?.toString();
        final rawPayload = row['payload']?.toString();
        if (rowId == null || rawPayload == null || !rawPayload.contains(oldId)) {
          continue;
        }
        try {
          final decoded = jsonDecode(rawPayload);
          if (decoded is! Map) continue;
          final payload = <String, dynamic>{
            for (final entry in decoded.entries) '${entry.key}': entry.value,
          };
          var mutated = false;
          if (rowEntity == entity && payload['id'] == oldId) {
            payload['id'] = newId;
            mutated = true;
          }
          if (entity == 'envelope') {
            if (payload['envelope_id'] == oldId) {
              payload['envelope_id'] = newId;
              mutated = true;
            }
            if (payload['_envelope_id'] == oldId) {
              payload['_envelope_id'] = newId;
              mutated = true;
            }
            final allocations = payload['allocations'];
            if (allocations is Map && allocations.containsKey(oldId)) {
              final nextAlloc = <String, dynamic>{
                for (final entry in allocations.entries)
                  '${entry.key}': entry.value,
              };
              final oldVal = (nextAlloc.remove(oldId) as num?)?.toInt() ?? 0;
              nextAlloc[newId] =
                  ((nextAlloc[newId] as num?)?.toInt() ?? 0) + oldVal;
              payload['allocations'] = nextAlloc;
              mutated = true;
            }
          } else if (entity == 'commitment_occurrence') {
            if (payload['occurrence_id'] == oldId) {
              payload['occurrence_id'] = newId;
              mutated = true;
            }
          }
          if (mutated) {
            await txn.update(
              'outbox',
              {'payload': jsonEncode(payload)},
              where: 'id = ?',
              whereArgs: [rowId],
            );
          }
        } catch (_) {}
      }
    });
  }

  Future<List<OutboxOp>> conflicts() async {
    final rows = await db.query('outbox',
        where: 'conflict_reason IS NOT NULL', orderBy: 'id ASC');
    return [for (final row in rows) _opFrom(row)];
  }

  Future<int> countConflicts() async {
    final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM outbox WHERE conflict_reason IS NOT NULL');
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<void> markConflict(
          int rowId, String reason, Map<String, Object?> serverPayload) =>
      db.update(
        'outbox',
        {
          'conflict_reason': reason,
          'server_payload': jsonEncode(serverPayload)
        },
        where: 'id = ?',
        whereArgs: [rowId],
      );

  Future<void> clearConflict(int rowId) => db.update(
        'outbox',
        {
          'conflict_reason': null,
          'server_payload': null,
          'attempts': 0,
          'created_ms': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [rowId],
      );

  /// Rebase an explicitly approved local change onto the exact server version
  /// shown in conflict review. This keeps "use this device" intentional while
  /// preserving server-side compare-and-swap semantics on the retry.
  Future<void> rebaseConflict(int rowId, String serverUpdatedAt) async {
    final rows = await db.query(
      'outbox',
      columns: ['payload'],
      where: 'id = ?',
      whereArgs: [rowId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final payload =
        jsonDecode(rows.first['payload'] as String) as Map<String, dynamic>;
    payload['_base_updated_at'] = serverUpdatedAt;
    await db.update(
      'outbox',
      {
        'payload': jsonEncode(payload),
        'conflict_reason': null,
        'server_payload': null,
        'attempts': 0,
        'created_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [rowId],
    );
  }

  /// Repeatedly failing ops ([minAttempts] attempts or more), surfaced in
  /// Sync & data for visibility. They remain eligible for automatic retries.
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
        'SELECT COUNT(*) AS c FROM outbox WHERE attempts >= ?', [minAttempts]);
    return Sqflite.firstIntValue(r) ?? 0;
  }

  /// "Try again": clear the failure count so the next sync pushes it.
  Future<void> resetAttempts(int rowId) async =>
      db.update('outbox', {'attempts': 0}, where: 'id = ?', whereArgs: [rowId]);

  /// "Try again all": clear the failure count for all ops so the next sync pushes them.
  Future<void> resetAllAttempts() async => db.update('outbox', {'attempts': 0});

  /// Explicit user discard (confirmed in the UI) - the only way a row
  /// leaves the outbox besides a successful push.
  Future<void> deleteRow(int rowId) async =>
      db.delete('outbox', where: 'id = ?', whereArgs: [rowId]);

  OutboxOp _opFrom(Map<String, Object?> r) => OutboxOp(
        rowId: r['id'] as int,
        entity: r['entity'] as String,
        opId: r['op_id'] as String,
        groupId: r['group_id'] as String?,
        attempts: (r['attempts'] as int?) ?? 0,
        createdMs: (r['created_ms'] as int?) ?? 0,
        conflictReason: r['conflict_reason'] as String?,
        serverPayload: r['server_payload'] == null
            ? null
            : (jsonDecode(r['server_payload'] as String)
                as Map<String, dynamic>),
        basePayload: r['base_payload'] == null
            ? null
            : (jsonDecode(r['base_payload'] as String)
                as Map<String, dynamic>),
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
  final String? groupId;

  /// Failed-push count (M7: batches park after SyncEngine.maxAttempts).
  final int attempts;

  final Map<String, Object?> payload;

  /// When the change was made (epoch ms) - shown in the parked list.
  final int createdMs;
  final String? conflictReason;
  final Map<String, Object?>? serverPayload;

  /// The row as it was on the server when the edit started (the CAS base).
  /// Used by the server-authoritative merge to compute a deterministic
  /// field-level merge when the row changed underneath the client.
  final Map<String, Object?>? basePayload;

  const OutboxOp({
    required this.rowId,
    required this.entity,
    required this.opId,
    this.groupId,
    this.attempts = 0,
    this.createdMs = 0,
    this.conflictReason,
    this.serverPayload,
    this.basePayload,
    required this.payload,
  });
}
