import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../firebase_options.dart';
import '../notifications/notifier.dart';
import '../notifications/reminders.dart';

/// Optional Firebase bridge. Builds without Firebase's native configuration
/// still start normally; once `flutterfire configure` supplies it, Messaging
/// and Analytics become active without another code change.
class FirebaseServices {
  FirebaseServices._();

  static bool _ready = false;
  static FirebaseAnalyticsObserver? _observer;
  static String? _boundUserId;
  static StreamSubscription<String>? _tokenSub;
  static StreamSubscription<RemoteMessage>? _messageSub;
  static StreamSubscription<RemoteMessage>? _openedSub;
  static String? _baseUrl;
  static String? _anonKey;
  static Future<String?> Function()? _accessToken;
  static Future<void> Function()? onFamilyUpdate;

  static bool get ready => _ready;

  static List<NavigatorObserver> get navigatorObservers =>
      _observer == null ? const <NavigatorObserver>[] : [_observer!];

  static Future<void> initialize({
    required Future<void> Function(RemoteMessage) backgroundHandler,
  }) async {
    if (kIsWeb) return;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(backgroundHandler);
      _ready = true;
      _observer =
          FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance);
      await Notifier.initialize();
      _messageSub = FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpen);
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) await _onMessageOpen(initial);
    } catch (error) {
      debugPrint('Firebase disabled: native configuration not found ($error)');
    }
  }

  @pragma('vm:entry-point')
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } catch (_) {
      return;
    }
  }

  /// Associates this installation with the signed-in Supabase identity.
  /// No financial values, names, email addresses, or family data enter
  /// Analytics or the device-token record.
  static Future<void> bindUser({
    required String userId,
    required String baseUrl,
    required String anonKey,
    required Future<String?> Function() accessToken,
    required bool notificationsEnabled,
  }) async {
    if (!_ready) return;
    if (_boundUserId == userId && _tokenSub != null) return;
    _boundUserId = userId;
    _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
    _anonKey = anonKey;
    _accessToken = accessToken;
    await FirebaseAnalytics.instance.setUserId(id: userId);
    await FirebaseAnalytics.instance.logLogin(loginMethod: 'supabase');

    if (!notificationsEnabled) return;
    try {
      final permission = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (permission.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) await _registerToken(token);
      await _tokenSub?.cancel();
      _tokenSub =
          FirebaseMessaging.instance.onTokenRefresh.listen(_registerToken);
    } catch (error) {
      debugPrint('Firebase Messaging registration failed: $error');
    }
  }

  static Future<void> unbindUser() async {
    if (!_ready) return;
    await disablePush();
    _boundUserId = null;
    await FirebaseAnalytics.instance.setUserId(id: null);
  }

  static Future<void> disablePush() async {
    if (!_ready) return;
    await _tokenSub?.cancel();
    _tokenSub = null;
    // Invalidating this installation token prevents a signed-out device from
    // receiving pushes addressed to its previous account, and honors the
    // in-app notification master switch immediately.
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  static Future<void> logEvent(String name,
      [Map<String, Object>? parameters]) async {
    if (!_ready) return;
    await FirebaseAnalytics.instance.logEvent(
      name: name,
      parameters: parameters,
    );
  }

  static Future<void> _registerToken(String token) async {
    final base = _baseUrl;
    final key = _anonKey;
    final getAccess = _accessToken;
    if (base == null || key == null || getAccess == null) return;
    final access = await getAccess();
    if (access == null || access.isEmpty) return;
    try {
      await http
          .post(
            Uri.parse('$base/rest/v1/push_device?on_conflict=token'),
            headers: {
              'apikey': key,
              'Authorization': 'Bearer $access',
              'Content-Type': 'application/json',
              'Prefer': 'resolution=merge-duplicates,return=minimal',
            },
            body: '{"token":"${_jsonEscape(token)}",'
                '"platform":"${Platform.isIOS ? 'ios' : 'android'}"}',
          )
          .timeout(const Duration(seconds: 20));
    } catch (error) {
      debugPrint('FCM token registration failed: $error');
    }
  }

  static String _jsonEscape(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n');

  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    await onFamilyUpdate?.call();
    await logEvent(
        'push_received', {'event': message.data['event'] ?? 'unknown'});
    final notification = message.notification;
    if (notification == null) return;
    await Notifier.showNow(Reminder(
      key: message.messageId ?? 'push_${DateTime.now().millisecondsSinceEpoch}',
      category: ReminderCategory.digest,
      title: notification.title ?? 'Mhuri',
      body: notification.body ?? 'Your family has an update.',
      when: DateTime.now(),
    ));
  }

  static Future<void> _onMessageOpen(RemoteMessage message) async {
    await onFamilyUpdate?.call();
    await logEvent('push_open', {'event': message.data['event'] ?? 'unknown'});
  }

  static Future<void> dispose() async {
    await _tokenSub?.cancel();
    await _messageSub?.cancel();
    await _openedSub?.cancel();
  }
}
