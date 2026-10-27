import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class ChatMediaUploader {
  ChatMediaUploader({
    required String baseUrl,
    required String anonKey,
    required Future<String?> Function() tokenGet,
    http.Client? client,
  })  : _base = baseUrl.replaceAll(RegExp(r'/+$'), ''),
        _anonKey = anonKey,
        _tokenGet = tokenGet,
        _ownsClient = client == null,
        _client = client ?? http.Client();

  final String _base;
  final String _anonKey;
  final Future<String?> Function() _tokenGet;
  final bool _ownsClient;
  final http.Client _client;

  void close() {
    if (_ownsClient) _client.close();
  }

  Future<String> upload({
    required Uint8List bytes,
    required String spaceId,
    required String messageId,
    required String extension,
  }) async {
    if (bytes.isEmpty) throw const ChatMediaException('The attachment is empty.');
    final token = await _tokenGet();
    if (token == null || token.isEmpty) {
      throw const ChatMediaException('Your session expired. Sign in again.');
    }
    final ext = extension.toLowerCase();
    if (!const {'png', 'jpg', 'jpeg', 'm4a'}.contains(ext)) {
      throw const ChatMediaException(
        'This chat attachment type is not supported.',
      );
    }
    final path = '$spaceId/$messageId.$ext';
    final contentType = switch (ext) {
      'png' => 'image/png',
      'm4a' => 'audio/mp4',
      _ => 'image/jpeg',
    };
    final response = await _client
        .post(
          Uri.parse('$_base/storage/v1/object/chat-media/$path'),
          headers: {
            'apikey': _anonKey,
            'Authorization': 'Bearer $token',
            'Content-Type': contentType,
            'x-upsert': 'false',
          },
          body: bytes,
        )
        .timeout(const Duration(seconds: 60));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ChatMediaException(
        'Could not upload the attachment (${response.statusCode}).',
      );
    }
    // This is deliberately not a public URL. Reads must include the caller's
    // JWT so the storage.objects family-membership policy is enforced.
    return '$_base/storage/v1/object/authenticated/chat-media/$path';
  }
}

class ChatMediaException implements Exception {
  const ChatMediaException(this.message);
  final String message;

  @override
  String toString() => message;
}
