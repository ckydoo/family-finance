import 'dart:convert';

/// The custom-scheme redirect URL the app registers (Android intent filter +
/// iOS URL scheme). Must be allow-listed in Supabase → Auth → URL
/// Configuration → Redirect URLs, or Supabase silently falls back to the
/// Site URL and the app never sees the tokens.
const String kRecoveryRedirect = 'mhuri://reset-callback';

/// What a clicked password-reset link turned out to be.
enum RecoveryKind {
  /// Implicit-flow redirect: fragment carries access_token + refresh_token.
  tokens,

  /// The link used the PKCE flow (?code=…) — we can't exchange it without
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

  const RecoveryLink._(this.kind, this.accessToken, this.refreshToken);

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
/// the URL fragment — the fragment never reaches a server, only the app.)
/// A `?code=` link means the project is on the PKCE flow, which a
/// hand-rolled client cannot exchange — reported as [RecoveryKind.code].
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
  if (access != null && access.isNotEmpty && refresh != null && refresh.isNotEmpty) {
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
/// regular URLs) — never throws.
String? parseInviteCode(String url) {
  if (url.isEmpty) return null;
  final Uri u;
  try {
    u = Uri.parse(url);
  } on FormatException {
    return null;
  }
  if (u.scheme.toLowerCase() != 'mhuri') return null;
  final host = u.host.toLowerCase();
  final path = u.path.toLowerCase();
  final isJoin = host == 'join' || path.contains('join');
  if (!isJoin) return null;
  final c = u.queryParameters['c'] ?? u.queryParameters['code'];
  if (c == null) return null;
  final trimmed = c.trim().toUpperCase();
  return RegExp(r'^MHRI-[A-Z0-9]{4,8}$').hasMatch(trimmed) ? trimmed : null;
}

/// Pulls `email` (and `sub`) out of a JWT access token without any server
/// call — the payload is plain base64url JSON. Returns null when the token
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
