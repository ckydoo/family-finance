import 'package:flutter/foundation.dart';

import '../config/app_env.dart';
import 'auth_service.dart';
import 'supabase_auth_service.dart';

/// Owns the auth session for the app shell. The login screen talks to this;
/// app.dart listens to it and swaps between LoginScreen and the role shells.
///
/// Live mode → SupabaseAuthService (real OTP). Demo mode → DemoAuthService
/// (only used if a test or demo build shows the gate — normally demo never
/// shows login at all).
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
  bool _busy = false;

  AuthSession? get session => _session;
  bool get isLoggedIn => _session != null;
  String? get lastError => _lastError;
  bool get busy => _busy;

  /// Called once at startup: restores a stored session or null. In demo
  /// mode the session is a kv marker so the login gate shows on first run
  /// only — after verifying once, launches go straight in.
  Future<void> restore() async {
    if (!env.isLive) {
      final p = await _kvGet?.call('demo_auth') ?? '';
      if (p.isNotEmpty) {
        _session = AuthSession(userId: 'demo_user', phone: p);
      }
      notifyListeners();
      return;
    }
    _session = await _service.restoreSession();
    notifyListeners();
  }

  Future<bool> sendCode(String phone) async {
    _lastError = null;
    _busy = true;
    notifyListeners();
    final r = await _service.sendOtp(phone);
    _busy = false;
    if (!r.ok) _lastError = r.error;
    notifyListeners();
    return r.ok;
  }

  Future<bool> verify(String phone, String code) async {
    _lastError = null;
    _busy = true;
    notifyListeners();
    final r = await _service.verifyOtp(phone, code);
    _busy = false;
    if (r.ok) {
      _session = await _service.restoreSession();
      if (_session == null) {
        _session = AuthSession(userId: 'user', phone: phone);
      }
      if (!env.isLive) await _kvSet?.call('demo_auth', phone);
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
    notifyListeners();
  }
}
