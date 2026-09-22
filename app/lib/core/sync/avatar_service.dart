import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Uploads profile pictures to the Supabase `avatars` storage bucket
/// (migration 005): path `avatars/{userId}/avatar.{ext}`, public read,
/// owner-only write. Returns the public URL to store on user_profile.
class AvatarUploader {
  AvatarUploader({
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

  /// Uploads [bytes] and returns the public URL. Throws [AvatarException]
  /// with an actionable message on failure.
  Future<String> upload({
    required Uint8List bytes,
    required String userId,
    String ext = 'jpg',
  }) async {
    if (bytes.isEmpty) {
      throw const AvatarException('The picked photo is empty — try another.');
    }
    final token = await _tokenGet();
    if (token == null || token.isEmpty) {
      throw const AvatarException(
          'Your session has expired — sign in again.');
    }
    final r = await _client.post(
      Uri.parse('$_base/storage/v1/object/avatars/$userId/avatar.$ext'),
      headers: {
        'apikey': _anonKey,
        'Authorization': 'Bearer $token',
        'x-upsert': 'true',
        'Content-Type': ext == 'png' ? 'image/png' : 'image/jpeg',
      },
      body: bytes,
    );
    if (r.statusCode < 200 || r.statusCode >= 300) {
      if (r.statusCode == 401 || r.statusCode == 403) {
        throw const AvatarException(
            'Your session has expired — sign in again.');
      }
      throw AvatarException(
          'Could not upload the photo (${r.statusCode}) — check your '
          'connection and try again.');
    }
    return '$_base/storage/v1/object/public/avatars/$userId/avatar.$ext';
  }
}

class AvatarException implements Exception {
  const AvatarException(this.message);
  final String message;

  @override
  String toString() => message;
}
