/// Auth models + service interface (M2 → email auth).
///
/// Identity stays separate from family data: a session proves who you are
/// (M3 attaches family spaces server-side). Email + password via Supabase
/// GoTrue (`SupabaseAuthService`).
library;

class AuthSession {
  final String userId;
  final String email;

  const AuthSession({required this.userId, required this.email});
}

class AuthResult {
  final bool ok;
  final String? error;

  /// Machine-readable failure reason so the UI can show targeted help and
  /// actions (resend confirmation, etc.) instead of a raw server string.
  /// One of: email_not_confirmed, invalid_credentials, already_registered,
  /// rate_limited, weak_password, network.
  final String? code;

  /// True when the account was created but the provider requires email
  /// confirmation before a session is issued (Supabase default). The UI
  /// shows "check your inbox" and switches to sign-in mode.
  final bool needsConfirmation;

  const AuthResult._(this.ok, this.error, {this.needsConfirmation = false, this.code});

  const AuthResult.success() : this._(true, null);

  const AuthResult.confirmationNeeded() : this._(true, null, needsConfirmation: true);

  const AuthResult.failure(String message, {String? code})
      : this._(false, message, code: code);
}

/// The one real implementation is `SupabaseAuthService`; this interface
/// exists so tests can inject a deterministic fake without any network.
abstract class AuthService {
  /// The session cached in memory (non-null right after a successful
  /// sign-in/sign-up, without touching the network).
  AuthSession? get session;

  Future<AuthResult> signIn(String email, String password);

  Future<AuthResult> signUp(String email, String password);

  /// Returns a saved session at startup, or null (show login).
  Future<AuthSession?> restoreSession();

  /// Re-sends the signup confirmation email (email-confirmation providers).
  Future<bool> resendConfirmation(String email);

  /// Best-effort fresh access token for the sync layer (null when the
  /// session cannot be renewed — the caller must treat the user as signed
  /// out rather than sending an empty credential).
  Future<String?> refreshAccessToken();

  Future<void> signOut();

  /// Permanently deletes the authenticated account and its server identity.
  Future<AuthResult> deleteAccount();
}
