import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Default household timezone for Mhuri family spaces (Harare, CAT UTC+02:00).
const String kDefaultHouseholdTimezone = 'Africa/Harare';

/// Curated household timezones for Southern/East/West Africa and major
/// diaspora hubs. Any valid IANA timezone synced from the server is also
/// supported even if not in this quick-pick list.
const List<({String id, String label})> kHouseholdTimezoneOptions = [
  (id: 'Africa/Harare', label: 'Harare (CAT · UTC+02:00)'),
  (id: 'Africa/Johannesburg', label: 'Johannesburg (SAST · UTC+02:00)'),
  (id: 'Africa/Gaborone', label: 'Gaborone (CAT · UTC+02:00)'),
  (id: 'Africa/Lusaka', label: 'Lusaka (CAT · UTC+02:00)'),
  (id: 'Africa/Nairobi', label: 'Nairobi (EAT · UTC+03:00)'),
  (id: 'Africa/Lagos', label: 'Lagos (WAT · UTC+01:00)'),
  (id: 'Europe/London', label: 'London (GMT / BST)'),
  (id: 'Europe/Dublin', label: 'Dublin (GMT / IST)'),
  (id: 'Europe/Paris', label: 'Paris / Central Europe (CET / CEST)'),
  (id: 'Asia/Dubai', label: 'Dubai (GST · UTC+04:00)'),
  (id: 'America/New_York', label: 'New York (ET)'),
  (id: 'America/Toronto', label: 'Toronto (ET)'),
  (id: 'America/Chicago', label: 'Chicago (CT)'),
  (id: 'America/Los_Angeles', label: 'Los Angeles (PT)'),
  (id: 'Australia/Perth', label: 'Perth (AWST · UTC+08:00)'),
  (id: 'Australia/Sydney', label: 'Sydney (AEST / AEDT)'),
  (id: 'Pacific/Auckland', label: 'Auckland (NZST / NZDT)'),
  (id: 'UTC', label: 'UTC'),
];

/// Pure-Dart IANA timezone anchoring for household payday cycles, budget
/// rollovers, and recurring bill windows.
///
/// When a family space sets `householdTimezone` (e.g. `Africa/Harare`), every
/// member device — whether in Harare, London, Johannesburg, New York, or
/// Sydney — computes the exact same cycle start instant and calendar date.
class HouseholdTimezone {
  HouseholdTimezone._();

  static bool _initialized = false;
  static Map<String, String>? _lowercaseIndex;

  static void ensureInitialized() {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    _lowercaseIndex = {
      for (final key in tz.timeZoneDatabase.locations.keys)
        key.toLowerCase(): key,
    };
    _initialized = true;
  }

  /// Returns true when [timezoneId] is a recognized IANA timezone identifier.
  static bool isValid(String? timezoneId) {
    final trimmed = timezoneId?.trim() ?? '';
    if (trimmed.isEmpty) return false;
    ensureInitialized();
    return tz.timeZoneDatabase.locations.containsKey(trimmed) ||
        (_lowercaseIndex?.containsKey(trimmed.toLowerCase()) ?? false);
  }

  /// Canonicalizes [timezoneId] to a valid IANA name, defaulting to
  /// [kDefaultHouseholdTimezone] (`Africa/Harare`) when null, empty, or
  /// unrecognized.
  static String normalize(String? timezoneId) {
    final trimmed = timezoneId?.trim() ?? '';
    if (trimmed.isEmpty) return kDefaultHouseholdTimezone;
    ensureInitialized();
    if (tz.timeZoneDatabase.locations.containsKey(trimmed)) {
      return trimmed;
    }
    final canonical = _lowercaseIndex?[trimmed.toLowerCase()];
    return canonical ?? kDefaultHouseholdTimezone;
  }

  /// Resolves a [tz.Location] when [timezoneId] is configured; returns `null`
  /// when [timezoneId] is null or empty so unconfigured local/test instances
  /// preserve device-local [DateTime] semantics.
  static tz.Location? tryLocation(String? timezoneId) {
    final trimmed = timezoneId?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    ensureInitialized();
    final canonical = normalize(trimmed);
    return tz.getLocation(canonical);
  }

  /// Friendly human-readable label for Settings UI.
  static String displayLabel(String? timezoneId) {
    final canonical = normalize(timezoneId);
    for (final opt in kHouseholdTimezoneOptions) {
      if (opt.id == canonical) return opt.label;
    }
    return canonical.replaceAll('_', ' ');
  }

  /// Converts [instant] into the household's wall-clock [DateTime] (preserving
  /// the underlying UTC epoch instant while exposing `.year`/`.month`/`.day`
  /// in the household timezone).
  static DateTime wallNow(DateTime instant, String? timezoneId) {
    final loc = tryLocation(timezoneId);
    if (loc == null) return instant;
    return tz.TZDateTime.from(instant, loc);
  }

  /// Midnight at `(year, month, day)` in [timezoneId] (handling out-of-range
  /// `month` offsets such as `month - 1` or `month + 1` cleanly).
  static DateTime dateAtMidnight(
    int year,
    int month,
    int day,
    String? timezoneId,
  ) {
    final loc = tryLocation(timezoneId);
    if (loc == null) return DateTime(year, month, day);
    return tz.TZDateTime(loc, year, month, day);
  }

  /// Payday cycle boundary for `(year, month)` (supports arbitrary month
  /// offsets like `month - 1` or `month + 1`), clamping [monthStartDay] to the
  /// target month's actual length (`28`/`29`/`30`/`31`) so Day 31 never
  /// overflows into the next month.
  static DateTime cycleDateForMonth(
    int year,
    int month,
    int monthStartDay,
    String? timezoneId,
  ) {
    final totalMonths = year * 12 + (month - 1);
    final normYear = totalMonths ~/ 12;
    final normMonth = (totalMonths % 12) + 1;
    final daysInMonth = DateTime.utc(normYear, normMonth + 1, 0).day;
    final clampedDay = monthStartDay.clamp(1, daysInMonth);
    final loc = tryLocation(timezoneId);
    if (loc == null) {
      return DateTime(normYear, normMonth, clampedDay);
    }
    return tz.TZDateTime(loc, normYear, normMonth, clampedDay);
  }

  /// Exact calendar-day distance from `(from.year, from.month, from.day)` to
  /// `(to.year, to.month, to.day)`, immune to 23h/25h DST transitions.
  static int calendarDaysBetween(DateTime from, DateTime to) {
    final a = DateTime.utc(from.year, from.month, from.day);
    final b = DateTime.utc(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }
}
