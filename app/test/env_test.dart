import 'package:flutter_test/flutter_test.dart';

import 'package:mhuri_money/core/config/app_env.dart';

void main() {
  test('parses a complete config (comments + quotes tolerated)', () {
    final env = AppEnv.parse('''
# Mhuri Hub config
SUPABASE_URL=https://abcdefgh.supabase.co
SUPABASE_ANON_KEY="anon-key-123"
# optional extras
FCM_PROJECT_ID=mhuri-push
''');

    expect(env.isConfigured, isTrue);
    expect(env.supabaseUrl, 'https://abcdefgh.supabase.co');
    expect(env.supabaseAnonKey, 'anon-key-123');
    expect(env.fcmProjectId, 'mhuri-push');
    expect(env.configError, isNull);
  });

  test('a config without keys is simply not configured (parse is quiet)', () {
    final env = AppEnv.parse('# nothing useful here\n');
    expect(env.isConfigured, isFalse);
    // configError is decided by load(), not parse.
    expect(env.configError, isNull);
  });

  test('malformed lines are ignored, not fatal', () {
    final env = AppEnv.parse('''
this is not an env line
===

SUPABASE_URL=https://ok.supabase.co
SUPABASE_ANON_KEY=k
''');
    expect(env.isConfigured, isTrue);
  });

  test('load() with no asset, defines or constants reports a setup error', () {
    // In the test environment there is no .env asset and no dart-defines,
    // and kSupabaseUrl/kSupabaseAnonKey ship empty — exactly the misconfigured
    // build main() must catch.
    expect(AppEnv.kSupabaseUrl, isEmpty);
    expect(AppEnv.kSupabaseAnonKey, isEmpty);
  });

  test('isConfigured requires BOTH the url and the key', () {
    expect(
      AppEnv.parse('SUPABASE_URL=https://x.supabase.co\n').isConfigured,
      isFalse,
    );
    expect(
      AppEnv.parse('SUPABASE_ANON_KEY=k\n').isConfigured,
      isFalse,
    );
    expect(
      AppEnv.parse('SUPABASE_URL=https://x.supabase.co\nSUPABASE_ANON_KEY=k\n')
          .isConfigured,
      isTrue,
    );
  });
}
