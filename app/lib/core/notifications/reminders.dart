import '../models/models.dart';
import '../money/money.dart';

/// M5 - smart notifications (spec J2/J3), computed device-side.
///
/// Everything in this file is PURE (no plugin, no platform channels) so the
/// planning logic is unit-testable. [Notifier] owns the actual scheduling.
///
/// Server push (FCM) is deliberately post-8: it needs a Firebase project +
/// Supabase edge functions. Local reminders cover the spec's J2 list for the
/// device they run on.

/// Categories a family member can switch on/off (J3 "choose which alerts
/// you receive").
enum ReminderCategory {
  bills,
  budget,
  kids,
  circle,
  goals,
  contributions,
  shopping,
  family,
}

/// kv storage token for a category (stored CSV in 'notify_prefs').
String categoryKey(ReminderCategory c) => switch (c) {
      ReminderCategory.bills => 'bills',
      ReminderCategory.budget => 'budget',
      ReminderCategory.kids => 'kids',
      ReminderCategory.circle => 'circle',
      ReminderCategory.goals => 'goals',
      ReminderCategory.contributions => 'contributions',
      ReminderCategory.shopping => 'shopping',
      ReminderCategory.family => 'family',
    };

ReminderCategory? categoryFromKey(String key) => switch (key) {
      'bills' => ReminderCategory.bills,
      'budget' => ReminderCategory.budget,
      'kids' => ReminderCategory.kids,
      'circle' => ReminderCategory.circle,
      'goals' => ReminderCategory.goals,
      'contributions' => ReminderCategory.contributions,
      'shopping' => ReminderCategory.shopping,
      'family' => ReminderCategory.family,
      // Upgrade old preferences into their closest useful categories.
      'meeting' => ReminderCategory.family,
      'digest' => ReminderCategory.shopping,
      _ => null,
    };

const allCategoryKeys =
    'bills,budget,kids,circle,goals,contributions,shopping,family';

/// One scheduled reminder. [key] is stable (dedupe + notification id).
class Reminder {
  final String key;
  final ReminderCategory category;
  final String title;
  final String body;
  final DateTime when;

  /// Weekly-repeating (digest/savings circle) - uses the plugin's
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

/// One envelope's position in the current cycle - planner input so the
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

/// Computes reminders from real family records: bills, budget thresholds,
/// requests, chores, an enabled savings circle, and explicit event extras.
/// It deliberately does not invent generic weekly or month-end entries.
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
    List<ContributionCampaign> campaigns = const [],
    List<Reminder> extra = const [],
  }) {
    if (!config.enabled) return const [];
    final out = <Reminder>[];

    // 1. Bills due within 3 days (C7 + J2) - morning of the due day.
    if (config.allows(ReminderCategory.bills)) {
      final dueSoon = recurring.where((r) {
        if (!r.active) return false;
        final today = DateTime(now.year, now.month, now.day);
        final overdue = r.nextDue.isBefore(today);
        if (overdue) return true;
        final within3 = r.nextDue.isBefore(today.add(const Duration(days: 3)));
        return within3;
      }).toList()
        ..sort((a, b) => a.nextDue.compareTo(b.nextDue));
      for (final r in dueSoon.take(4)) {
        final today = DateTime(now.year, now.month, now.day);
        final overdue = r.nextDue.isBefore(today);
        out.add(Reminder(
          key: 'bill_${r.id}${overdue ? '_overdue' : '_${_dayKey(r.nextDue)}'}',
          category: ReminderCategory.bills,
          title: '${r.name} - ${r.amount.text}',
          body: overdue
              ? 'This one is due now - post it from Home when you pay it.'
              : 'Due this ${r.frequency == Frequency.weekly ? 'week' : 'month'}. '
                  'Review & post when it\'s paid.',
          when: overdue ? _nextDailyAt(now, 9) : _atHour(r.nextDue, 9),
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
              ? 'The envelope reached its limit this cycle - decide together '
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
          body: '${r.amount.text} - ${r.reason}. Approve or decline it.',
          when: _nextDailyAt(now, 9),
        ));
      }
      for (final c in chores) {
        if (c.state != ChoreState.waiting) continue;
        out.add(Reminder(
          key: 'chore_${c.id}',
          category: ReminderCategory.kids,
          title: '"${c.name}" is done - confirm it',
          body: 'A chore is waiting for your ⭐ confirmation.',
          when: _nextDailyAt(now, 10),
        ));
      }
    }

    // 4. Savings circle turn (E4/J2) - Sunday 5pm while the round is open
    //    (the tracker has no collection dates yet, so a weekly check-in).
    if (config.allows(ReminderCategory.circle) &&
        circle != null &&
        circle.currentRound <= circle.totalRounds) {
      out.add(Reminder(
        key: 'circle_weekly',
        category: ReminderCategory.circle,
        title:
            '🔄 Savings circle - ${memberNames[circle.nextCollector] ?? 'next up'} '
            'collects this round',
        body: 'Round ${circle.currentRound} of ${circle.totalRounds}. '
            'Mark contributions in Savings.',
        when: _nextSundayAt(now, 17),
        weekly: true,
      ));
    }

    // 5. Contributions: only active campaigns with a real deadline in the
    // next seven days (or already overdue).
    if (config.allows(ReminderCategory.contributions)) {
      final today = DateTime(now.year, now.month, now.day);
      for (final campaign in campaigns.where((c) => c.status == 'active')) {
        final deadline = DateTime(campaign.deadline.year,
            campaign.deadline.month, campaign.deadline.day);
        if (deadline.isAfter(today.add(const Duration(days: 7)))) continue;
        final dueNow = !deadline.isAfter(today);
        out.add(Reminder(
          key: 'contribution_${campaign.id}_${_dayKey(deadline)}',
          category: ReminderCategory.contributions,
          title: dueNow
              ? '${campaign.name} needs attention'
              : '${campaign.name} deadline is approaching',
          body:
              'Target: ${campaign.target.text}. Open Contributions to review what is still outstanding.',
          when: dueNow ? _nextDailyAt(now, 9) : _atHour(deadline, 9),
        ));
      }
    }

    // Event extras (goal milestones, kid answers) are explicit real events.
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

  static DateTime _nextDailyAt(DateTime now, int hour) {
    var result = _atHour(now, hour);
    if (!result.isAfter(now)) result = result.add(const Duration(days: 1));
    return result;
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
