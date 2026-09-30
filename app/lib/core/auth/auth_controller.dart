import 'package:flutter/foundation.dart';

import '../config/app_env.dart';
import 'auth_service.dart';
import 'supabase_auth_service.dart';

/// Owns the auth session for the app shell. The login screen talks to this;
/// app.dart listens to it and swaps between LoginScreen and the role shells.
/// Sessions are real Supabase GoTrue sessions (email + password); tests may
/// inject a fake [AuthService].
class AuthController extends ChangeNotifier {
  AuthController({
    required this.env,
    AuthService? service,
    KvGetter? kvGet,
    KvSetter? kvSet,
  }) : _service = service ??
            SupabaseAuthService(
              baseUrl: env.supabaseUrl ?? '',
              anonKey: env.supabaseAnonKey ?? '',
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

  /// True after a sign-up that requires email confirmation - the login screen
  /// shows "check your inbox" and returns to sign-in mode.
  bool get needsConfirmation => _needsConfirmation;
  bool get busy => _busy;

  /// Supabase's hosted OAuth entry point. The provider redirects back to the
  /// custom scheme registered by the Android and iOS runners.
  Uri get googleSignInUri => Uri.parse('${env.supabaseUrl}/auth/v1/authorize')
          .replace(queryParameters: const {
        'provider': 'google',
        'redirect_to': 'mhuri://auth-callback',
      });

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
      // The service cached the session while persisting its tokens - use it
      // directly. (Never fabricate one: a session without stored tokens sent
      // empty JWTs to the server.)
      _session = _service.session;
      if (_session == null) {
        _lastError = 'Sign-in could not be completed - try again.';
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
        _lastError = 'Account created but sign-in could not be completed - '
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

  Future<bool> sendPasswordReset(String email) =>
      _service.sendPasswordReset(email);

  /// Recovery step 2: with the session adopted from the reset link, set the
  /// new password (PUT /auth/v1/user).
  Future<AuthResult> updatePassword(String newPassword) =>
      _service.updatePassword(newPassword);

  /// Recovery step 1: the app opened the reset link - adopt the session it
  /// carries so the user can pick a new password. The controller mirrors the
  /// service session so the UI (and a mid-flow restart) knows we're signed
  /// in with a recovery session.
  Future<bool> adoptRecoverySession(
      String accessToken, String refreshToken) async {
    final ok = await _service.adoptRecoverySession(accessToken, refreshToken);
    if (ok) {
      _session = _service.session;
      notifyListeners();
    }
    return ok;
  }

  Future<bool> adoptOAuthSession(
      String accessToken, String refreshToken) async {
    _lastError = null;
    _lastErrorCode = null;
    _busy = true;
    notifyListeners();
    final ok = await _service.adoptOAuthSession(accessToken, refreshToken);
    _busy = false;
    if (ok) {
      _session = _service.session;
    } else {
      _lastError = 'Google sign-in could not be completed. Please try again.';
      _lastErrorCode = 'oauth_failed';
    }
    notifyListeners();
    return ok;
  }

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

  Future<bool> reauthenticate(String password) async {
    _lastError = null;
    _busy = true;
    notifyListeners();
    final ok = await _service.reauthenticate(password);
    _busy = false;
    if (!ok) {
      _lastError = 'Incorrect password.';
    }
    notifyListeners();
    return ok;
  }

  /// Called when the server revokes the user's session or token refresh fails (401).
  /// Clears the active session so the app routes to sign-in, while preserving
  /// local database and pending outbox changes for recovery upon re-authenticating.
  void handleForcedLogout({String? reason}) {
    _session = null;
    _lastError =
        reason ?? 'Your session expired or was revoked. Please sign in again.';
    _lastErrorCode = 'session_revoked';
    notifyListeners();
  }
}
