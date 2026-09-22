import 'package:flutter/services.dart' show rootBundle;

/// App environment contract (M2).
///
/// Reads the optional `.env` bundled as a flutter asset (see pubspec.yaml —
/// the asset lines ship commented out; uncomment them after creating your
/// `.env` from `.env.example`). Missing `.env`, or an invalid one, always
/// means: offline demo mode, exactly as the app has always behaved.
enum EnvMode { demo, live }

class AppEnv {
  const AppEnv({
    required this.mode,
    this.supabaseUrl,
    this.supabaseAnonKey,
    this.fcmProjectId,
    this.sentryDsn,
    this.rateApiUrl,
    this.configError,
  });

  /// No `.env` found — pure demo mode.
  const AppEnv.fallback() : this(mode: EnvMode.demo);

  final EnvMode mode;
  final String? supabaseUrl;
  final String? supabaseAnonKey;

  /// Optional extras (used in later milestones).
  final String? fcmProjectId;
  final String? sentryDsn;
  final String? rateApiUrl;

  /// Non-null when `.env` asked for live mode but keys were missing — the app
  /// fell back to demo and this message should be surfaced in settings.
  final String? configError;

  /// Live mode only ever engages with a complete config. Never otherwise.
  bool get isLive =>
      mode == EnvMode.live &&
      (supabaseUrl?.isNotEmpty ?? false) &&
      (supabaseAnonKey?.isNotEmpty ?? false);

  /// Loads `.env` from the asset bundle. Any problem → try the
  /// `--dart-define` overrides (MHURI_APP_ENV / MHURI_SUPABASE_URL /
  /// MHURI_SUPABASE_ANON_KEY), then demo fallback. A build with neither
  /// source is demo by design — never half-configured.
  static Future<AppEnv> load() async {
    try {
      final raw = await rootBundle.loadString('.env');
      return AppEnv.parse(raw);
    } catch (_) {}
    const dartEnv = String.fromEnvironment('MHURI_APP_ENV');
    if (dartEnv.isNotEmpty) {
      return AppEnv.parse(
        'APP_ENV=$dartEnv\n'
        'SUPABASE_URL=${const String.fromEnvironment('MHURI_SUPABASE_URL')}\n'
        'SUPABASE_ANON_KEY=${const String.fromEnvironment('MHURI_SUPABASE_ANON_KEY')}\n',
      );
    }
    return const AppEnv.fallback();
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

    final wantsLive = (map['APP_ENV'] ?? 'demo').trim().toLowerCase() == 'live';
    final url = map['SUPABASE_URL'];
    final key = map['SUPABASE_ANON_KEY'];

    String? error;
    if (wantsLive && ((url?.isEmpty ?? true) || (key?.isEmpty ?? true))) {
      error = 'APP_ENV=live but SUPABASE_URL / SUPABASE_ANON_KEY are missing '
          '— running in demo mode instead.';
    }

    return AppEnv(
      mode: error == null && wantsLive ? EnvMode.live : EnvMode.demo,
      supabaseUrl: url,
      supabaseAnonKey: key,
      fcmProjectId: map['FCM_PROJECT_ID'],
      sentryDsn: map['SENTRY_DSN'],
      rateApiUrl: map['RATE_API_URL'],
      configError: error,
    );
  }
}
