import 'dart:convert';

import 'package:http/http.dart' as http;

/// Thin Supabase REST (PostgREST) client for sync — hand-written, no SDK.
///
///  push:  POST /rest/v1/{table}?on_conflict=id
///         Prefer: resolution=merge-duplicates,return=minimal  (idempotent upsert)
///  pull:  GET  /rest/v1/{table}?select=*&order=updated_at.asc[&filters]
///  rpc:   POST /rest/v1/rpc/{fn}
///
/// The HTTP client is injectable so every flow is testable offline.
class SupabaseSyncClient {
  SupabaseSyncClient({
    required String baseUrl,
    required String anonKey,
    required Future<String?> Function() tokenGet,
    http.Client? client,
  })  : _base = baseUrl.replaceAll(RegExp(r'/+$'), ''),
        _anonKey = anonKey,
        _tokenGet = tokenGet,
        _client = client ?? http.Client();

  final String _base;
  final String _anonKey;
  final Future<String?> Function() _tokenGet;
  final http.Client _client;

  Future<Map<String, String>> _headers() async {
    final token = await _tokenGet();
    return {
      'apikey': _anonKey,
      'Authorization': 'Bearer ${token ?? ''}',
      'Content-Type': 'application/json',
    };
  }

  /// Idempotent upsert of a batch. Returns true on success.
  Future<bool> pushRows(String table, List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return true;
    final r = await _client.post(
      Uri.parse('$_base/rest/v1/$table?on_conflict=id'),
      headers: {
        ...(await _headers()),
        'Prefer': 'resolution=merge-duplicates,return=minimal',
      },
      body: jsonEncode(rows),
    );
    if (r.statusCode >= 200 && r.statusCode < 300) return true;
    throw SyncException(r.statusCode, _msg(r));
  }

  /// Pull rows changed after [sinceIso] (empty/null → everything RLS allows).
  Future<List<Map<String, Object?>>> pullRows(
    String table, {
    required String orderCol,
    String? sinceIso,
    String? spaceId,
    String? spaceCol,
    int limit = 500,
  }) async {
    var url = '$_base/rest/v1/$table'
        '?select=*'
        '&order=$orderCol.asc'
        '&limit=$limit';
    if (sinceIso != null && sinceIso.isNotEmpty) {
      url += '&$orderCol=gt.$sinceIso';
    }
    if (spaceCol != null && spaceId != null && spaceId.isNotEmpty) {
      url += '&$spaceCol=eq.$spaceId';
    }
    final r = await _client.get(Uri.parse(url), headers: await _headers());
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw SyncException(r.statusCode, _msg(r));
    }
    final decoded = jsonDecode(r.body);
    if (decoded is List) {
      return [for (final row in decoded) row as Map<String, Object?>];
    }
    return [];
  }

  /// Calls a SECURITY DEFINER RPC (create_space / join_space).
  Future<dynamic> rpc(String fn, Map<String, Object?> args) async {
    final r = await _client.post(
      Uri.parse('$_base/rest/v1/rpc/$fn'),
      headers: await _headers(),
      body: jsonEncode(args),
    );
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw SyncException(r.statusCode, _msg(r));
    }
    final body = r.body.isEmpty ? null : jsonDecode(r.body);
    return body;
  }

  String _msg(http.Response r) {
    try {
      final body = jsonDecode(r.body);
      if (body is Map<String, dynamic>) {
        final m = body['message'] ?? body['msg'] ?? body['error'];
        if (m is String && m.isNotEmpty) return m;
      }
    } catch (_) {}
    return 'HTTP ${r.statusCode}';
  }
}

class SyncException implements Exception {
  final int statusCode;
  final String message;

  const SyncException(this.statusCode, this.message);

  bool get isAuthError => statusCode == 401 || statusCode == 403;

  @override
  String toString() => 'SyncException($statusCode, $message)';
}
