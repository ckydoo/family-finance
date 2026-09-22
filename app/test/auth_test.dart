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

import 'fake_auth.dart';

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

http.Request _reqOf(http.BaseRequest r) => r as http.Request;

void main() {
  group('FakeAuthService (contract of the real GoTrue service)', () {
    test('bad input fails, valid email+password signs in, signOut clears',
        () async {
      final auth = FakeAuthService();
      expect((await auth.signIn('david@mhuri.app', '123')).ok, isFalse);
      expect((await auth.signIn('no-email', '123456')).ok, isFalse);
      final ok = await auth.signIn('david@mhuri.app', '123456');
      expect(ok.ok, isTrue);
      final session = await auth.restoreSession();
      expect(session, isNotNull);
      expect(session!.email, 'david@mhuri.app');
      await auth.signOut();
      expect(await auth.restoreSession(), isNull);
    });

    test('signUp succeeds and signs straight in (no confirmation)', () async {
      final auth = FakeAuthService();
      final r = await auth.signUp('mai@mhuri.app', '123456');
      expect(r.ok, isTrue);
      expect(r.needsConfirmation, isFalse);
      expect((await auth.restoreSession())!.email, 'mai@mhuri.app');
    });

    test('deleteAccount clears the active session', () async {
      final auth = FakeAuthService();
      await auth.signIn('david@mhuri.app', '123456');

      expect((await auth.deleteAccount()).ok, isTrue);
      expect(await auth.restoreSession(), isNull);
    });
  });

  group('AuthController', () {
    test('sign-in flow: bad input fails, good input sets a session, signOut clears it', () async {
      final c = AuthController(
        env: testEnv(),
        service: FakeAuthService(),
      );
      await c.restore();
      expect(c.isLoggedIn, isFalse);

      expect(await c.signIn('david@mhuri.app', '123'), isFalse);
      expect(c.lastError, isNotNull);

      expect(await c.signIn('david@mhuri.app', '123456'), isTrue);
      expect(c.isLoggedIn, isTrue);

      await c.signOut();
      expect(c.isLoggedIn, isFalse);
    });

    test('deleteAccount clears the controller session', () async {
      final c = AuthController(
        env: testEnv(),
        service: FakeAuthService(),
      );
      expect(await c.signIn('david@mhuri.app', '123456'), isTrue);

      expect(await c.deleteAccount(), isTrue);
      expect(c.isLoggedIn, isFalse);
      expect(c.lastError, isNull);
    });
  });

  group('SupabaseAuthService (GoTrue REST, offline via FakeClient)', () {
    late Map<String, String> kv;
    late FakeClient client;
    late SupabaseAuthService service;

    setUp(() {
      kv = {};
      client = FakeClient([]);
      service = SupabaseAuthService(
        baseUrl: 'https://abcdefgh.supabase.co/',
        anonKey: 'anon-key',
        kvGet: (k) async => kv[k],
        kvSet: (k, v) async => kv[k] = v,
        client: client,
      );
    });

    test('signIn posts to grant_type=password with email+payload', () async {
      client.responses.add(MapEntry(
          200,
          jsonEncode({
            'access_token': 'access-1',
            'refresh_token': 'refresh-1',
            'user': {'id': 'uuid-7', 'email': 'david@mhuri.app'},
          })));
      final r = await service.signIn('david@mhuri.app', '123456');
      expect(r.ok, isTrue);
      expect(client.sent.first.url.path, '/auth/v1/token');
      expect(client.sent.first.url.query, 'grant_type=password');
      expect(client.sent.first.headers['apikey'], 'anon-key');
      final body =
          jsonDecode(_reqOf(client.sent.first).body) as Map<String, dynamic>;
      expect(body['email'], 'david@mhuri.app');
      expect(body['password'], '123456');
    });

    test('signIn surfaces the server message on bad credentials', () async {
      client.responses
        ..clear()
        ..add(const MapEntry(400, '{"error":"Invalid login credentials"}'));
      final r = await service.signIn('david@mhuri.app', 'wrong-password');
      expect(r.ok, isFalse);
      expect(r.error, 'Invalid login credentials');
      expect(kv.containsKey('auth_access_token'), isFalse);
    });

    test('signIn stores tokens and session on success', () async {
      client.responses..clear()
        ..add(MapEntry(
            200,
            jsonEncode({
              'access_token': 'access-1',
              'refresh_token': 'refresh-1',
              'user': {'id': 'uuid-7', 'email': 'david@mhuri.app'},
            })));
      await service.signIn('david@mhuri.app', '123456');
      expect(kv['auth_access_token'], 'access-1');
      expect(kv['auth_refresh_token'], 'refresh-1');
      expect(kv['auth_user_id'], 'uuid-7');
      expect(kv['auth_email'], 'david@mhuri.app');
      final s = await service.restoreSession();
      expect(s, isNotNull);
      expect(s!.userId, 'uuid-7');
    });

    test('signUp with a session signs straight in (confirmation OFF)',
        () async {
      client.responses..clear()
        ..add(MapEntry(
            200,
            jsonEncode({
              'access_token': 'access-s',
              'refresh_token': 'refresh-s',
              'user': {'id': 'uuid-8', 'email': 'mai@mhuri.app'},
            })));
      final r = await service.signUp('mai@mhuri.app', '123456');
      expect(r.ok, isTrue);
      expect(r.needsConfirmation, isFalse);
      expect(kv['auth_access_token'], 'access-s');
      expect(client.sent.single.url.path, '/auth/v1/signup');
    });

    test('signUp without a session flags email confirmation (default ON)',
        () async {
      client.responses..clear()
        ..add(MapEntry(
            200,
            jsonEncode({
              'user': {'id': 'uuid-9', 'email': 'mai@mhuri.app'},
            })));
      final r = await service.signUp('mai@mhuri.app', '123456');
      expect(r.ok, isTrue);
      expect(r.needsConfirmation, isTrue);
      expect(kv.containsKey('auth_access_token'), isFalse);
    });

    test('signUp surfaces server errors (weak password)', () async {
      client.responses..clear()
        ..add(const MapEntry(
            422,
            '{"error":"Password should be at least 6 characters"}'));
      final r = await service.signUp('mai@mhuri.app', '123');
      expect(r.ok, isFalse);
      expect(r.error, contains('at least 6'));
    });

    test('restoreSession refreshes a dead access token', () async {
      // Pre-store a session as if a previous run signed in.
      kv['auth_access_token'] = 'stale';
      kv['auth_refresh_token'] = 'refresh-9';
      kv['auth_user_id'] = 'uuid-7';
      kv['auth_email'] = 'david@mhuri.app';

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

    test('a TRANSIENT refresh failure keeps the stored session (no empty-JWT state)', () async {
      // Stored session from a previous run.
      kv['auth_access_token'] = 'access-1';
      kv['auth_refresh_token'] = 'refresh-1';
      kv['auth_user_id'] = 'uuid-7';
      kv['auth_email'] = 'david@mhuri.app';

      // Supabase hiccups (5xx) on the refresh grant.
      client = FakeClient([const MapEntry(500, '{"error":"upstream unavailable"}')]);
      service = SupabaseAuthService(
        baseUrl: 'https://abcdefgh.supabase.co/',
        anonKey: 'anon-key',
        kvGet: (k) async => kv[k],
        kvSet: (k, v) async => kv[k] = v,
        client: client,
      );

      final s = await service.restoreSession();

      // Session survives from the stored identity; tokens NOT wiped —
      // wiping them here produced "logged-in app sending empty JWT".
      expect(s, isNotNull);
      expect(s!.userId, 'uuid-7');
      expect(kv['auth_access_token'], 'access-1');
      expect(kv['auth_refresh_token'], 'refresh-1');
    });

    test('a DEAD refresh token (400) clears tokens for a clean re-login', () async {
      kv['auth_access_token'] = 'access-1';
      kv['auth_refresh_token'] = 'refresh-dead';
      kv['auth_user_id'] = 'uuid-7';
      kv['auth_email'] = 'david@mhuri.app';

      client = FakeClient([const MapEntry(400, '{"error":"Invalid Refresh Token"}')]);
      service = SupabaseAuthService(
        baseUrl: 'https://abcdefgh.supabase.co/',
        anonKey: 'anon-key',
        kvGet: (k) async => kv[k],
        kvSet: (k, v) async => kv[k] = v,
        client: client,
      );

      final s = await service.restoreSession();
      expect(s, isNull);
      expect(kv['auth_access_token'], '');
      expect(kv['auth_refresh_token'], '');
    });

    test('refreshAccessToken() renews and persists the access token', () async {
      kv['auth_access_token'] = 'access-1';
      kv['auth_refresh_token'] = 'refresh-1';
      kv['auth_user_id'] = 'uuid-7';
      kv['auth_email'] = 'david@mhuri.app';

      client = FakeClient([MapEntry(
          200,
          jsonEncode({
            'access_token': 'access-9',
            'refresh_token': 'refresh-9',
          }))]);
      service = SupabaseAuthService(
        baseUrl: 'https://abcdefgh.supabase.co/',
        anonKey: 'anon-key',
        kvGet: (k) async => kv[k],
        kvSet: (k, v) async => kv[k] = v,
        client: client,
      );

      final token = await service.refreshAccessToken();
      expect(token, 'access-9');
      expect(kv['auth_access_token'], 'access-9');
      expect(kv['auth_refresh_token'], 'refresh-9');
      expect(service.session!.userId, 'uuid-7');
    });

    test('signOut clears stored tokens (best-effort server call)', () async {
      client.responses
        ..clear()
        ..addAll([
          MapEntry(
              200,
              jsonEncode({
                'access_token': 'access-1',
                'refresh_token': 'refresh-1',
                'user': {'id': 'uuid-7', 'email': 'david@mhuri.app'},
              })),
          const MapEntry(204, ''),
        ]);
      await service.signIn('david@mhuri.app', '123456');
      await service.signOut();
      expect(kv['auth_access_token'], '');
      expect(await service.restoreSession(), isNull);
    });

    test('deleteAccount invokes the protected RPC and clears tokens',
        () async {
      kv
        ..['auth_access_token'] = 'access-delete'
        ..['auth_refresh_token'] = 'refresh-delete'
        ..['auth_user_id'] = 'uuid-delete'
        ..['auth_email'] = 'david@mhuri.app';
      client = FakeClient([const MapEntry(204, '')]);
      service = SupabaseAuthService(
        baseUrl: 'https://abcdefgh.supabase.co/',
        anonKey: 'anon-key',
        kvGet: (k) async => kv[k],
        kvSet: (k, v) async => kv[k] = v,
        client: client,
      );

      final result = await service.deleteAccount();

      expect(result.ok, isTrue);
      expect(client.sent.single.url.path, '/rest/v1/rpc/delete_own_account');
      expect(
          client.sent.single.headers['Authorization'], 'Bearer access-delete');
      expect(kv['auth_access_token'], '');
      expect(kv['auth_refresh_token'], '');
    });
  });

  group('PinStore (hashed, in-memory fallback)', () {
    test('parent default 1234 works until a real PIN is set', () async {
      final pins = PinStore();
      expect(await pins.verifyPin(PinStore.parentKey, '1234'), isTrue);

      await pins.setPin(PinStore.parentKey, '998877');
      expect(await pins.hasPin(PinStore.parentKey), isTrue);
    });
  });
}
