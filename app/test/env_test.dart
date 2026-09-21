import 'package:flutter_test/flutter_test.dart';

import 'package:mhuri_money/core/config/app_env.dart';

void main() {
  test('parses a complete live config (comments + quotes tolerated)', () {
    final env = AppEnv.parse('''
# Mhuri Money live config
APP_ENV=live
SUPABASE_URL=https://abcdefgh.supabase.co
SUPABASE_ANON_KEY="anon-key-123"
# optional extras
FCM_PROJECT_ID=mhuri-push
''');

    expect(env.mode, EnvMode.live);
    expect(env.isLive, isTrue);
    expect(env.supabaseUrl, 'https://abcdefgh.supabase.co');
    expect(env.supabaseAnonKey, 'anon-key-123');
    expect(env.fcmProjectId, 'mhuri-push');
    expect(env.configError, isNull);
  });

  test('live mode without keys falls back to demo with a config error', () {
    final env = AppEnv.parse('APP_ENV=live\n');
    expect(env.isLive, isFalse);
    expect(env.mode, EnvMode.demo);
    expect(env.configError, isNotNull);
  });

  test('missing .env semantics: fallback is quiet demo mode', () {
    const env = AppEnv.fallback();
    expect(env.isLive, isFalse);
    expect(env.mode, EnvMode.demo);
    expect(env.configError, isNull);
  });

  test('explicit demo stays demo even with keys present', () {
    final env = AppEnv.parse(
      'APP_ENV=demo\nSUPABASE_URL=https://x.supabase.co\nSUPABASE_ANON_KEY=k\n',
    );
    expect(env.mode, EnvMode.demo);
    expect(env.isLive, isFalse);
  });

  test('malformed lines are ignored, not fatal', () {
    final env = AppEnv.parse('''
this is not an env line
===

APP_ENV=live
SUPABASE_URL=https://ok.supabase.co
SUPABASE_ANON_KEY=k
''');
    expect(env.isLive, isTrue);
  });
}
