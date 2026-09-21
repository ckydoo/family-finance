import '../models/models.dart';
import '../money/money.dart';

/// M5 — smart notifications (spec J2/J3), computed device-side.
///
/// Everything in this file is PURE (no plugin, no platform channels) so the
/// planning logic is unit-testable. [Notifier] owns the actual scheduling.
///
/// Server push (FCM) is deliberately post-8: it needs a Firebase project +
/// Supabase edge functions. Local reminders cover the spec's J2 list for the
/// device they run on.

/// Categories a family member can switch on/off (J3 "choose which alerts
/// you receive").
enum ReminderCategory { bills, budget, kids, circle, goals, meeting, digest }

/// kv storage token for a category (stored CSV in 'notify_prefs').
String categoryKey(ReminderCategory c) => switch (c) {
      ReminderCategory.bills => 'bills',
      ReminderCategory.budget => 'budget',
      ReminderCategory.kids => 'kids',
      ReminderCategory.circle => 'circle',
      ReminderCategory.goals => 'goals',
      ReminderCategory.meeting => 'meeting',
      ReminderCategory.digest => 'digest',
    };

ReminderCategory? categoryFromKey(String key) => switch (key) {
      'bills' => ReminderCategory.bills,
      'budget' => ReminderCategory.budget,
      'kids' => ReminderCategory.kids,
      'circle' => ReminderCategory.circle,
      'goals' => ReminderCategory.goals,
      'meeting' => ReminderCategory.meeting,
      'digest' => ReminderCategory.digest,
      _ => null,
    };

const allCategoryKeys =
    'bills,budget,kids,circle,goals,meeting,digest';

extension ReminderCategoryX on ReminderCategory {
  String get label => switch (this) {
        ReminderCategory.bills => 'Bills due (3 days before)',
        ReminderCategory.budget => 'Envelope 80% & empty warnings',
        ReminderCategory.kids => 'Kids: requests & chore approvals',
        ReminderCategory.circle => 'Savings circle (Sunday)',
        ReminderCategory.goals => 'Goal milestones',
        ReminderCategory.meeting => 'Family meeting day',
        ReminderCategory.digest => 'Weekly digest (Sunday 6pm)',
      };
}

/// One scheduled reminder. [key] is stable (dedupe + notification id).
class Reminder {
  final String key;
  final ReminderCategory category;
  final String title;
  final String body;
  final DateTime when;

  /// Weekly-repeating (digest/savings circle) — uses the plugin's
  /// dayOfWeekAndTime match.
  final bool weekly;

  const Reminder({
    required this.key,
    required this.category,
    required this.title,
    required this.body,
    required this.when,
    this.weekly = false,
  });

  /// Stable 31-bit notification id derived from the key.
  int get id => key.hashCode & 0x7fffffff;

  @override
  bool operator ==(Object other) =>
      other is Reminder &&
      other.key == key &&
      other.weekly == weekly &&
      other.title == title &&
      other.body == body &&
      other.when.millisecondsSinceEpoch == when.millisecondsSinceEpoch;

  @override
  int get hashCode =>
      Object.hash(key, when.millisecondsSinceEpoch, weekly, title, body);
}

/// User's notification configuration (J3): master switch, per-category
/// prefs, and the DND window. Times are device-local hours 0..23; equal
/// start/end disables the window.
class NotifyConfig {
  final bool enabled;
  final Set<ReminderCategory> allowed;
  final int quietStart;
  final int quietEnd;

  const NotifyConfig({
    required this.enabled,
    required this.allowed,
    this.quietStart = 21,
    this.quietEnd = 7,
  });

  bool allows(ReminderCategory c) => enabled && allowed.contains(c);

  bool get quietEnabled => quietStart != quietEnd;

  bool inQuiet(int hour) {
    if (!quietEnabled) return false;
    return quietStart < quietEnd
        ? (hour >= quietStart && hour < quietEnd)
        : (hour >= quietStart || hour < quietEnd);
  }
}

