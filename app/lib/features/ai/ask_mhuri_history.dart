import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/utils/ids.dart';

class AskMhuriConversation {
  const AskMhuriConversation({
    required this.id,
    required this.title,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  final String id;
  final String title;
  final int createdAtMs;
  final int updatedAtMs;

  factory AskMhuriConversation.fromRow(Map<String, Object?> row) =>
      AskMhuriConversation(
        id: row['id']! as String,
        title: row['title']! as String,
        createdAtMs: row['created_at_ms']! as int,
        updatedAtMs: row['updated_at_ms']! as int,
      );
}

class AskMhuriSavedMessage {
  const AskMhuriSavedMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAtMs,
    this.facts = const {},
  });

  final String id;
  final String role;
  final String content;
  final int createdAtMs;
  final Map<String, Object?> facts;

  factory AskMhuriSavedMessage.fromRow(Map<String, Object?> row) {
    Map<String, Object?> facts = const {};
    final encoded = row['facts_json'] as String?;
    if (encoded != null && encoded.isNotEmpty) {
      try {
        final decoded = jsonDecode(encoded);
        if (decoded is Map) facts = Map<String, Object?>.from(decoded);
      } catch (_) {
        // Keep the saved answer readable if an old facts payload is malformed.
      }
    }
    return AskMhuriSavedMessage(
      id: row['id']! as String,
      role: row['role']! as String,
      content: row['content']! as String,
      createdAtMs: row['created_at_ms']! as int,
      facts: facts,
    );
  }
}

/// Device-local Ask Mhuri history. Rows are scoped to both the signed-in user
/// and active family space and are never sent through family sync.
class AskMhuriHistoryStore {
  const AskMhuriHistoryStore(this._db);

  final Database _db;

  Future<List<AskMhuriConversation>> listConversations({
    required String userId,
    required String familyId,
  }) async {
    final rows = await _db.query(
      'ask_mhuri_conversation',
      where: 'user_id = ? AND family_id = ?',
      whereArgs: [userId, familyId],
      orderBy: 'updated_at_ms DESC, created_at_ms DESC',
    );
    return rows.map(AskMhuriConversation.fromRow).toList(growable: false);
  }

  Future<List<AskMhuriSavedMessage>> loadMessages({
    required String conversationId,
    required String userId,
    required String familyId,
  }) async {
    final rows = await _db.query(
      'ask_mhuri_message',
      where: 'conversation_id = ? AND user_id = ? AND family_id = ?',
      whereArgs: [conversationId, userId, familyId],
      orderBy: 'created_at_ms ASC, rowid ASC',
    );
    return rows.map(AskMhuriSavedMessage.fromRow).toList(growable: false);
  }

  Future<AskMhuriConversation> saveExchange({
    required String conversationId,
    required String userId,
    required String familyId,
    required String question,
    required String answer,
    required Map<String, Object?> facts,
    required int createdAtMs,
  }) async {
    final title = _title(question);
    late AskMhuriConversation saved;
    await _db.transaction((txn) async {
      final existing = await txn.query(
        'ask_mhuri_conversation',
        columns: ['id', 'title', 'created_at_ms'],
        where: 'id = ? AND user_id = ? AND family_id = ?',
        whereArgs: [conversationId, userId, familyId],
        limit: 1,
      );
      final createdAt = existing.isEmpty
          ? createdAtMs
          : existing.first['created_at_ms']! as int;
      final savedTitle =
          existing.isEmpty ? title : existing.first['title']! as String;
      saved = AskMhuriConversation(
        id: conversationId,
        title: savedTitle,
        createdAtMs: createdAt,
        updatedAtMs: createdAtMs,
      );
      await txn.insert(
        'ask_mhuri_conversation',
        {
          'id': conversationId,
          'user_id': userId,
          'family_id': familyId,
          'title': savedTitle,
          'created_at_ms': createdAt,
          'updated_at_ms': createdAtMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert('ask_mhuri_message', {
        'id': newUuid(),
        'conversation_id': conversationId,
        'user_id': userId,
        'family_id': familyId,
        'role': 'user',
        'content': question,
        'facts_json': null,
        'created_at_ms': createdAtMs,
      });
      await txn.insert('ask_mhuri_message', {
        'id': newUuid(),
        'conversation_id': conversationId,
        'user_id': userId,
        'family_id': familyId,
        'role': 'assistant',
        'content': answer,
        'facts_json': jsonEncode(facts),
        'created_at_ms': createdAtMs + 1,
      });
    });

    return saved;
  }

  Future<void> renameConversation({
    required String conversationId,
    required String userId,
    required String familyId,
    required String title,
  }) async {
    final normalized = _title(title);
    await _db.update(
      'ask_mhuri_conversation',
      {
        'title': normalized,
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch
      },
      where: 'id = ? AND user_id = ? AND family_id = ?',
      whereArgs: [conversationId, userId, familyId],
    );
  }

  Future<void> deleteConversation({
    required String conversationId,
    required String userId,
    required String familyId,
  }) async {
    await _db.transaction((txn) async {
      await txn.delete(
        'ask_mhuri_message',
        where: 'conversation_id = ? AND user_id = ? AND family_id = ?',
        whereArgs: [conversationId, userId, familyId],
      );
      await txn.delete(
        'ask_mhuri_conversation',
        where: 'id = ? AND user_id = ? AND family_id = ?',
        whereArgs: [conversationId, userId, familyId],
      );
    });
  }

  static String _title(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 52) {
      return normalized.isEmpty ? 'New chat' : normalized;
    }
    return '${normalized.substring(0, 49).trimRight()}…';
  }
}
