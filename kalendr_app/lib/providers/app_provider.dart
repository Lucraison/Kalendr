import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_state.dart';
import '../services/hub_service.dart';
import '../services/push_service.dart';

class AppProvider extends ChangeNotifier {
  final ApiService api = ApiService();
  final AuthState auth = AuthState();
  final HubService hub = HubService();
  late final PushService push = PushService(api);

  bool _initialized = false;
  bool get initialized => _initialized;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  bool _notificationsEnabled = true;
  bool get notificationsEnabled => _notificationsEnabled;

  String _locale = 'en';
  String get locale => _locale;

  bool _use24hFormat = false;
  bool get use24hFormat => _use24hFormat;

  bool _startOnMonday = true;
  bool get startOnMonday => _startOnMonday;

  String formatTime(TimeOfDay t) {
    if (_use24hFormat) {
      final h = t.hour.toString().padLeft(2, '0');
      final m = t.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$m $period';
  }

  /// Format the time portion of a DateTime according to user preference.
  String formatDateTime(DateTime dt) {
    if (_use24hFormat) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour:$m $period';
  }

  Timer? _notifTimer;
  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async => _prefs ??= await SharedPreferences.getInstance();

  Future<void> init() async {
    final prefs = await _getPrefs();
    final saved = prefs.getString('themeMode');
    if (saved == 'light') _themeMode = ThemeMode.light;
    else if (saved == 'dark') _themeMode = ThemeMode.dark;
    else _themeMode = ThemeMode.system;
    _locale = prefs.getString('locale') ?? 'en';
    _use24hFormat = prefs.getBool('use24hFormat') ?? false;
    _startOnMonday = prefs.getBool('startOnMonday') ?? true;
    _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
    await auth.load(api);
    _initialized = true;
    notifyListeners();
    if (auth.isLoggedIn) {
      _startPolling();
      _connectHub();
      // Re-register the FCM token on every app start — cheap, and catches
      // token rotation that happened while the app was closed.
      unawaited(push.registerForCurrentUser());
    }
  }

  Future<void> _connectHub() async {
    try {
      final groups = await api.getGroups();
      final groupIds = groups.map((g) => g.id).toList();
      await hub.connect(auth.token!, groupIds);
    } catch (_) {}
  }

  void _startPolling() {
    if (!_notificationsEnabled) return;
    _fetchUnreadCount();
    _notifTimer?.cancel();
    _notifTimer = Timer.periodic(const Duration(seconds: 60), (_) => _fetchUnreadCount());
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    final prefs = await _getPrefs();
    await prefs.setBool('notificationsEnabled', enabled);
    if (enabled) {
      _startPolling();
    } else {
      _notifTimer?.cancel();
      _unreadCount = 0;
    }
    notifyListeners();
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final notifs = await api.getNotifications();
      final count = notifs.where((n) => !n.isRead).length;
      if (count != _unreadCount) {
        _unreadCount = count;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> refreshNotifications() => _fetchUnreadCount();

  void clearUnreadCount() {
    _unreadCount = 0;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await _getPrefs();
    await prefs.setString('themeMode', mode.name);
    notifyListeners();
  }

  Future<void> setLocale(String lang) async {
    _locale = lang;
    final prefs = await _getPrefs();
    await prefs.setString('locale', lang);
    notifyListeners();
  }

  Future<void> set24hFormat(bool value) async {
    _use24hFormat = value;
    final prefs = await _getPrefs();
    await prefs.setBool('use24hFormat', value);
    notifyListeners();
  }

  Future<void> setStartOnMonday(bool value) async {
    _startOnMonday = value;
    final prefs = await _getPrefs();
    await prefs.setBool('startOnMonday', value);
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    final r = await api.login(username, password);
    await auth.save(r, api);
    notifyListeners();
    _startPolling();
    _connectHub();
    unawaited(push.registerForCurrentUser());
  }

  Future<void> register(String username, String email, String password) async {
    final r = await api.register(username, email, password);
    await auth.save(r, api);
    notifyListeners();
    _startPolling();
    _connectHub();
    unawaited(push.registerForCurrentUser());
  }

  Future<void> joinHubGroup(String groupId) => hub.joinGroup(groupId);

  void refresh() => notifyListeners();

  Future<void> logout() async {
    _notifTimer?.cancel();
    _unreadCount = 0;
    // Unregister BEFORE clearing auth — the backend endpoint requires the
    // JWT to know whose device to remove.
    await push.unregisterForCurrentUser();
    await hub.disconnect();
    await auth.clear(api);
    notifyListeners();
  }

  @override
  void dispose() {
    _notifTimer?.cancel();
    hub.dispose();
    super.dispose();
  }
}
