import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

/// Optional key-value hooks so the service can persist tokens without
/// depending on the database layer. Backed by the `kv` table on device,
/// in-memory maps in tests/demo.
typedef KvGetter = Future<String?> Function(String key);
typedef KvSetter = Future<void> Function(String key, String value);

/// Real phone-OTP auth against Supabase's GoTrue REST API — hand-written so
/// the app does not need the Supabase SDK. Only three stable endpoints are
/// used, and the HTTP client is injectable, so the whole flow is testable
/// offline (see test/auth_test.dart).
///
///   POST {base}/auth/v1/otp                       {phone}            → send code
///   POST {base}/auth/v1/verify                    {type,phone,token} → sign in
///   POST {base}/auth/v1/token?grant_type=refresh_token               → refresh
///   POST {base}/auth/v1/logout  (Authorization: Bearer)              → sign out
class SupabaseAuthService implements AuthService {
  SupabaseAuthService({
    required String baseUrl,
    required String anonKey,
    KvGetter? kvGet,
    KvSetter? kvSet,
    http.Client? client,
  })  : _base = baseUrl.replaceAll(RegExp(r'/+$'), ''),
        _anonKey = anonKey,
        _kvGet = kvGet,
        _kvSet = kvSet,
        _client = client ?? http.Client();

  final String _base;
  final String _anonKey;
  final KvGetter? _kvGet;
  final KvSetter? _kvSet;
  final http.Client _client;

  AuthSession? _session;

  Map<String, String> get _headers => {
        'apikey': _anonKey,
        'Content-Type': 'application/json',
      };

  @override
  Future<AuthResult> sendOtp(String phone) async {
    try {
      final r = await _client.post(
        Uri.parse('$_base/auth/v1/otp'),
        headers: _headers,
        body: jsonEncode({'phone': phone}),
      );
      if (r.statusCode >= 200 && r.statusCode < 300) {
        return const AuthResult.success();
      }
      return AuthResult.failure(_errorMessage(r));
    } catch (_) {
      return const AuthResult.failure(
          'Network error — check your connection and try again.');
    }
  }

  @override
  Future<AuthResult> verifyOtp(String phone, String code) async {
    try {
      final r = await _client.post(
        Uri.parse('$_base/auth/v1/verify'),
        headers: _headers,
        body: jsonEncode({
          'type': 'sms',
          'phone': phone,
          'token': code.trim(),
        }),
      );
      if (r.statusCode < 200 || r.statusCode >= 300) {
        return AuthResult.failure(_errorMessage(r));
      }
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final access = body['access_token'] as String?;
      final refresh = body['refresh_token'] as String?;
      final user = body['user'] as Map<String, dynamic>?;
      final userId = (user?['id'] ?? body['user_id'] ?? phone).toString();
      if (access == null || access.isEmpty) {
        return const AuthResult.failure('Sign-in failed — try again.');
      }
      _session = AuthSession(userId: userId, phone: phone);
      await _persistTokens(access: access, refresh: refresh, userId: userId, phone: phone);
      return const AuthResult.success();
    } catch (_) {
      return const AuthResult.failure(
          'Network error — check your connection and try again.');
    }
  }

  @override
  Future<AuthSession?> restoreSession() async {
    final get = _kvGet;
    if (get == null) return _session;
    final refresh = await get('auth_refresh_token');
    final access = await get('auth_access_token');
    final userId = await get('auth_user_id');
    final phone = await get('auth_phone');

    // No stored session → login screen.
    if ((refresh == null || refresh.isEmpty) &&
        (access == null || access.isEmpty)) {
      return _session;
    }

    // Try to refresh; if the refresh token is dead, clear and show login.
    try {
      final r = await _client.post(
        Uri.parse('$_base/auth/v1/token?grant_type=refresh_token'),
        headers: _headers,
        body: jsonEncode({'refresh_token': refresh}),
      );
      if (r.statusCode >= 200 && r.statusCode < 300) {
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        final newAccess = body['access_token'] as String?;
        final newRefresh = body['refresh_token'] as String? ?? refresh;
        if (newAccess != null && newAccess.isNotEmpty) {
          final uid = userId ?? 'user';
          final ph = phone ?? '';
          _session = AuthSession(userId: uid, phone: ph);
          await _persistTokens(
              access: newAccess, refresh: newRefresh, userId: uid, phone: ph);
          return _session;
        }
      }
      await _clearTokens();
      return _session;
    } catch (_) {
      // Offline at startup with a stored session: trust it for now; the sync
      // layer (M3) handles 401s by re-refreshing.
      if (access != null && access.isNotEmpty) {
        _session ??= AuthSession(userId: userId ?? 'user', phone: phone ?? '');
        return _session;
      }
      return _session;
    }
  }

  @override
  Future<void> signOut() async {
    final access = await _kvGet?.call('auth_access_token');
    try {
      if (access != null && access.isNotEmpty) {
        await _client.post(
          Uri.parse('$_base/auth/v1/logout?scope=global'),
          headers: {..._headers, 'Authorization': 'Bearer $access'},
        );
      }
    } catch (_) {
      // Best effort — local sign-out always succeeds.
    }
    _session = null;
    await _clearTokens();
  }

  Future<void> _persistTokens({
    required String access,
    required String? refresh,
    required String userId,
    required String phone,
  }) async {
    final set = _kvSet;
    if (set == null) return;
    await set('auth_access_token', access);
    if (refresh != null) await set('auth_refresh_token', refresh);
    await set('auth_user_id', userId);
    await set('auth_phone', phone);
  }

  Future<void> _clearTokens() async {
    final set = _kvSet;
    if (set == null) return;
    await set('auth_access_token', '');
    await set('auth_refresh_token', '');
  }

  String _errorMessage(http.Response r) {
    try {
      final body = jsonDecode(r.body);
      if (body is Map<String, dynamic>) {
        final msg = body['msg'] ??
            body['error_description'] ??
            body['message'] ??
            body['error'];
        if (msg is String && msg.isNotEmpty) return msg;
      }
    } catch (_) {}
    return 'Sign-in failed (HTTP ${r.statusCode}).';
  }
}
