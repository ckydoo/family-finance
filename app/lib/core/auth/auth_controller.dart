import 'package:flutter/foundation.dart';

import '../config/app_env.dart';
import 'auth_service.dart';
import 'supabase_auth_service.dart';

/// Owns the auth session for the app shell. The login screen talks to this;
/// app.dart listens to it and swaps between LoginScreen and the role shells.
///
/// Live mode → SupabaseAuthService (email + password via GoTrue).
/// Demo mode → DemoAuthService (only used if a test or demo build shows the
/// gate — normally demo restores its kv session without the login screen).
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
            (env.isLive
                ? SupabaseAuthService(
                    baseUrl: env.supabaseUrl!,
                    anonKey: env.supabaseAnonKey!,
                    kvGet: kvGet,
                    kvSet: kvSet,
                  )
                : DemoAuthService());

  final AppEnv env;
  final AuthService _service;

  AuthSession? _session;
  String? _lastError;
  bool _needsConfirmation = false;
  bool _busy = false;

  AuthSession? get session => _session;
  bool get isLoggedIn => _session != null;
  String? get lastError => _lastError;

  /// True after a sign-up that requires email confirmation — the login screen
  /// shows "check your inbox" and returns to sign-in mode.
  bool get needsConfirmation => _needsConfirmation;
  bool get busy => _busy;

  /// Called once at startup: restores a stored session or null. In demo
  /// mode the session is a kv marker (the email) so the login gate shows on
  /// first run only — after verifying once, launches go straight in.
  Future<void> restore() async {
    if (!env.isLive) {
      final e = await _kvGet?.call('demo_auth') ?? '';
      if (e.isNotEmpty) {
        _session = AuthSession(userId: 'demo_user', email: e);
      }
      notifyListeners();
      return;
    }
    _session = await _service.restoreSession();
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    _lastError = null;
    _needsConfirmation = false;
    _busy = true;
    notifyListeners();
    final r = await _service.signIn(email, password);
    _busy = false;
    if (r.ok) {
      _session = await _service.restoreSession();
      _session ??= AuthSession(userId: 'user', email: email);
      if (!env.isLive) await _kvSet?.call('demo_auth', email);
    } else {
      _lastError = r.error;
    }
    notifyListeners();
    return r.ok;
  }

  Future<bool> signUp(String email, String password) async {
    _lastError = null;
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
      _session = await _service.restoreSession();
      _session ??= AuthSession(userId: 'user', email: email);
      if (!env.isLive) await _kvSet?.call('demo_auth', email);
    } else {
      _lastError = r.error;
    }
    notifyListeners();
    return r.ok;
  }

  Future<void> signOut() async {
    await _service.signOut();
    if (!env.isLive) await _kvSet?.call('demo_auth', '');
    _session = null;
    _lastError = null;
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
    if (!env.isLive) await _kvSet?.call('demo_auth', '');
    _session = null;
    notifyListeners();
    return true;
  }
}
