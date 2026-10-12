import 'dart:convert';

/// The custom-scheme redirect URL the app registers (Android intent filter +
/// iOS URL scheme). Must be allow-listed in Supabase → Auth → URL
/// Configuration → Redirect URLs, or Supabase silently falls back to the
/// Site URL and the app never sees the tokens.
const String kRecoveryRedirect = 'mhuri://reset-callback';
const String kOAuthRedirect = 'mhuri://auth-callback';

enum OAuthCallbackKind { tokens, code, error, none }

class OAuthCallback {
  final OAuthCallbackKind kind;
  final String? accessToken;
  final String? refreshToken;
  final String? code;
  final String? error;

  const OAuthCallback._(
    this.kind, {
    this.accessToken,
    this.refreshToken,
    this.code,
    this.error,
  });

  const OAuthCallback.none() : this._(OAuthCallbackKind.none);
}

/// Parses both supported Supabase mobile OAuth returns: modern PKCE
/// `?code=...` callbacks and legacy implicit-flow token fragments. Provider
/// errors are retained so the login screen can explain the failure.
OAuthCallback parseOAuthCallback(String url) {
  if (url.isEmpty) return const OAuthCallback.none();
  final Uri uri;
  try {
    uri = Uri.parse(url);
  } on FormatException {
    return const OAuthCallback.none();
  }
  if (uri.scheme.toLowerCase() != 'mhuri' ||
      uri.host.toLowerCase() != 'auth-callback') {
    return const OAuthCallback.none();
  }
  final fragment = uri.fragment.isEmpty
      ? const <String, String>{}
      : Uri.splitQueryString(uri.fragment);
  final params = {...uri.queryParameters, ...fragment};
  final error = params['error_description'] ?? params['error'];
  if (error != null && error.isNotEmpty) {
    return OAuthCallback._(OAuthCallbackKind.error, error: error);
  }
  final code = params['code'];
  if (code != null && code.isNotEmpty) {
    return OAuthCallback._(OAuthCallbackKind.code, code: code);
  }
  final access = params['access_token'];
  final refresh = params['refresh_token'];
  if (access != null &&
      access.isNotEmpty &&
      refresh != null &&
      refresh.isNotEmpty) {
    return OAuthCallback._(
      OAuthCallbackKind.tokens,
      accessToken: access,
      refreshToken: refresh,
    );
  }
  return const OAuthCallback.none();
}

/// Android can also forward an OAuth failure through Flutter's route channel
/// as `/?error=...` after the custom-scheme intent has opened the activity.
/// This is not a trusted token callback, so only extract provider errors; token
/// and code handling remains restricted to [parseOAuthCallback].
String? parseOAuthRouteError(String routeName) {
  if (routeName.isEmpty || !routeName.startsWith('/?')) return null;
  final Uri uri;
  try {
    uri = Uri.parse(routeName);
  } on FormatException {
    return null;
  }
  final fragment = uri.fragment.isEmpty
      ? const <String, String>{}
      : Uri.splitQueryString(uri.fragment);
  final params = {...uri.queryParameters, ...fragment};
  final error = params['error_description'] ?? params['error'];
  return error == null || error.trim().isEmpty ? null : error.trim();
}

/// Tokens returned by Supabase after a successful social sign-in.
({String accessToken, String refreshToken})? parseOAuthLink(String url) {
  final callback = parseOAuthCallback(url);
  if (callback.kind != OAuthCallbackKind.tokens) return null;
  return (
    accessToken: callback.accessToken!,
    refreshToken: callback.refreshToken!,
  );
}

/// What a clicked password-reset link turned out to be.
enum RecoveryKind {
  /// Implicit-flow redirect: fragment carries access_token + refresh_token.
  tokens,

  /// The link used the PKCE flow (?code=…) - we can't exchange it without
  /// the original verifier. The user must request a fresh link.
  code,

  /// Not a reset link (another deep link or garbage).
  none,
}

/// Result of parsing a deep link that opened the app.
class RecoveryLink {
  final RecoveryKind kind;
  final String? accessToken;
  final String? refreshToken;

