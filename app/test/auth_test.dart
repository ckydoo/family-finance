import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:mhuri_money/core/auth/auth_controller.dart';
import 'package:mhuri_money/core/auth/auth_service.dart';
import 'package:mhuri_money/core/auth/pin_store.dart';
import 'package:mhuri_money/core/auth/supabase_auth_service.dart';
import 'package:mhuri_money/core/config/app_env.dart';

/// Queues canned responses; records every request so tests can assert the
/// exact endpoints and payloads the hand-written GoTrue client produces.
class FakeClient extends http.BaseClient {
  FakeClient(this.responses);

  final List<MapEntry<int, String>> responses;
  final List<http.BaseRequest> sent = [];
  int _i = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sent.add(request);
    final r = responses[_i.clamp(0, responses.length - 1)];
    _i++;
    final bytes = Uint8List.fromList(utf8.encode(r.value));
    return http.StreamedResponse(Stream.value(bytes), r.key);
  }
}

void main() {
  group('DemoAuthService', () {
    test('wrong code fails, 1234 signs in, signOut clears', () async {
      final auth = DemoAuthService();
      await auth.sendOtp('+263772123456');
      expect((await auth.verifyOtp('+263772123456', '9999')).ok, isFalse);
      final ok = await auth.verifyOtp('+263772123456', '1234');
      expect(ok.ok, isTrue);
      final session = await auth.restoreSession();
      expect(session, isNotNull);
      await auth.signOut();
      expect(await auth.restoreSession(), isNull);
    });
  });

  group('AuthController', () {
    test('demo flow: verify sets a session, signOut clears it', () async {
      final c = AuthController(
        env: AppEnv.parse('APP_ENV=demo'),
        service: DemoAuthService(),
      );
      await c.restore();
      expect(c.isLoggedIn, isFalse);

      expect(await c.verify('+263772123456', '9999'), isFalse);
      expect(c.lastError, isNotNull);

      expect(await c.verify('+263772123456', '1234'), isTrue);
      expect(c.isLoggedIn, isTrue);

      await c.signOut();
      expect(c.isLoggedIn, isFalse);
    });
  });

  group('SupabaseAuthService (GoTrue REST, offline via FakeClient)', () {
    late Map<String, String> kv;
    late FakeClient client;
    late SupabaseAuthService service;

    setUp(() {
      kv = {};
      client = FakeClient([
        // sendOtp → 200 (code dispatched by SMS)
        const MapEntry(200, '{}'),
        // verifyOtp → 400 first (wrong code), then 200 with tokens
        const MapEntry(400, '{"msg":"Invalid token"}'),
        MapEntry(
            200,
            jsonEncode({
              'access_token': 'access-1',
              'refresh_token': 'refresh-1',
              'user': {'id': 'uuid-7'},
            })),
      ]);
      service = SupabaseAuthService(
        baseUrl: 'https://abcdefgh.supabase.co/',
        anonKey: 'anon-key',
        kvGet: (k) async => kv[k],
        kvSet: (k, v) async => kv[k] = v,
        client: client,
      );
    });

    test('sendOtp posts to /auth/v1/otp with the anon key', () async {
      final r = await service.sendOtp('+263772123456');
      expect(r.ok, isTrue);
      expect(client.sent.first.url.path, '/auth/v1/otp');
      expect(client.sent.first.headers['apikey'], 'anon-key');
      final body = jsonDecode((client.sent.first as http.Request).body)
          as Map<String, dynamic>;
      expect(body['phone'], '+263772123456');
    });

    test('verifyOtp surfaces the server message on failure', () async {
      final r = await service.verifyOtp('+263772123456', '000000');
      expect(r.ok, isFalse);
      expect(r.error, 'Invalid token');
      expect(kv.containsKey('auth_access_token'), isFalse);
    });

    test('verifyOtp stores tokens and session on success', () async {
      await service.verifyOtp('+263772123456', '123456');
      expect(kv['auth_access_token'], 'access-1');
      expect(kv['auth_refresh_token'], 'refresh-1');
      expect(kv['auth_user_id'], 'uuid-7');
      final s = await service.restoreSession();
      expect(s, isNotNull);
      expect(s!.userId, 'uuid-7');
    });

    test('restoreSession refreshes a dead access token', () async {
      // Pre-store a session as if a previous run signed in.
      kv['auth_access_token'] = 'stale';
      kv['auth_refresh_token'] = 'refresh-9';
      kv['auth_user_id'] = 'uuid-7';
      kv['auth_phone'] = '+263772123456';

      client.responses.clear();
      client.responses.add(MapEntry(
          200,
          jsonEncode({
            'access_token': 'access-2',
            'refresh_token': 'refresh-10',
          })));

      final s = await service.restoreSession();
      expect(s, isNotNull);
      expect(client.sent.first.url.path,
          '/auth/v1/token'); // refresh grant endpoint
      expect(kv['auth_access_token'], 'access-2');
      expect(kv['auth_refresh_token'], 'refresh-10');
    });

    test('signOut clears stored tokens (best-effort server call)', () async {
      await service.verifyOtp('+263772123456', '123456');
      await service.signOut();
      expect(kv['auth_access_token'], '');
      expect(await service.restoreSession(), isNull);
    });
  });

  group('PinStore (hashed, in-memory fallback)', () {
    test('parent default 1234 works until a real PIN is set', () async {
      final pins = PinStore();
      expect(await pins.verifyPin(PinStore.parentKey, '1234'), isTrue);

      await pins.setPin(PinStore.parentKey, '998877');
      expect(await pins.hasPin(PinStore.parentKey), isTrue);
      expect(await pins.verifyPin(PinStore.parentKey, '1234'), isFalse);
      expect(await pins.verifyPin(PinStore.parentKey, '998877'), isTrue);

      await pins.clearPin(PinStore.parentKey);
      expect(await pins.hasPin(PinStore.parentKey), isFalse);
      expect(await pins.verifyPin(PinStore.parentKey, '1234'), isTrue);
    });

    test('kid profile with no PIN opens freely; set PIN is enforced', () async {
      final pins = PinStore();
      expect(await pins.verifyPin('m_leo', '9999'), isTrue);
      await pins.setPin('m_leo', '2468');
      expect(await pins.verifyPin('m_leo', '9999'), isFalse);
      expect(await pins.verifyPin('m_leo', '2468'), isTrue);
    });

    test('PINs are never stored in plaintext', () async {
      final kv = <String, String>{};
      final pins = PinStore(
        kvGet: (k) async => kv[k],
        kvSet: (k, v) async => kv[k] = v,
      );
      await pins.setPin(PinStore.parentKey, '1234');
      expect(kv.containsValue('1234'), isFalse);
      expect(kv['pin_parent']!.length, 64); // sha256 hex
    });
  });
}
