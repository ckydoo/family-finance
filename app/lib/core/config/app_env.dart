import 'package:flutter/services.dart' show rootBundle;

/// Server connection config (M2 → live-only).
///
/// The app is always a real client of the family's Supabase project —
/// config decides WHERE to connect, nothing else.
/// Sources, in precedence order:
///   1. `.env` bundled as a Flutter asset (see pubspec.yaml)
///   2. `--dart-define=MHURI_SUPABASE_URL=… MHURI_SUPABASE_ANON_KEY=…`
///      for CI/release builds that must not create a local file.
///
/// A build with NO source for these values shows a setup error screen at
/// startup — it never falls back to any offline fiction.
class AppEnv {
  const AppEnv({
    this.supabaseUrl,
    this.supabaseAnonKey,
    this.fcmProjectId,
    this.sentryDsn,
    this.rateApiUrl,
    this.configError,
  });

  final String? supabaseUrl;
  final String? supabaseAnonKey;

  /// Optional extras (used by later milestones).
  final String? fcmProjectId;
  final String? sentryDsn;
  final String? rateApiUrl;

  /// Non-null when the build has no usable server connection — main() shows
  /// a setup error screen with this message instead of the app.
  final String? configError;

  /// True when the app can reach its family server. There is no third state:
  /// an unconfigured build refuses to start the app shell.
  bool get isConfigured =>
      (supabaseUrl?.isNotEmpty ?? false) &&
      (supabaseAnonKey?.isNotEmpty ?? false);

  /// Loads the connection config: `.env` asset → dart-defines.
  /// Nothing to read anywhere → [configError] is set and main() shows the
  /// setup screen. Any problem reading `.env` is simply "no .env".
  static Future<AppEnv> load() async {
    var env = const AppEnv();
    try {
      env = AppEnv.parse(await rootBundle.loadString('.env'));
    } catch (_) {}
    if (env.isConfigured) return env;

    const dUrl = String.fromEnvironment('MHURI_SUPABASE_URL');
    const dKey = String.fromEnvironment('MHURI_SUPABASE_ANON_KEY');
    if (dUrl.isNotEmpty && dKey.isNotEmpty) {
      return AppEnv(
        supabaseUrl: dUrl,
        supabaseAnonKey: dKey,
        fcmProjectId: env.fcmProjectId,
        sentryDsn: env.sentryDsn,
        rateApiUrl: env.rateApiUrl,
      );
    }
    return AppEnv(
      fcmProjectId: env.fcmProjectId,
      sentryDsn: env.sentryDsn,
      rateApiUrl: env.rateApiUrl,
      configError: 'No server connection in this build. Rebuild with '
          'an app/.env file containing SUPABASE_URL and SUPABASE_ANON_KEY, '
          'or use --dart-define=MHURI_SUPABASE_URL=… and '
          '--dart-define=MHURI_SUPABASE_ANON_KEY=….',
    );
  }

  /// Parser kept deliberately simple: KEY=VALUE lines, `#` comments, optional
  /// matching quotes around values. Unknown lines are ignored.
  factory AppEnv.parse(String raw) {
    final map = <String, String>{};
    for (var line in raw.split('\n')) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final eq = line.indexOf('=');
      if (eq <= 0) continue;
      final k = line.substring(0, eq).trim();
      var v = line.substring(eq + 1).trim();
      if (v.length >= 2 &&
          ((v.startsWith('"') && v.endsWith('"')) ||
              (v.startsWith("'") && v.endsWith("'")))) {
        v = v.substring(1, v.length - 1);
      }
      map[k] = v;
    }

    return AppEnv(
      supabaseUrl: map['SUPABASE_URL'],
      supabaseAnonKey: map['SUPABASE_ANON_KEY'],
      fcmProjectId: map['FCM_PROJECT_ID'],
      sentryDsn: map['SENTRY_DSN'],
      rateApiUrl: map['RATE_API_URL'],
    );
  }
}
