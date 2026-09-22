import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

/// Optional key-value hooks so the service can persist tokens without
/// depending on the database layer. Backed by the `kv` table on device,
/// in-memory maps in tests/demo.
typedef KvGetter = Future<String?> Function(String key);
typedef KvSetter = Future<void> Function(String key, String value);

/// Real email+password auth against Supabase's GoTrue REST API — hand-written
/// so the app does not need the Supabase SDK. Only four stable endpoints are
/// used, and the HTTP client is injectable, so the whole flow is testable
/// offline (see test/auth_test.dart).
///
///   POST {base}/auth/v1/token?grant_type=password  {email,password} → sign in
///   POST {base}/auth/v1/signup                     {email,password} → create
///     (returns a session when email confirmation is OFF; only a user object
///      when confirmation is ON → [AuthResult.confirmationNeeded])
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
  Future<AuthResult> signIn(String email, String password) async {
    try {
      final r = await _client.post(
        Uri.parse('$_base/auth/v1/token?grant_type=password'),
        headers: _headers,
        body: jsonEncode({'email': email, 'password': password}),
      );
      if (r.statusCode < 200 || r.statusCode >= 300) {
        return AuthResult.failure(_errorMessage(r));
      }
      final session = _sessionFrom(r.body);
      if (session == null) {
        return const AuthResult.failure('Sign-in failed — try again.');
      }
      return AuthResult.success();
    } catch (_) {
      return const AuthResult.failure(
          'Network error — check your connection and try again.');
    }
  }

  @override
  Future<AuthResult> signUp(String email, String password) async {
    try {
      final r = await _client.post(
        Uri.parse('$_base/auth/v1/signup'),
        headers: _headers,
        body: jsonEncode({'email': email, 'password': password}),
      );
      if (r.statusCode < 200 || r.statusCode >= 300) {
        return AuthResult.failure(_errorMessage(r));
      }
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      if (body['access_token'] is String &&
          (body['access_token'] as String).isNotEmpty) {
        _sessionFrom(r.body);
        return const AuthResult.success();
      }
      // Sessionless 200 = "Confirm email" is enabled: account exists, but the
      // user must click the link in their inbox before signing in.
      if (body['user'] != null) {
        return const AuthResult.confirmationNeeded();
      }
      return const AuthResult.failure('Sign-up failed — try again.');
    } catch (_) {
      return const AuthResult.failure(
          'Network error — check your connection and try again.');
    }
  }

  /// Parses tokens out of a GoTrue response body, caches the session and
  /// persists it. Returns the session, or null when the body has no tokens.
  AuthSession? _sessionFrom(String body) {
    final map = jsonDecode(body) as Map<String, dynamic>;
    final access = map['access_token'] as String?;
    final refresh = map['refresh_token'] as String?;
    final user = map['user'] as Map<String, dynamic>?;
    final userId = (user?['id'] ?? map['user_id']).toString();
    final email =
        (user?['email'] ?? map['email'] ?? '').toString();
    if (access == null || access.isEmpty) return null;
    _session = AuthSession(userId: userId, email: email);
    _persistTokens(
        access: access, refresh: refresh, userId: userId, email: email);
    return _session;
  }

  @override
  Future<AuthSession?> restoreSession() async {
    final get = _kvGet;
    if (get == null) return _session;
    final refresh = await get('auth_refresh_token');
    final access = await get('auth_access_token');
    final userId = await get('auth_user_id');
    final email = await get('auth_email');

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
          final em = email ?? '';
          _session = AuthSession(userId: uid, email: em);
          await _persistTokens(
              access: newAccess, refresh: newRefresh, userId: uid, email: em);
          return _session;
        }
      }
      await _clearTokens();
      return _session;
    } catch (_) {
      // Offline at startup with a stored session: trust it for now; the sync
      // layer (M3) handles 401s by re-refreshing.
      if (access != null && access.isNotEmpty) {
        _session ??= AuthSession(userId: userId ?? 'user', email: email ?? '');
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

  @override
  Future<AuthResult> deleteAccount() async {
    final access = await _kvGet?.call('auth_access_token');
    if (access == null || access.isEmpty) {
      return const AuthResult.failure(
          'Your session has expired. Sign in again.');
    }
    try {
      final response = await _client.post(
        Uri.parse('$_base/rest/v1/rpc/delete_own_account'),
        headers: {..._headers, 'Authorization': 'Bearer $access'},
        body: '{}',
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AuthResult.failure(_errorMessage(response));
      }
      _session = null;
      await _clearTokens();
      return const AuthResult.success();
    } catch (_) {
      return const AuthResult.failure(
          'Network error — check your connection and try again.');
    }
  }

  Future<void> _persistTokens({
    required String access,
    required String? refresh,
    required String userId,
    required String email,
  }) async {
    final set = _kvSet;
    if (set == null) return;
    await set('auth_access_token', access);
    if (refresh != null) await set('auth_refresh_token', refresh);
    await set('auth_user_id', userId);
    await set('auth_email', email);
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
