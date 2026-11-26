import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/config/app_env.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/core/time/household_timezone.dart';

void main() {
  group('HouseholdTimezone', () {
    test('normalize canonicalizes case and falls back to Africa/Harare', () {
      expect(HouseholdTimezone.normalize('africa/harare'),
          'Africa/Harare');
      expect(HouseholdTimezone.normalize('  Europe/London  '),
          'Europe/London');
      expect(HouseholdTimezone.normalize('Not/AZone'), kDefaultHouseholdTimezone);
      expect(HouseholdTimezone.normalize(''), kDefaultHouseholdTimezone);
      expect(HouseholdTimezone.normalize(null), kDefaultHouseholdTimezone);
    });

    test('isValid accepts real IANA ids and rejects junk', () {
      expect(HouseholdTimezone.isValid('Africa/Harare'), isTrue);
      expect(HouseholdTimezone.isValid('asia/dubai'), isTrue);
      expect(HouseholdTimezone.isValid('Not/AZone'), isFalse);
      expect(HouseholdTimezone.isValid(''), isFalse);
      expect(HouseholdTimezone.isValid(null), isFalse);
    });

    test('displayLabel maps quick-picks and tidies the rest', () {
      expect(HouseholdTimezone.displayLabel('Africa/Harare'),
          contains('Harare'));
      expect(HouseholdTimezone.displayLabel('Europe/London'), contains('London'));
      expect(HouseholdTimezone.displayLabel('Asia/Tokyo'), 'Asia/Tokyo');
    });

    test('wallNow exposes household wall clock while keeping the instant',
        () {
      // 23:30 UTC on Nov 25 = 01:30 CAT on Nov 26.
      final instant = DateTime.utc(2026, 11, 25, 23, 30);
      final wall = HouseholdTimezone.wallNow(instant, 'Africa/Harare');
      expect(wall.year, 2026);
      expect(wall.month, 11);
      expect(wall.day, 26);
      expect(wall.hour, 1);
      expect(wall.minute, 30);
      // The epoch instant is preserved for comparisons.
      expect(wall.millisecondsSinceEpoch, instant.millisecondsSinceEpoch);
    });

    test('cycleDateForMonth clamps day 31 into short months', () {
      final feb = HouseholdTimezone.cycleDateForMonth(
          2026, 2, 31, 'Africa/Harare');
      expect(feb.month, 2);
      expect(feb.day, 28); // 2026 is not a leap year.

      final febLeap = HouseholdTimezone.cycleDateForMonth(
          2028, 2, 31, 'Africa/Harare');
      expect(febLeap.day, 29);

      final apr = HouseholdTimezone.cycleDateForMonth(
          2026, 4, 31, 'Africa/Harare');
      expect(apr.month, 4);
      expect(apr.day, 30);

      // Midnight in the household timezone, not UTC.
      expect(feb.timeZoneOffset, const Duration(hours: 2));
    });

    test('cycleDateForMonth handles month offsets across year boundaries',
        () {
      // month 0 = December of the previous year.
      final dec = HouseholdTimezone.cycleDateForMonth(2026, 0, 25, 'Europe/London');
      expect(dec.year, 2025);
      expect(dec.month, 12);
      expect(dec.day, 25);
    });

    test('calendarDaysBetween stays immune to DST transitions', () {
      // America/New_York springs forward 2026-03-08 (23h day) and falls back
      // 2026-11-01 (25h day). Calendar distance must stay exact.
      final before = HouseholdTimezone.dateAtMidnight(
          2026, 3, 7, 'America/New_York');
      final after = HouseholdTimezone.dateAtMidnight(2026, 3, 9, 'America/New_York');
      expect(HouseholdTimezone.calendarDaysBetween(before, after), 2);

      final oct = HouseholdTimezone.dateAtMidnight(
          2026, 10, 31, 'America/New_York');
      final nov = HouseholdTimezone.dateAtMidnight(
          2026, 11, 2, 'America/New_York');
      expect(HouseholdTimezone.calendarDaysBetween(oct, nov), 2);
    });
  });

  group('Diaspora-safe payday cycles via AppState', () {
    AppState stateWithClock(DateTime Function() clock) =>
        AppState(env: const AppEnv(), clock: clock);

    test('unconfigured state keeps legacy device-local semantics', () {
      final state = stateWithClock(() => DateTime(2026, 11, 25, 9));
      state.monthStartDay = 25;
      expect(state.householdTimezone, isNull);
      expect(state.householdNow, DateTime(2026, 11, 25, 9));
      expect(state.cycleStartFor(DateTime(2026, 11, 20)),
          DateTime(2026, 10, 25));
      expect(state.cycleStartFor(DateTime(2026, 11, 26)),
          DateTime(2026, 11, 25));
    });

    test('a Harare payday cycle on day 31 never overflows into the next month',
        () {
      final state = stateWithClock(() => DateTime.utc(2026, 3, 15, 12));
      state.monthStartDay = 31;
      state.householdTimezone = 'Africa/Harare';

      // Mid-February: the containing cycle started Jan 31.
      final inFeb = state.cycleStartFor(DateTime(2026, 2, 10));
      expect(inFeb.month, 1);
      expect(inFeb.day, 31);

      // Mid-March (before the Mar 31 boundary): the containing cycle still
      // started at the clamped Feb 28 boundary.
      final inMar = state.cycleStartFor(DateTime(2026, 3, 15));
      expect(inMar.month, 2);
      expect(inMar.day, 28);

      // Once the Mar 31 boundary passes, the next cycle is Apr 30 (clamped:
      // April has no day 31).
      final next = state.nextCycleStartFor(DateTime(2026, 3, 31, 12));
      expect(next.month, 4);
      expect(next.day, 30);
    });

    test('members in London and Harare agree on the same cycle boundaries',
        () {
      final state = stateWithClock(
          () => DateTime.utc(2026, 11, 30, 23, 30)); // 01:30 CAT Dec 1.
      state.monthStartDay = 1;
      state.householdTimezone = 'Africa/Harare';

      // Wall clock says December in Harare even though UTC is still November.
      expect(state.householdNow.day, 1);
      expect(state.householdNow.month, 12);

      final start = state.cycleStartFor(state.now);
      expect(start.month, 12);
      expect(start.day, 1);
      // Boundary is midnight CAT (00:00 CAT = 22:00 UTC the day before).
      expect(start.timeZoneOffset, const Duration(hours: 2));

      expect(state.daysUntilNextCycle, 31);
      expect(state.isCycleStartToday, isTrue);
      expect(state.daysLeftInCycle, 31);
    });

    test('cycleStartAtOffset walks clamped history without short-month drift',
        () {
      final state =
          stateWithClock(() => DateTime.utc(2026, 3, 31, 10));
      state.monthStartDay = 31;
      state.householdTimezone = 'Africa/Harare';

      expect(state.cycleStartAtOffset(0).day, 31); // Mar 31.
      final feb = state.cycleStartAtOffset(1);
      expect(feb.month, 2);
      expect(feb.day, 28); // Clamped, NOT Mar 3.
      final jan = state.cycleStartAtOffset(2);
      expect(jan.month, 1);
      expect(jan.day, 31);
    });

    test('month-end review window and pace use household wall clock', () {
      // 2026-11-05 23:30 UTC = 2026-11-06 01:30 CAT → day 5 after a Nov 1 close.
      final state =
          stateWithClock(() => DateTime.utc(2026, 11, 5, 23, 30));
      state.monthStartDay = 1;
      state.householdTimezone = 'Africa/Harare';
      // Wall clock is Nov 6 in Harare; Dec 1 boundary is 25 calendar days out.
      expect(state.householdNow.day, 6);
      expect(state.daysUntilNextCycle, 25);
    });

    test('setCycleSettings persists payday day + timezone together', () async {
      final state = stateWithClock(() => DateTime(2026, 11, 25));
      await state.setCycleSettings(day: 25, timezone: 'europe/london');
      expect(state.monthStartDay, 25);
      expect(state.householdTimezone, 'Europe/London');
      expect(state.effectiveHouseholdTimezone, 'Europe/London');

      await state.setHouseholdTimezone('not/a-zone');
      // Invalid ids never clobber a good setting.
      expect(state.householdTimezone, 'Europe/London');
    });

    test('effective timezone falls back to the server default', () {
      final state = stateWithClock(() => DateTime(2026, 11, 25));
      expect(state.effectiveHouseholdTimezone, kDefaultHouseholdTimezone);
    });
  });
}
