/// Auth models + service interface + demo implementation (M2 → email auth).
///
/// Identity stays separate from family data: a session proves who you are
/// (M3 attaches family spaces server-side). Email + password via Supabase
/// GoTrue; demo mode uses the same shape with no network.
library;

class AuthSession {
  final String userId;
  final String email;

  const AuthSession({required this.userId, required this.email});
}

class AuthResult {
  final bool ok;
  final String? error;

  /// True when the account was created but the provider requires email
  /// confirmation before a session is issued (Supabase default). The UI
  /// shows "check your inbox" and switches to sign-in mode.
  final bool needsConfirmation;

  const AuthResult._(this.ok, this.error, {this.needsConfirmation = false});

  const AuthResult.success() : this._(true, null);

  const AuthResult.confirmationNeeded() : this._(true, null, needsConfirmation: true);

  const AuthResult.failure(String message) : this._(false, message);
}

/// One interface, two implementations:
///  * [DemoAuthService] — deterministic offline flow (any email + 6-char
///    password, no confirmation step).
///  * `SupabaseAuthService` — real email+password over GoTrue REST (see
///    supabase_auth_service.dart).
abstract class AuthService {
  Future<AuthResult> signIn(String email, String password);

  Future<AuthResult> signUp(String email, String password);

  /// Returns a saved session at startup, or null (show login).
  Future<AuthSession?> restoreSession();

  Future<void> signOut();

  /// Permanently deletes the authenticated account and its server identity.
  Future<AuthResult> deleteAccount();
}

/// Offline/demo auth: any well-formed email + password of 6+ characters.
/// Exists so the login screen and AuthController are exercised identically
/// in tests and demo builds without any network.
class DemoAuthService implements AuthService {
  AuthSession? _session;

  bool _valid(String email, String password) =>
      email.contains('@') && email.contains('.') && password.length >= 6;

  @override
  Future<AuthResult> signIn(String email, String password) async {
    if (!_valid(email, password)) {
      return const AuthResult.failure(
          'Enter a valid email and a password of at least 6 characters.');
    }
    _session = AuthSession(userId: 'demo_user', email: email);
    return const AuthResult.success();
  }

  @override
  Future<AuthResult> signUp(String email, String password) async =>
      signIn(email, password);

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
