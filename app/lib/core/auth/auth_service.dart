/// Auth models + service interface + demo implementation (M2).
///
/// M2 keeps identity separate from family data: a session proves who you are
/// (M3 attaches family spaces server-side). Demo mode never shows login.
library;

class AuthSession {
  final String userId;
  final String phone;

  const AuthSession({required this.userId, required this.phone});
}

class AuthResult {
  final bool ok;
  final String? error;

  const AuthResult._(this.ok, this.error);

  const AuthResult.success() : this._(true, null);

  const AuthResult.failure(String message) : this._(false, message);
}

/// One interface, two implementations:
///  * [DemoAuthService] — deterministic offline flow (code `1234`).
///  * `SupabaseAuthService` — real phone OTP over GoTrue REST (see
///    supabase_auth_service.dart).
abstract class AuthService {
  Future<AuthResult> sendOtp(String phone);

  Future<AuthResult> verifyOtp(String phone, String code);

  /// Returns a saved session at startup, or null (show login).
  Future<AuthSession?> restoreSession();

  Future<void> signOut();

  /// Permanently deletes the authenticated account and its server identity.
  Future<AuthResult> deleteAccount();
}

/// Offline/demo auth: any phone + code `1234`. Exists so the login screen and
/// AuthController are exercised identically in tests and demo builds without
/// any network.
class DemoAuthService implements AuthService {
  static const demoCode = '1234';

  AuthSession? _session;

  @override
  Future<AuthResult> sendOtp(String phone) async => const AuthResult.success();

  @override
  Future<AuthResult> verifyOtp(String phone, String code) async {
    if (code.trim() == demoCode) {
      _session = AuthSession(userId: 'demo_user', phone: phone);
      return const AuthResult.success();
    }
    return const AuthResult.failure('Wrong code — demo code is 1234.');
  }

  @override
  Future<AuthSession?> restoreSession() async => _session;

  @override
  Future<void> signOut() async {
    _session = null;
  }

  @override
  Future<AuthResult> deleteAccount() async {
    _session = null;
    return const AuthResult.success();
  }
}