  const RecoveryLink.tokens(String access, String refresh)
      : kind = RecoveryKind.tokens,
        accessToken = access,
        refreshToken = refresh;
  const RecoveryLink.code()
      : kind = RecoveryKind.code,
        accessToken = null,
        refreshToken = null;
  const RecoveryLink.none()
      : kind = RecoveryKind.none,
        accessToken = null,
        refreshToken = null;

  bool get isRecovery => kind != RecoveryKind.none;
}

/// Recognises the Supabase recovery redirect:
///
///   mhuri://reset-callback#access_token=…&refresh_token=…&expires_in=…&type=recovery
///
/// (Supabase's /auth/v1/verify 302s to the redirect URL with the session in
/// the URL fragment - the fragment never reaches a server, only the app.)
/// A `?code=` link means the project is on the PKCE flow, which a
/// hand-rolled client cannot exchange - reported as [RecoveryKind.code].
RecoveryLink parseRecoveryLink(String url) {
  if (url.isEmpty) return const RecoveryLink.none();
  final Uri u;
  try {
    u = Uri.parse(url);
  } on FormatException {
    return const RecoveryLink.none();
  }

  // Only treat our own callback as a recovery entry point.
  final pathish = '${u.host}${u.path}'.toLowerCase();
  final looksOurs = u.scheme.toLowerCase() == 'mhuri' ||
      pathish.contains('reset-callback') ||
      pathish.contains('reset_password');
  if (!looksOurs) return const RecoveryLink.none();

  final frag = u.fragment;
  final fragParams = frag.isEmpty
      ? <MapEntry<String, String>>[]
      : Uri.splitQueryString(frag).entries.toList();
  String? access;
  String? refresh;
  for (final e in fragParams) {
    if (e.key == 'access_token') access = e.value;
    if (e.key == 'refresh_token') refresh = e.value;
  }
  if (access != null &&
      access.isNotEmpty &&
      refresh != null &&
      refresh.isNotEmpty) {
    return RecoveryLink.tokens(access, refresh);
  }
  if (u.queryParameters.containsKey('code')) return const RecoveryLink.code();
  return const RecoveryLink.none();
}

/// Extracts an invite code from a join deep link:
///
///   mhuri://join?c=MHRI-AB12CD
///
/// Returns null when the link is not an invite (QR scans of other content,
/// regular URLs) - never throws.
String? parseInviteCode(String url) {
  if (url.isEmpty) return null;
  final Uri u;
  try {
    u = Uri.parse(url);
  } on FormatException {
    return null;
  }
  final scheme = u.scheme.toLowerCase();
  final host = u.host.toLowerCase();
  final path = u.path.toLowerCase();
  final bool isJoin;
  if (scheme == 'mhuri') {
    isJoin = host == 'join' || path.contains('join');
  } else if (scheme == 'https' || scheme == 'http') {
    isJoin = host.contains('mhuri') &&
        (path.contains('join') || path.contains('invite'));
  } else {
    return null;
  }
  if (!isJoin) return null;
  final c = u.queryParameters['c'] ?? u.queryParameters['code'];
  if (c == null) return null;
  final trimmed = c.trim().toUpperCase();
  return RegExp(r'^MHRI-[A-Z0-9]{4,8}$').hasMatch(trimmed) ? trimmed : null;
}

/// Pulls `email` (and `sub`) out of a JWT access token without any server
/// call - the payload is plain base64url JSON. Returns null when the token
/// is malformed; never throws.
Map<String, String> claimsFromJwt(String jwt) {
  try {
    final parts = jwt.split('.');
    if (parts.length < 2) return const {};
    var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
    final pad = payload.length % 4;
    if (pad > 0) payload += '=' * (4 - pad);
    final decoded = jsonDecode(utf8.decode(base64.decode(payload)));
    if (decoded is! Map<String, dynamic>) return const {};
    return {
      for (final e in decoded.entries)
        if (e.value is String) e.key: e.value as String,
    };
  } catch (_) {
    return const {};
  }
}
