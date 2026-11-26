import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Returns true when [uri] points to a remote Supabase Storage URL rather than
/// a device-local file path.
bool isRemoteReceiptUri(String? uri) {
  if (uri == null || uri.trim().isEmpty) return false;
  final trimmed = uri.trim();
  return trimmed.startsWith('https://') || trimmed.startsWith('http://');
}

/// Extracts a normalized image extension (`jpg`, `png`, or `webp`) from a
/// file path or URL, defaulting safely to `jpg`.
String receiptExtensionOf(String pathOrUrl) {
  final stripped = pathOrUrl.split('?').first.split('#').first.trim();
  final dot = stripped.lastIndexOf('.');
  if (dot < 0 || dot == stripped.length - 1) return 'jpg';
  final ext = stripped.substring(dot + 1).toLowerCase();
  return switch (ext) {
    'png' => 'png',
    'webp' => 'webp',
    'jpeg' || 'jpg' => 'jpg',
    _ => 'jpg',
  };
}

/// Validates that [rawUrl] belongs to the configured [supabaseUrl] origin and
/// rewrites any `/public/` or unprefixed bucket path to the `/authenticated/`
/// endpoint so JWT-authenticated Storage RLS policies always apply.
String? normalizeAuthenticatedReceiptUrl({
  required String? supabaseUrl,
  required String? rawUrl,
}) {
  final base = Uri.tryParse((supabaseUrl ?? '').trim());
  final target = Uri.tryParse((rawUrl ?? '').trim());
  if (base == null ||
      !base.hasAuthority ||
      target == null ||
      !target.hasAuthority ||
      target.origin != base.origin) {
    return null;
  }
  var path = target.path;
  if (path.startsWith('/storage/v1/object/public/receipts/')) {
    path = path.replaceFirst(
      '/storage/v1/object/public/receipts/',
      '/storage/v1/object/authenticated/receipts/',
    );
  } else if (path.startsWith('/storage/v1/object/receipts/')) {
    path = path.replaceFirst(
      '/storage/v1/object/receipts/',
      '/storage/v1/object/authenticated/receipts/',
    );
  }
  if (!path.startsWith('/storage/v1/object/authenticated/receipts/')) {
    return null;
  }
  return target.replace(path: path).toString();
}

/// Offline-first upload, authenticated download, and persistent local disk
/// cache for private `receipts` Supabase Storage objects.
class ReceiptStorageService {
  ReceiptStorageService({
    required String baseUrl,
    required String anonKey,
    required Future<String?> Function() tokenGet,
    http.Client? client,
    Future<Directory?> Function()? cacheDirectoryProvider,
  })  : _base = baseUrl.replaceAll(RegExp(r'/+$'), ''),
        _anonKey = anonKey,
        _tokenGet = tokenGet,
        _ownsClient = client == null,
        _client = client ?? http.Client(),
        _cacheDirProvider = cacheDirectoryProvider ?? _defaultReceiptsDir;

  final String _base;
  final String _anonKey;
  final Future<String?> Function() _tokenGet;
  final bool _ownsClient;
  final http.Client _client;
  final Future<Directory?> Function() _cacheDirProvider;

  void close() {
    if (_ownsClient) _client.close();
  }

