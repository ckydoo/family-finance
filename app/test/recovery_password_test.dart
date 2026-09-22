import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:mhuri_money/core/auth/auth_service.dart';
import 'package:mhuri_money/core/auth/recovery_link.dart';
import 'package:mhuri_money/core/auth/supabase_auth_service.dart';

/// Queues canned responses; records every request.
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

String _b64url(String s) => base64Url.encode(utf8.encode(s)).replaceAll('=', '');

String _jwt({String sub = 'uid-9', String email = 'bongi@example.com'}) =>
    '${_b64url('{"alg":"HS256"}').}${_b64url(jsonEncode({"sub": sub, "email": email}))}.sig';

void main() {
  final kv = <String, String>{};
  late SupabaseAuthService service;
  late FakeClient client;

  setUp(() {
    kv.clear();
    kv['auth_access_token'] = _jwt();
    kv['auth_refresh_token'] = 'refresh-1';
    client = FakeClient([const MapEntry(200, '{}')]);
    service = SupabaseAuthService(
      baseUrl: 'https://abcdefgh.supabase.co/',
      anonKey: 'anon-key',
      kvGet: (k) async => kv[k],
      kvSet: (k, v) async => kv[k] = v,
      client: client,
    );
  });

  group('updatePassword (recovery step 2)', () {
    test('PUTs the new password to /auth/v1/user with the session', () async {
      final r = await service.updatePassword('NewPass123');
      expect(r.ok, isTrue);
      final req = _reqOf(client.sent.last);
      expect(req.method, 'PUT');
      expect(req.url.toString(),
          'https://abcdefgh.supabase.co/auth/v1/user');
      expect(req.headers['Authorization'], 'Bearer ${_jwt()}');
      expect(jsonDecode(req.body), {'password': 'NewPass123'});
    });

    test('a dead recovery session → honest expired code', () async {
      client.responses.clear();
      client.responses.add(const MapEntry(401, '{"msg":"jwt expired"}'));
      final r = await service.updatePassword('NewPass123');
      expect(r.ok, isFalse);
      expect(r.code, 'reset_expired');
    });

    test('weak password surfaces the server reason', () async {
      client.responses.clear();
      client.responses.add(const MapEntry(
          422,
          '{"msg":"Password should be at least 8 characters.",'
          '"error":"weak_password"}'));
      final r = await service.updatePassword('short');
      expect(r.ok, isFalse);
      expect(r.code, 'weak_password');
    });

    test('no stored token fails fast without a request', () async {
      kv.remove('auth_access_token');
      final r = await service.updatePassword('NewPass123');
      expect(r.ok, isFalse);
      expect(r.code, 'reset_expired');
      expect(client.sent, isEmpty);
    });
  });

  group('adoptRecoverySession (recovery step 1)', () {
    test('persists tokens, sets the session, marks the pending reset',
        () async {
      final ok =
          await service.adoptRecoverySession(_jwt(), 'refresh-from-link');
      expect(ok, isTrue);
      expect(kv['auth_access_token'], _jwt());
      expect(kv['auth_refresh_token'], 'refresh-from-link');
      expect(kv['pw_reset_pending'], '1');
      expect(service.session, isNotNull);
      expect(service.session!.email, 'bongi@example.com');
    });

    test('rejects a token without a sub claim', () async {
      final ok = await service.adoptRecoverySession('garbage', 'r');
      expect(ok, isFalse);
      expect(service.session, isNull);
    });
  });

  group('pending-reset marker lifecycle', () {
    test('signOut clears the marker', () async {
      await service.adoptRecoverySession(_jwt(), 'r');
      expect(kv['pw_reset_pending'], '1');
      await service.signOut();
      expect(kv['pw_reset_pending'], '');
    });
  });

  test('the recover email asks to come back to the app', () async {
    kv.remove('auth_access_token');
    await service.sendPasswordReset('bongi@example.com');
    final req = _reqOf(client.sent.last);
    expect(req.url.host, 'abcdefgh.supabase.co');
    expect(req.url.path, '/auth/v1/recover');
    expect(req.url.queryParameters['redirect_to'],
        contains('mhuri://reset-callback'));
    expect(req.headers['redirect_to'], 'mhuri://reset-callback');
    expect(kRecoveryRedirect, startsWith('mhuri://'));
  });
}

http.Request _reqOf(http.BaseRequest r) => r as http.Request;
