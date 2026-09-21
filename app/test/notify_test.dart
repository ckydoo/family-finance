import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/db/app_database.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/notifications/reminders.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// M5 — the reminder planner (pure, spec J2/J3) and notification settings
/// persistence. Plugin calls themselves are device-only (Notifier no-ops
/// off Android/iOS), so tests cover the plan, not the platform channel.
void main() {
  final now = DateTime(2026, 9, 21, 10); // Monday, 10:00
  const config = NotifyConfig(
    enabled: true,
    allowed: {
      ReminderCategory.bills,
      ReminderCategory.budget,
      ReminderCategory.kids,
      ReminderCategory.circle,
      ReminderCategory.goals,
      ReminderCategory.meeting,
      ReminderCategory.digest,
    },
  );

  Reminder rule(String id, DateTime due, {bool active = true}) =>
      RecurringRule(
        id: id,
        name: 'School levy',
        emoji: 'school',
        amount: Money.fromMajor(20, Currency.usd),
        memberId: 'm_david',
        method: Method.bankTransfer,
        frequency: Frequency.monthly,
        nextDue: due,
        active: active,
      );

  List<Reminder> plan({
    NotifyConfig cfg = config,
    List<RecurringRule> recurring = const [],
    List<EnvelopeHealth> envelopes = const [],
    List<Chore> chores = const [],
    List<KidRequest> requests = const [],
    SavingsCircle? circle,
    List<Reminder> extra = const [],
  }) {
    return ReminderPlanner.plan(
      now: now,
      config: cfg,
      recurring: recurring,
      envelopes: envelopes,
      chores: chores,
      requests: requests,
      circle: muk,
      memberNames: const {'m_leo': 'Leo', 'm_zoe': 'Zoe'},
      monthStartDay: 25,
      extra: extra,
    );
  }

  group('planner — bills due (C7: 3-day reminder)', () {
    test('due in 2 days → morning-of reminder', () {
      final out = plan(recurring: [rule('rc_x', now.add(const Duration(days: 2)))]);
      final bill = out.where((r) => r.key.startsWith('bill_')).toList();
      expect(bill, hasLength(1));
      expect(bill.first.when.hour, 9);
      expect(bill.first.when.day, now.add(const Duration(days: 2)).day);
    });

    test('due in 10 days → no reminder yet', () {
      final out =
          plan(recurring: [rule('rc_x', now.add(const Duration(days: 10)))]);
      expect(out.where((r) => r.key.startsWith('bill_')), isEmpty);
    });

    test('overdue → reminder within minutes', () {
      final out = plan(
        recurring: [rule('rc_x', now.subtract(const Duration(days: 1)))],
      );
      final bill = out.where((r) => r.key.startsWith('bill_')).first;
      expect(bill.key, contains('overdue'));
      expect(bill.when.difference(now).inMinutes, lessThanOrEqualTo(15));
    });

    test('paused rules never remind', () {
      final out = plan(
        recurring: [
          rule('rc_x', now.add(const Duration(days: 1)), active: false),
        ],
      );
      expect(out.where((r) => r.key.startsWith('bill_')), isEmpty);
    });
  });

  group('planner — budget & kids (J2)', () {
    test('envelope at 80% warns; at 50% stays quiet', () {
      final env = Envelope(
        id: 'e_x',
        name: 'Groceries',
        emoji: 'cart',
        limit: Money.fromMajor(100, Currency.usd),
      );
      final out80 = plan(envelopes: [
        EnvelopeHealth(
          envelope: env,
          limit: Money.fromMajor(100, Currency.usd),
          spent: Money.fromMajor(85, Currency.usd),
          cycleStart: now,
        ),
      ]);
      expect(out80.where((r) => r.key.startsWith('budget_')), hasLength(1));
      final out50 = plan(envelopes: [
        EnvelopeHealth(
          envelope: env,
          limit: Money.fromMajor(100, Currency.usd),
          spent: Money.fromMajor(50, Currency.usd),
          cycleStart: now,
        ),
      ]);
      expect(out50.where((r) => r.key.startsWith('budget_')), isEmpty);
    });

    test('pending kid request reminds; answered ones do not', () {
      final req = KidRequest(
        id: 'kr_1',
        kidId: 'm_leo',
        amount: Money.fromMajor(5, Currency.usd),
        reason: 'Soccer ball',
      );
      final out = plan(requests: [req]);
      expect(out.where((r) => r.key == 'kid_kr_1'), hasLength(1));
      final answered = req..state = RequestState.approved;
      final out2 = plan(requests: [answered]);
      expect(out2.where((r) => r.key == 'kid_kr_1'), isEmpty);
    });

    test('chore waiting for confirmation reminds the parent', () {
      final out = plan(
        chores: [
          Chore(id: 'ch_1', name: 'Dishes', stars: 2, state: ChoreState.waiting),
        ],
      );
      expect(out.where((r) => r.key == 'chore_ch_1'), hasLength(1));
    });
  });

  group('planner — weekly beats & meeting', () {
    test('savings-circle reminder is weekly on Sunday 17:00', () {
      final muk = SavingsCircle(
        name: 'Circle',
        contribution: Money.fromMajor(50, Currency.usd),
        totalRounds: 8,
        currentRound: 4,
        order: const ['m_david', 'm_maya', 'm_leo', 'm_zoe'],
      );
      final out = plan(circle: muk);
      final m = out.firstWhere((r) => r.key == 'circle_weekly');
      expect(m.weekly, isTrue);
      expect(m.when.weekday, DateTime.sunday);
      expect(m.when.hour, 17);
      expect(m.body, contains('4 of 8'));
    });

    test('digest is weekly on Sunday 18:00', () {
      final out = plan();
      final d = out.firstWhere((r) => r.key == 'digest_weekly');
      expect(d.weekly, isTrue);
      expect(d.when.weekday, DateTime.sunday);
      expect(d.when.hour, 18);
    });

    test('meeting reminder lands the evening before day 25', () {
      final out = plan();
      final m = out.firstWhere((r) => r.key.startsWith('meeting_'));
      // Now Sep 21 → day 25 is still ahead this month → meeting Sep 25,
      // reminder Sep 24 18:00.
      expect(m.when.day, 24);
      expect(m.when.month, 9);
      expect(m.when.hour, 18);
    });
  });

  group('planner — quiet hours, gating, extras, cap (J3)', () {
    test('reminders inside the DND window slide to its end', () {
      const quietCfg = NotifyConfig(
        enabled: true,
        allowed: {
          ReminderCategory.budget,
          ReminderCategory.bills,
          ReminderCategory.kids,
          ReminderCategory.circle,
          ReminderCategory.goals,
          ReminderCategory.meeting,
          ReminderCategory.digest,
        },
        quietStart: 18,
        quietEnd: 9,
      );
      final env = Envelope(
        id: 'e_x',
        name: 'Groceries',
        emoji: 'cart',
        limit: Money.fromMajor(100, Currency.usd),
      );
      final out = plan(
        cfg: quietCfg,
        envelopes: [
          EnvelopeHealth(
            envelope: env,
            limit: Money.fromMajor(100, Currency.usd),
            spent: Money.fromMajor(85, Currency.usd),
            cycleStart: now,
          ),
        ],
      );
      final b = out.firstWhere((r) => r.key.startsWith('budget_'));
      // 18:30 is inside 18→9 quiet → pushed to 09:00 the next day.
      expect(b.when.hour, 9);
      expect(b.when.isAfter(now), isTrue);
    });

    test('master off → empty plan', () {
      final out = plan(
        cfg: const NotifyConfig(enabled: false, allowed: {
          ReminderCategory.bills,
          ReminderCategory.budget,
          ReminderCategory.kids,
          ReminderCategory.circle,
          ReminderCategory.goals,
          ReminderCategory.meeting,
          ReminderCategory.digest,
        }),
        recurring: [rule('rc_x', now)],
      );
      expect(out, isEmpty);
    });

    test('category switched off → that category stays quiet', () {
      final noBills = NotifyConfig(
        enabled: true,
        allowed: {
          ReminderCategory.budget,
          ReminderCategory.kids,
          ReminderCategory.circle,
          ReminderCategory.goals,
          ReminderCategory.meeting,
          ReminderCategory.digest,
        },
      );
      final out = plan(cfg: noBills, recurring: [rule('rc_x', now)]);
      expect(out.where((r) => r.category == ReminderCategory.bills), isEmpty);
    });

    test('event extras merge in; expired extras drop out', () {
      final out = plan(
        extra: [
          Reminder(
            key: 'milestone_g_50',
            category: ReminderCategory.goals,
            title: 'Halfway!',
            body: 'Keep going',
            when: now.add(const Duration(minutes: 2)),
          ),
          Reminder(
            key: 'stale',
            category: ReminderCategory.goals,
            title: 'Old',
            body: 'Expired',
            when: now.subtract(const Duration(hours: 2)),
          ),
        ],
      );
      expect(out.where((r) => r.key == 'milestone_g_50'), hasLength(1));
      expect(out.where((r) => r.key == 'stale'), isEmpty);
    });

    test('plan is capped at 12 reminders', () {
      final many = [
        for (var i = 0; i < 20; i++)
          rule('rc_$i', now.add(Duration(days: i % 3))),
      ];
      expect(plan(recurring: many).length, lessThanOrEqualTo(12));
    });
  });

  group('notification settings persistence', () {
    late AppDatabase db;

    setUp(() async {
      final raw = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (d, v) async {
          await AppDatabase.createSchema(d);
        },
      );
      db = AppDatabase.wrap(raw);
    });

    tearDown(() async {
      await db.raw.close();
    });

    test('master switch, prefs and quiet hours survive a restart', () async {
      final first = AppState(db: db);
      await first.ready();
      expect(first.notifyEnabled, isTrue);
      first.setRemindersEnabled(false);
      first.setReminderPref(ReminderCategory.digest, false);
      first.setQuietHours(23, 6);
      await first.flushWrites();

      final second = AppState(db: db);
      await second.ready();
      expect(second.notifyEnabled, isFalse);
      expect(second.notifyAllowed.contains(ReminderCategory.digest), isFalse);
      expect(second.quietStart, 23);
      expect(second.quietEnd, 6);
      expect(second.planReminders(), isEmpty, reason: 'disabled → no plan');
    });

    test('goal contribution crossing a band schedules a milestone', () async {
      final s = AppState(db: db);
      await s.ready();
      s.goalTxs.clear();
      final g = s.goal('g_jar')!; // kids' jar, USD target from seed
      final half = Money(g.target.minor ~/ 2, g.target.currency);
      s.contribute(g, half);
      expect(
        s.planReminders().any((r) => r.key.startsWith('milestone_')),
        isTrue,
        reason: 'jumping straight past 25% and 50% fires a nudge',
      );
      await s.flushWrites();
    });

    test('quiet window helpers behave (equal hours = no DND)', () {
      const off = NotifyConfig(enabled: true, allowed: {}, quietStart: 7, quietEnd: 7);
      expect(off.quietEnabled, isFalse);
      expect(off.inQuiet(23), isFalse);
      const wrap = NotifyConfig(enabled: true, allowed: {}, quietStart: 21, quietEnd: 7);
      expect(wrap.inQuiet(22), isTrue);
      expect(wrap.inQuiet(5), isTrue);
      expect(wrap.inQuiet(12), isFalse);
    });
  });
}
