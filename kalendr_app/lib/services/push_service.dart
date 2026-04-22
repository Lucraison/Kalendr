import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../app_nav.dart';
import '../models/models.dart';
import '../screens/event_detail_screen.dart';
import '../theme.dart';
import 'api_service.dart';

/// Firebase Cloud Messaging wrapper.
///
/// Responsibilities:
///   - On login/app start: request permission, fetch the FCM token,
///     POST it to the backend so the server can push to this device.
///   - While the app is in the foreground, show a local notification when a
///     data-only push arrives (FCM suppresses system notifications for the
///     foreground app; we render one manually).
///   - On tap (any app state — terminated, backgrounded, foreground) deep-link
///     into the event referenced by the push's `eventId` data field.
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
  StreamSubscription<RemoteMessage>? _openedSub;
  String? _currentToken;
  bool _localsInitialized = false;
  bool _tapHandlersAttached = false;

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

      // Attach tap handlers once per process. These fire when the user taps a
      // system-tray notification (backgrounded or terminated app).
      await _attachTapHandlersOnce();
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
    // Clear our cached token regardless of what happens next, so that when a
    // different user logs in on the same device the `token != _currentToken`
    // guard in registerForCurrentUser() doesn't short-circuit and leave the
    // new user without a backend UserDevices row. FCM itself reuses the same
    // device token across users — it's per-install, not per-account.
    _currentToken = null;
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
    await _local.initialize(
      const InitializationSettings(android: androidInit),
      // Foreground tap: the user tapped the local notification we rendered via
      // _showForegroundNotification. Payload is the eventId we stuffed in.
      onDidReceiveNotificationResponse: (response) {
        final eventId = response.payload;
        if (eventId != null && eventId.isNotEmpty) {
          unawaited(_openEvent(eventId));
        }
      },
    );
    _localsInitialized = true;
  }

  Future<void> _attachTapHandlersOnce() async {
    if (_tapHandlersAttached) return;
    _tapHandlersAttached = true;

    // App was terminated and the OS launched it via a notification tap.
    // getInitialMessage returns non-null exactly once per process launch.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      // Defer until after MaterialApp is mounted so navigatorKey.currentState
      // resolves. First-frame callback is reliable here.
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleTap(initial));
    }

    // App was backgrounded and user tapped the notification to resume.
    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
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

    // Stuff the eventId into payload so the tap handler can deep-link.
    final eventId = msg.data['eventId'] as String?;
    await _local.show(msg.hashCode, title, body, details, payload: eventId);
  }

  void _handleTap(RemoteMessage msg) {
    final eventId = msg.data['eventId'] as String?;
    if (eventId == null || eventId.isEmpty) return;
    unawaited(_openEvent(eventId));
  }

  /// Fetch the event (+ its group for colour matching) and push the detail
  /// screen. Mirrors the `_eventColor` logic from notifications_screen so the
  /// accent colour matches what the user sees on the calendar — refactor
  /// candidate: extract this into a shared helper if it ever drifts.
  Future<void> _openEvent(String eventId) async {
    final nav = navigatorKey.currentState;
    if (nav == null) {
      debugPrint('Push tap: navigator not ready, dropping open for event $eventId');
      return;
    }
    try {
      final event = await _api.getEvent(eventId);
      final groups = await _api.getGroups();

      Group? group;
      if (event.groupId != null) {
        for (final g in groups) {
          if (g.id == event.groupId) {
            group = g;
            break;
          }
        }
      }

      final color = _resolveEventColor(event, group);

      await nav.push(MaterialPageRoute(
        builder: (_) => EventDetailScreen(
          event: event,
          group: group,
          color: color,
          availableGroups: groups,
        ),
      ));
    } catch (e) {
      debugPrint('Push tap: failed to open event $eventId: $e');
    }
  }

  Color _resolveEventColor(CalendarEvent e, Group? group) {
    if (e.color != null) return hexToColor(e.color!);
    if (e.isWorkHours) return const Color(0xFF3B82F6);
    if (group != null) {
      for (final m in group.members) {
        if (m.userId == e.createdByUserId) return hexToColor(m.color);
      }
      return groupColorFor(group.id);
    }
    return kPrimary;
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
    _tokenRefreshSub = null;
    _foregroundSub = null;
    _openedSub = null;
  }
}
