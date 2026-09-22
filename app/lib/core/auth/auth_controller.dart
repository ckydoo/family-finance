import 'package:flutter/foundation.dart';

import '../config/app_env.dart';
import 'auth_service.dart';
import 'supabase_auth_service.dart';

/// Owns the auth session for the app shell. The login screen talks to this;
/// app.dart listens to it and swaps between LoginScreen and the role shells.
/// Sessions are real Supabase GoTrue sessions (email + password); tests may
/// inject a fake [AuthService].
class AuthController extends ChangeNotifier {
  final KvGetter? _kvGet;
  final KvSetter? _kvSet;

  AuthController({
    required this.env,
    AuthService? service,
    KvGetter? kvGet,
    KvSetter? kvSet,
  })  : _kvGet = kvGet,
        _kvSet = kvSet,
        _service = service ??
            SupabaseAuthService(
              baseUrl: env.supabaseUrl!,
              anonKey: env.supabaseAnonKey!,
              kvGet: kvGet,
              kvSet: kvSet,
            );

  final AppEnv env;
  final AuthService _service;

  AuthSession? _session;
  String? _lastError;
  String? _lastErrorCode;
  bool _needsConfirmation = false;
  bool _busy = false;

  AuthSession? get session => _session;
  bool get isLoggedIn => _session != null;
  String? get lastError => _lastError;

  /// Machine-readable reason for [lastError] (email_not_confirmed,
  /// invalid_credentials, already_registered, rate_limited, network…).
  String? get lastErrorCode => _lastErrorCode;

  /// True after a sign-up that requires email confirmation — the login screen
  /// shows "check your inbox" and returns to sign-in mode.
  bool get needsConfirmation => _needsConfirmation;
  bool get busy => _busy;

  /// Called once at startup: restores the stored session or null (login).
  Future<void> restore() async {
    _session = await _service.restoreSession();
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    _lastError = null;
    _lastErrorCode = null;
    _needsConfirmation = false;
    _busy = true;
    notifyListeners();
    final r = await _service.signIn(email, password);
    _busy = false;
    if (r.ok) {
      // The service cached the session while persisting its tokens — use it
      // directly. (Never fabricate one: a session without stored tokens sent
      // empty JWTs to the server.)
      _session = _service.session;
      if (_session == null) {
        _lastError = 'Sign-in could not be completed — try again.';
        notifyListeners();
        return false;
      }
    } else {
      _lastError = r.error;
      _lastErrorCode = r.code;
    }
    notifyListeners();
    return r.ok;
  }

  Future<bool> signUp(String email, String password) async {
    _lastError = null;
    _lastErrorCode = null;
    _needsConfirmation = false;
    _busy = true;
    notifyListeners();
    final r = await _service.signUp(email, password);
    _busy = false;
    if (r.ok) {
      if (r.needsConfirmation) {
        // Account created; confirmation email sent. No session yet.
        _needsConfirmation = true;
        notifyListeners();
        return false;
      }
      _session = _service.session;
      if (_session == null) {
        _lastError = 'Account created but sign-in could not be completed — '
            'sign in with your new password.';
        notifyListeners();
        return false;
      }
    } else {
      _lastError = r.error;
      _lastErrorCode = r.code;
    }
    notifyListeners();
    return r.ok;
  }

  /// Re-sends the signup confirmation email (email-confirmation providers).
  Future<bool> resendConfirmation(String email) =>
      _service.resendConfirmation(email);

  /// Fresh access token for the sync layer (null when unrenewable).
  Future<String?> refreshAccessToken() => _service.refreshAccessToken();

  Future<void> signOut() async {
    await _service.signOut();
    _session = null;
    _lastError = null;
    _lastErrorCode = null;
    _needsConfirmation = false;
    notifyListeners();
  }

  Future<bool> deleteAccount() async {
    _lastError = null;
    _busy = true;
    notifyListeners();
    final result = await _service.deleteAccount();
    _busy = false;
    if (!result.ok) {
      _lastError = result.error;
      notifyListeners();
      return false;
    }
    _session = null;
    notifyListeners();
    return true;
  }
}
