import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:mhuri_money/core/auth/recovery_link.dart';

String _b64url(String s) => base64Url.encode(utf8.encode(s)).replaceAll('=', '');

String _jwt({String sub = 'uid-1', String email = 'ama@example.com'}) =>
    '${_b64url('{"alg":"HS256","typ":"JWT"}').}${_b64url(jsonEncode({"sub": sub, "email": email}))}.sig';

void main() {
  group('parseRecoveryLink', () {
    test('implicit-flow link with fragment tokens', () {
      final r = parseRecoveryLink(
          'mhuri://reset-callback#access_token=abc.def.ghi&refresh_token=r1&'
          'expires_in=3600&token_type=bearer&type=recovery');
      expect(r.kind, RecoveryKind.tokens);
      expect(r.accessToken, 'abc.def.ghi');
      expect(r.refreshToken, 'r1');
      expect(r.isRecovery, isTrue);
    });

    test('uppercase scheme still recognised', () {
      final r = parseRecoveryLink(
          'MHURI://reset-callback#access_token=a&refresh_token=b');
      expect(r.kind, RecoveryKind.tokens);
    });

    test('PKCE code link reported as unsupported', () {
      final r = parseRecoveryLink('mhuri://reset-callback?code=pkce-code');
      expect(r.kind, RecoveryKind.code);
      expect(r.isRecovery, isTrue);
    });

    test('foreign links and host links are ignored', () {
      expect(
          parseRecoveryLink(
                  'https://evil.example.com/#access_token=x&refresh_token=y')
              .kind,
          RecoveryKind.none);
      expect(parseRecoveryLink('mhuri://something-else').kind,
          RecoveryKind.none);
      expect(
          parseRecoveryLink('mhuri://reset-callback').kind, RecoveryKind.none);
    });

    test('garbage is safe', () {
      expect(parseRecoveryLink('').kind, RecoveryKind.none);
      expect(parseRecoveryLink('::::not a url:::').kind, RecoveryKind.none);
    });
  });

  group('claimsFromJwt', () {
    test('reads sub and email from the payload', () {
      final c = claimsFromJwt(_jwt());
      expect(c['sub'], 'uid-1');
      expect(c['email'], 'ama@example.com');
    });

    test('malformed token returns empty, never throws', () {
      expect(claimsFromJwt('not-a-jwt'), isEmpty);
      expect(claimsFromJwt('a.b.c'), isEmpty);
      expect(claimsFromJwt(''), isEmpty);
    });
  });

  group('parseInviteCode', () {
    test('join link yields the code, uppercased', () {
      expect(parseInviteCode('mhuri://join?c=MHRI-ab12cd'), 'MHRI-AB12CD');
      expect(parseInviteCode('mhuri://join?code=MHRI-XY12ZW'), 'MHRI-XY12ZW');
    });

    test('non-invite and garbage links are ignored', () {
      expect(parseInviteCode('mhuri://reset-callback#access_token=x'),
          isNull);
      expect(parseInviteCode('https://example.com/join?c=MHRI-AB12CD'), isNull);
      expect(parseInviteCode('mhuri://join'), isNull);
      expect(parseInviteCode('mhuri://join?c=DROP TABLE'), isNull);
      expect(parseInviteCode(''), isNull);
    });
  });
}
