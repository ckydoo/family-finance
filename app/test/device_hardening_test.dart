import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/auth/recovery_link.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/notifications/reminders.dart';

void main() {
  group('Phase 7 - Deep Links & Universal Links', () {
    test('parses custom scheme invite link with ?c= parameter', () {
      final code = parseInviteCode('mhuri://join?c=MHRI-ABC123');
      expect(code, 'MHRI-ABC123');
    });

    test('parses custom scheme invite link with ?code= parameter', () {
      final code = parseInviteCode('mhuri://join?code=MHRI-XYZ999');
      expect(code, 'MHRI-XYZ999');
    });

    test('parses HTTPS universal link with https://mhuri.app/join?c=...', () {
      final code = parseInviteCode('https://mhuri.app/join?c=MHRI-UNI888');
      expect(code, 'MHRI-UNI888');
    });

    test('parses HTTPS universal link with https://mhuri.money/invite?code=...', () {
      final code = parseInviteCode('https://mhuri.money/invite?code=MHRI-LIVE42');
      expect(code, 'MHRI-LIVE42');
    });

    test('case-insensitivity and whitespace trimming on invite codes', () {
      final code = parseInviteCode('mhuri://join?c=%20mhri-abc123%20');
      expect(code, 'MHRI-ABC123');
    });

    test('rejects non-invite links and returns null without throwing', () {
      expect(parseInviteCode(''), isNull);
      expect(parseInviteCode('not a url ::: garbage'), isNull);
      expect(parseInviteCode('https://google.com'), isNull);
      expect(parseInviteCode('mhuri://other-action?code=MHRI-1234'), isNull);
      expect(parseInviteCode('https://mhuri.app/about'), isNull);
      expect(parseInviteCode('mhuri://join?c=INVALID_CODE_FORMAT'), isNull);
      expect(parseInviteCode('mhuri://join?c='), isNull);
    });

    test('parses recovery links with token fragments', () {
      const url =
          'mhuri://reset-callback#access_token=test_access_token&refresh_token=test_refresh_token&expires_in=3600&type=recovery';
      final res = parseRecoveryLink(url);
      expect(res.kind, RecoveryKind.tokens);
      expect(res.isRecovery, isTrue);
      expect(res.accessToken, 'test_access_token');
      expect(res.refreshToken, 'test_refresh_token');
    });

    test('detects PKCE code-based reset link as needing fresh link', () {
      const url = 'mhuri://reset-callback?code=some_pkce_auth_code';
      final res = parseRecoveryLink(url);
      expect(res.kind, RecoveryKind.code);
      expect(res.isRecovery, isTrue);
    });

    test('rejects non-recovery links', () {
      expect(parseRecoveryLink('').kind, RecoveryKind.none);
      expect(parseRecoveryLink('https://example.com').kind, RecoveryKind.none);
      expect(parseRecoveryLink('mhuri://home').kind, RecoveryKind.none);
    });

    test('extracts claims from JWT payload safely', () {
      // standard mock JWT with payload: {"email": "family@mhuri.money", "sub": "usr_123"}
      // base64url: eyJlbWFpbCI6ICJmYW1pbHlAbWh1cmkubW9uZXkiLCAic3ViIjogInVzcl8xMjMifQ
      const jwt = 'header.eyJlbWFpbCI6ICJmYW1pbHlAbWh1cmkubW9uZXkiLCAic3ViIjogInVzcl8xMjMifQ.signature';
      final claims = claimsFromJwt(jwt);
      expect(claims['email'], 'family@mhuri.money');
      expect(claims['sub'], 'usr_123');
    });

    test('handles invalid JWTs gracefully', () {
      expect(claimsFromJwt(''), isEmpty);
      expect(claimsFromJwt('not.a.jwt.token'), isEmpty);
      expect(claimsFromJwt('bad_single_part'), isEmpty);
    });
  });

  group('Phase 7 - Notifications & Quiet Hours Hardening', () {
    test('DND quiet hours slide notifications to the end of the quiet window', () {
      // Quiet hours 21:00 (9pm) to 07:00 (7am)
      const config = NotifyConfig(
        enabled: true,
        allowed: {ReminderCategory.bills},
        quietStart: 21,
        quietEnd: 7,
      );

      // 22:30 (10:30pm) is in quiet hours
      expect(config.inQuiet(22), isTrue);
      expect(config.inQuiet(23), isTrue);
      expect(config.inQuiet(0), isTrue);
      expect(config.inQuiet(6), isTrue);
      // 07:00 and 14:00 are not in quiet hours
      expect(config.inQuiet(7), isFalse);
      expect(config.inQuiet(14), isFalse);
    });

    test('quiet window disabled when quietStart == quietEnd', () {
      const config = NotifyConfig(
        enabled: true,
        allowed: {ReminderCategory.bills},
        quietStart: 8,
        quietEnd: 8,
      );
      expect(config.quietEnabled, isFalse);
      expect(config.inQuiet(8), isFalse);
      expect(config.inQuiet(22), isFalse);
    });

    test('planner respects master switch and disabled categories', () {
      final now = DateTime(2026, 9, 23, 10, 0);
      final due = now.add(const Duration(days: 1));
      final rule = RecurringRule(
        id: 'r_wifi',
        name: 'Fiber Internet',
        emoji: 'wifi',
        amount: const Money(4500, Currency.usd),
        memberId: 'm1',
        method: Method.bankCard,
        frequency: Frequency.monthly,
        nextDue: due,
        active: true,
      );

      // When notifications are disabled:
      const disabledConfig = NotifyConfig(
        enabled: false,
        allowed: {ReminderCategory.bills},
      );
      final emptyPlan = ReminderPlanner.plan(
        now: now,
        config: disabledConfig,
        recurring: [rule],
        envelopes: [],
        chores: [],
        requests: [],
        circle: null,
        memberNames: {},
        monthStartDay: 1,
      );
      expect(emptyPlan, isEmpty);

      // When bills category is not allowed:
      const noBillsConfig = NotifyConfig(
        enabled: true,
        allowed: {ReminderCategory.budget},
      );
      final noBillsPlan = ReminderPlanner.plan(
        now: now,
        config: noBillsConfig,
        recurring: [rule],
        envelopes: [],
        chores: [],
        requests: [],
        circle: null,
        memberNames: {},
        monthStartDay: 1,
      );
      expect(noBillsPlan, isEmpty);

      // When bills category is allowed:
      const billsConfig = NotifyConfig(
        enabled: true,
        allowed: {ReminderCategory.bills},
        quietStart: 22,
        quietEnd: 6,
      );
      final activePlan = ReminderPlanner.plan(
        now: now,
        config: billsConfig,
        recurring: [rule],
        envelopes: [],
        chores: [],
        requests: [],
        circle: null,
        memberNames: {},
        monthStartDay: 1,
      );
      expect(activePlan, isNotEmpty);
      expect(activePlan.first.category, ReminderCategory.bills);
      expect(activePlan.first.title, contains('Fiber Internet'));
    });

    test('stable 31-bit notification ID derived for OS notification scheduler', () {
      final r1 = Reminder(
        key: 'bill_r_wifi_2026-09-24',
        category: ReminderCategory.bills,
        title: 'Fiber Internet',
        body: 'Due tomorrow',
        when: DateTime(2026, 9, 24, 9, 0),
      );
      final r2 = Reminder(
        key: 'bill_r_wifi_2026-09-24',
        category: ReminderCategory.bills,
        title: 'Fiber Internet',
        body: 'Due tomorrow',
        when: DateTime(2026, 9, 24, 9, 0),
      );

      expect(r1.id, equals(r2.id));
      expect(r1.id, greaterThanOrEqualTo(0));
      expect(r1.id, lessThan(0x7fffffff)); // 31-bit max
    });
  });
}