/// One envelope's position in the current cycle — planner input so the
/// pure planner can warn at 80%/100% of the (cycle-aware) limit.
class EnvelopeHealth {
  final Envelope envelope;
  final Money limit;
  final Money spent;
  final DateTime cycleStart;

  const EnvelopeHealth({
    required this.envelope,
    required this.limit,
    required this.spent,
    required this.cycleStart,
  });
}

/// Computes the reminder list to schedule right now (J2's seven alerts:
/// bill due 3 days, budget 80%/empty, kid request, chore confirm, savings circle
/// turn, meeting day, weekly Sunday digest — plus event extras like goal
/// milestones pushed in by [extra]).
class ReminderPlanner {
  ReminderPlanner._();

  static const _maxReminders = 12;

  static List<Reminder> plan({
    required DateTime now,
    required NotifyConfig config,
    required List<RecurringRule> recurring,
    required List<EnvelopeHealth> envelopes,
    required List<Chore> chores,
    required List<KidRequest> requests,
    required SavingsCircle? circle,
    required Map<String, String> memberNames,
    required int monthStartDay,
    List<Reminder> extra = const [],
  }) {
    if (!config.enabled) return const [];
    final out = <Reminder>[];

    // 1. Bills due within 3 days (C7 + J2) — morning of the due day.
    if (config.allows(ReminderCategory.bills)) {
      final dueSoon = recurring.where((r) {
        if (!r.active) return false;
        final today = DateTime(now.year, now.month, now.day);
        final overdue = r.nextDue.isBefore(today);
        if (overdue) return true;
        final within3 = r.nextDue
            .isBefore(today.add(const Duration(days: 3)));
        return within3;
      }).toList()
        ..sort((a, b) => a.nextDue.compareTo(b.nextDue));
      for (final r in dueSoon.take(4)) {
        final today = DateTime(now.year, now.month, now.day);
        final overdue = r.nextDue.isBefore(today);
        out.add(Reminder(
          key:
              'bill_${r.id}${overdue ? '_overdue' : '_${_dayKey(r.nextDue)}'}',
          category: ReminderCategory.bills,
          title: '${r.name} — ${r.amount.text}',
          body: overdue
              ? 'This one is due now — post it from Home when you pay it.'
              : 'Due this ${r.frequency == Frequency.weekly ? 'week' : 'month'}. '
                  'Review & post when it\'s paid.',
          when: overdue
              ? now.add(const Duration(minutes: 10))
              : _atHour(r.nextDue, 9),
        ));
      }
    }

    // 2. Budget warnings (J2): envelope at 80% or used up this cycle.
    if (config.allows(ReminderCategory.budget)) {
      for (final h in envelopes) {
        if (h.limit.minor <= 0) continue;
        final ratio = h.spent.minor / h.limit.minor;
        if (ratio < 0.8) continue;
        final empty = ratio >= 1;
        out.add(Reminder(
          key: 'budget_${h.envelope.id}_${_dayKey(h.cycleStart)}',
          category: ReminderCategory.budget,
          title: empty
              ? '${h.envelope.emoji} ${h.envelope.name} is used up'
              : '${h.envelope.emoji} ${h.envelope.name} is 80% spent',
          body: empty
              ? 'The envelope reached its limit this cycle — decide together '
                  'before topping it up.'
              : 'Only a slice of this envelope is left this cycle.',
          when: _atHour(now, 18, minute: 30),
        ));
      }
    }

    // 3. Kids (J2): pending requests + chores waiting for confirmation.
    if (config.allows(ReminderCategory.kids)) {
      for (final r in requests) {
        if (r.state != RequestState.pending) continue;
        out.add(Reminder(
          key: 'kid_${r.id}',
          category: ReminderCategory.kids,
          title: '${memberNames[r.kidId] ?? 'A kid'} is waiting on an answer',
          body: '${r.amount.text} — ${r.reason}. Approve or decline it.',
          when: now.add(const Duration(minutes: 2)),
        ));
      }
      for (final c in chores) {
        if (c.state != ChoreState.waiting) continue;
        out.add(Reminder(
          key: 'chore_${c.id}',
          category: ReminderCategory.kids,
          title: '"${c.name}" is done — confirm it',
          body: 'A chore is waiting for your ⭐ confirmation.',
          when: now.add(const Duration(minutes: 30)),
        ));
      }
    }

    // 4. Savings circle turn (E4/J2) — Sunday 5pm while the round is open
    //    (the tracker has no collection dates yet, so a weekly check-in).
    if (config.allows(ReminderCategory.circle) &&
        circle != null &&
        circle.currentRound <= circle.totalRounds) {
      out.add(Reminder(
        key: 'circle_weekly',
        category: ReminderCategory.circle,
        title:
            '🔄 Savings circle — ${memberNames[circle.nextCollector] ?? 'next up'} '
            'collects this round',
        body: 'Round ${circle.currentRound} of ${circle.totalRounds}. '
            'Mark contributions in Savings.',
        when: _nextSundayAt(now, 17),
        weekly: true,
      ));
    }

    // 5. Family meeting (I4) — the evening before the new cycle starts.
    if (config.allows(ReminderCategory.meeting)) {
      final day = monthStartDay < 1
          ? 1
          : (monthStartDay > 28 ? 28 : monthStartDay);
      var meeting = DateTime(now.year, now.month, day);
      if (!meeting.isAfter(now)) {
        meeting = DateTime(now.year, now.month + 1, day);
      }
      out.add(Reminder(
        key: 'meeting_${_dayKey(meeting)}',
        category: ReminderCategory.meeting,
        title: '👨🏾‍👩🏾‍👧🏾 Family meeting tomorrow',
        body: 'The guided agenda is ready — 15 minutes to align next month.',
        when: _atHour(meeting.subtract(const Duration(days: 1)), 18),
      ));
    }

    // 6. Weekly family digest — Sunday 6pm (J2).
    if (config.allows(ReminderCategory.digest)) {
      out.add(Reminder(
        key: 'digest_weekly',
        category: ReminderCategory.digest,
        title: "📊 Weekly family digest",
        body: "Five minutes together over this week's money.",
        when: _nextSundayAt(now, 18),
        weekly: true,
      ));
    }

    // 7. Event extras (goal milestones, kid answers) — already instant.
    for (final r in extra) {
      if (!config.allows(r.category)) continue;
      out.add(r);
    }

    final scheduled = <Reminder>[];
    for (final r in out) {
      final when = _shiftQuiet(config, r.when);
      if (!when.isAfter(now)) continue;
      scheduled.add(Reminder(
        key: r.key,
        category: r.category,
        title: r.title,
        body: r.body,
        when: when,
        weekly: r.weekly,
      ));
    }
    scheduled.sort((a, b) => a.when.compareTo(b.when));
    return scheduled.take(_maxReminders).toList();
  }

  static DateTime _atHour(DateTime day, int hour, {int minute = 0}) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  static String _dayKey(DateTime d) =>
      (d.millisecondsSinceEpoch ~/ 86400000).toString();

  static DateTime _nextSundayAt(DateTime now, int hour) {
    var d = _atHour(now, hour);
    d = d.add(Duration(days: (DateTime.sunday - d.weekday) % 7));
    if (!d.isAfter(now)) d = d.add(const Duration(days: 7));
    return d;
  }

  /// J3 quiet hours: anything landing inside the DND window slides to the
  /// window's end (same day if still ahead, else the next day).
  static DateTime _shiftQuiet(NotifyConfig config, DateTime t) {
    if (!config.inQuiet(t.hour)) return t;
    var shifted = DateTime(t.year, t.month, t.day, config.quietEnd);
    if (!shifted.isAfter(t)) shifted = shifted.add(const Duration(days: 1));
    return shifted;
  }
}
