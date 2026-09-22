import 'package:mhuri_money/core/auth/auth_service.dart';
import 'package:mhuri_money/core/config/app_env.dart';

/// Deterministic AuthService double for tests. The one real implementation
/// is SupabaseAuthService (email + password over GoTrue); this mirrors its
/// contract without any network.
class FakeAuthService implements AuthService {
  AuthSession? _session;

  bool _valid(String email, String password) =>
      email.contains('@') && email.contains('.') && password.length >= 6;

  @override
  AuthSession? get session => _session;

  @override
  Future<String?> refreshAccessToken() async =>
      _session == null ? null : 'fake-access-token';

  @override
  Future<AuthResult> signIn(String email, String password) async {
    if (!_valid(email, password)) {
      return const AuthResult.failure(
          'Enter a valid email and a password of at least 6 characters.');
    }
    _session = const AuthSession(userId: 'test-user-1', email: email);
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

/// A configured (connected) env for tests — the only kind the app runs with.
AppEnv testEnv() => AppEnv.parse(
      'SUPABASE_URL=https://abcdefgh.supabase.co\n'
      'SUPABASE_ANON_KEY=test-key\n',
    );
