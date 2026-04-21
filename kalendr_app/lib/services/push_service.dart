import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';

/// Firebase Cloud Messaging wrapper.
///
/// Responsibilities:
///   - On login/app start: request permission, fetch the FCM token,
///     POST it to the backend so the server can push to this device.
///   - While the app is in the foreground, show a local notification when a
///     data-only push arrives (FCM suppresses system notifications for the
///     foreground app; we render one manually).
///   - On logout: tell the backend to drop this token so pushes stop.
///
/// iOS is not set up yet — we guard `Platform.isAndroid` to avoid surprise
/// work on other platforms.
class PushService {
  PushService(this._api);

  final ApiService _api;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  String? _currentToken;
  bool _localsInitialized = false;

  /// Call after a successful login/register or on app start if already logged in.
  /// Safe to call more than once — we short-circuit if the token hasn't changed.
  Future<void> registerForCurrentUser() async {
    if (!Platform.isAndroid) return;
    try {
      await _ensureLocalsInitialized();
      await _requestPermissionIfNeeded();

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;

      if (token != _currentToken) {
        _currentToken = token;
        await _api.registerFcmToken(token, 'android');
      }

      // If FCM rotates the token while the user is logged in, re-register.
      _tokenRefreshSub ??= FirebaseMessaging.instance.onTokenRefresh.listen((t) async {
        _currentToken = t;
        try {
          await _api.registerFcmToken(t, 'android');
        } catch (e) {
          debugPrint('FCM token refresh registration failed: $e');
        }
      });

      // Show a local notification for pushes that arrive while in foreground.
      _foregroundSub ??= FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    } catch (e) {
      debugPrint('PushService.registerForCurrentUser failed: $e');
    }
  }

  /// Call on logout. Removes the token from the backend so pushes stop routing
  /// to this device for this user. We keep the local FCM token itself — on
  /// next login, we'll re-register it under the new user.
  Future<void> unregisterForCurrentUser() async {
    if (!Platform.isAndroid) return;
    final token = _currentToken ?? await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    try {
      await _api.unregisterFcmToken(token);
    } catch (e) {
      debugPrint('FCM unregister failed (ignoring): $e');
    }
  }

  Future<void> _requestPermissionIfNeeded() async {
    // On Android 13+ this prompts the OS permission dialog the first time.
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _ensureLocalsInitialized() async {
    if (_localsInitialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _local.initialize(const InitializationSettings(android: androidInit));
    _localsInitialized = true;
  }

  Future<void> _showForegroundNotification(RemoteMessage msg) async {
    final notif = msg.notification;
    final title = notif?.title ?? msg.data['title'] as String? ?? 'Chalk';
    final body = notif?.body ?? msg.data['body'] as String? ?? '';
    if (body.isEmpty && notif == null) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'chalk_default',
        'Chalk notifications',
        channelDescription: 'Events, reactions, comments and RSVPs',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _local.show(msg.hashCode, title, body, details);
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();
    _tokenRefreshSub = null;
    _foregroundSub = null;
  }
}
