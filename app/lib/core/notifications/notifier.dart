import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminders.dart';

/// Thin wrapper over flutter_local_notifications (v22 API: all-named
/// parameters). Every call is fire-and-forget safe - a failed schedule or
/// a missing platform channel must never crash the app. On non-phone
/// platforms (desktop/web/tests) this silently no-ops.
class Notifier {
  Notifier._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _inited = false;

  /// Scheduling uses UTC absolute instants, so the device's time zone
  /// database is irrelevant (no flutter_timezone dependency needed).
  static bool get supported =>
      !kIsWeb &&
      Platform.environment['FLUTTER_TEST'] != 'true' &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> _ensureInit() async {
    if (_inited || !supported) return;
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: settings);
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            'mhuri_family_updates',
            'Family updates',
            description: 'Important updates from your family space',
            importance: Importance.high,
          ));
    }
    _inited = true;
  }

  /// Creates notification channels before the first remote message arrives.
  static Future<void> initialize() => _ensureInit();

  /// Requests OS permission and reports whether notifications may be shown.
  static Future<bool> requestPermission() async {
    try {
      await _ensureInit();
      if (!supported) return false;
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await _plugin
                .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin>()
                ?.requestNotificationsPermission() ??
            false;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        return await _plugin
                .resolvePlatformSpecificImplementation<
                    IOSFlutterLocalNotificationsPlugin>()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      }
      return false;
    } catch (e) {
      debugPrint('Notifier.requestPermission: $e');
      return false;
    }
  }

  /// Replace the whole pending schedule with [reminders].
  static Future<void> apply(List<Reminder> reminders) async {
    if (!supported) return;
    try {
      await _ensureInit();
      await _plugin.cancelAll();
      const androidDetails = AndroidNotificationDetails(
        'mhuri_reminders',
        'Reminders',
        channelDescription: 'Family money reminders',
        importance: Importance.max,
        priority: Priority.high,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );
      final nowUtc = tz.TZDateTime.now(tz.UTC);
      for (final r in reminders) {
        final when = tz.TZDateTime.from(r.when.toUtc(), tz.UTC);
        if (!when.isAfter(nowUtc)) continue;
        await _plugin.zonedSchedule(
          id: r.id,
          title: r.title,
          body: r.body,
          scheduledDate: when,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents:
              r.weekly ? DateTimeComponents.dayOfWeekAndTime : null,
        );
      }
    } catch (e) {
      debugPrint('Notifier.apply: $e');
    }
  }

  /// Immediate notification (used by Settings' "send a test" button).
  static Future<bool> showNow(Reminder r) async {
    if (!supported) return false;
    try {
      await _ensureInit();
      const androidDetails = AndroidNotificationDetails(
        'mhuri_family_updates',
        'Family updates',
        channelDescription: 'Messages and important updates from your family',
        importance: Importance.max,
        priority: Priority.high,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );
      await _plugin.show(
        id: r.id,
        title: r.title,
        body: r.body,
        notificationDetails: details,
      );
      return true;
    } catch (e) {
      debugPrint('Notifier.showNow: $e');
      return false;
    }
  }
}