  static Future<Directory?> _defaultReceiptsDir() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/receipts');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } catch (_) {
      return null;
    }
  }

  /// Copies a camera/gallery image into a persistent local staging directory so
  /// OS temp-cache eviction cannot delete an offline receipt before upload.
  /// Falls back to [fallbackPath] in headless test environments.
  static Future<String> stageLocalReceipt({
    required Uint8List bytes,
    required String fallbackPath,
    Directory? overrideDir,
  }) async {
    if (bytes.isEmpty) return fallbackPath;
    try {
      final dir = overrideDir ?? await _defaultReceiptsDir();
      if (dir == null) return fallbackPath;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final ext = receiptExtensionOf(fallbackPath);
      final digest = sha256.convert(bytes).toString().substring(0, 16);
      final staged = File(
        '${dir.path}/staged_${DateTime.now().millisecondsSinceEpoch}_$digest.$ext',
      );
      await staged.writeAsBytes(bytes, flush: true);
      return staged.path;
    } catch (_) {
      return fallbackPath;
    }
  }

  Future<File?> _cacheFileForUrl(String normalizedUrl) async {
    try {
      final dir = await _cacheDirProvider();
      if (dir == null) return null;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final ext = receiptExtensionOf(normalizedUrl);
      final hash = sha256.convert(utf8.encode(normalizedUrl)).toString();
      return File('${dir.path}/cache_$hash.$ext');
    } catch (_) {
      return null;
    }
  }

  /// Uploads receipt [bytes] to the private `receipts` bucket using an
  /// idempotent `x-upsert: true` write and caches the bytes locally under the
  /// resulting authenticated URL so this device never re-downloads its own
  /// receipt.
  Future<String> upload({
    required Uint8List bytes,
    required String spaceId,
    required String txId,
    required String extension,
    String? privateOwnerUserId,
  }) async {
    if (bytes.isEmpty) {
      throw const ReceiptStorageException('The receipt image is empty.');
    }
    final token = await _tokenGet();
    if (token == null || token.isEmpty) {
      throw const ReceiptStorageException(
        'Your session expired. Sign in again.',
      );
    }
    final ext = receiptExtensionOf('file.$extension');
    final contentType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    final owner = privateOwnerUserId?.trim();
    final objectPath = (owner != null && owner.isNotEmpty)
        ? '$spaceId/private/$owner/$txId.$ext'
        : '$spaceId/shared/$txId.$ext';

    final response = await _client
        .post(
          Uri.parse('$_base/storage/v1/object/receipts/$objectPath'),
          headers: {
            'apikey': _anonKey,
            'Authorization': 'Bearer $token',
            'Content-Type': contentType,
            'x-upsert': 'true',
          },
          body: bytes,
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ReceiptStorageException(
        'Could not upload receipt (${response.statusCode}).',
      );
    }

    final authUrl =
        '$_base/storage/v1/object/authenticated/receipts/$objectPath';
    final cacheFile = await _cacheFileForUrl(authUrl);
    if (cacheFile != null) {
      try {
        await cacheFile.writeAsBytes(bytes, flush: true);
      } catch (_) {
        // Non-fatal cache write failure.
      }
    }
    return authUrl;
  }

  /// Loads receipt image bytes from a local path, the persistent offline disk
  /// cache, or the authenticated `receipts` Storage endpoint.
  Future<Uint8List> loadBytes(String receiptUri) async {
    final trimmed = receiptUri.trim();
    if (trimmed.isEmpty) {
      throw const ReceiptStorageException('No receipt attached.');
    }
    if (!isRemoteReceiptUri(trimmed)) {
      final localFile = File(trimmed);
      if (!await localFile.exists()) {
        throw const ReceiptStorageException(
          'This receipt was saved only on another device or is no longer on disk.',
        );
      }
      final bytes = await localFile.readAsBytes();
      if (bytes.isEmpty) {
        throw const ReceiptStorageException('The receipt file is empty.');
      }
      return bytes;
    }

    final normalized = normalizeAuthenticatedReceiptUrl(
      supabaseUrl: _base,
      rawUrl: trimmed,
    );
    if (normalized == null) {
      throw const ReceiptStorageException('Invalid receipt storage URL.');
    }

    final cacheFile = await _cacheFileForUrl(normalized);
    if (cacheFile != null && await cacheFile.exists()) {
      final cached = await cacheFile.readAsBytes();
      if (cached.isNotEmpty) return cached;
    }

    final token = await _tokenGet();
    if (token == null || token.isEmpty) {
      throw const ReceiptStorageException(
        'Sign in again to download this receipt photo.',
      );
    }

    final response = await _client
        .get(
          Uri.parse(normalized),
          headers: {
            'apikey': _anonKey,
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        response.bodyBytes.isEmpty) {
      throw ReceiptStorageException(
        'Could not load receipt photo (${response.statusCode}).',
      );
    }

    if (cacheFile != null) {
      try {
        await cacheFile.writeAsBytes(response.bodyBytes, flush: true);
      } catch (_) {
        // Non-fatal cache write failure.
      }
    }
    return response.bodyBytes;
  }
}

class ReceiptStorageException implements Exception {
  const ReceiptStorageException(this.message);
  final String message;

  @override
  String toString() => message;
}
