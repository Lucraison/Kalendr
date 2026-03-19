import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_state.dart';

class AppProvider extends ChangeNotifier {
  final ApiService api = ApiService();
  final AuthState auth = AuthState();

  bool _initialized = false;
  bool get initialized => _initialized;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  bool _notificationsEnabled = true;
  bool get notificationsEnabled => _notificationsEnabled;

  Timer? _notifTimer;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('themeMode');
    if (saved == 'light') _themeMode = ThemeMode.light;
    else if (saved == 'dark') _themeMode = ThemeMode.dark;
    else _themeMode = ThemeMode.system;
    _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
    await auth.load(api);
    _initialized = true;
    notifyListeners();
    if (auth.isLoggedIn) _startPolling();
  }

  void _startPolling() {
    if (!_notificationsEnabled) return;
    _fetchUnreadCount();
    _notifTimer?.cancel();
    _notifTimer = Timer.periodic(const Duration(seconds: 60), (_) => _fetchUnreadCount());
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.name);
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final r = await api.login(email, password);
    await auth.save(r, api, email: email);
    notifyListeners();
    _startPolling();
  }

  Future<void> register(String username, String email, String password) async {
    final r = await api.register(username, email, password);
    await auth.save(r, api, email: email);
    notifyListeners();
    _startPolling();
  }

  Future<void> updateUsername(String username) async {
    final r = await api.updateUsername(username);
    await auth.saveUsername(r.username);
    notifyListeners();
  }

  void refresh() => notifyListeners();

  Future<void> logout() async {
    _notifTimer?.cancel();
    _unreadCount = 0;
    await auth.clear(api);
    notifyListeners();
  }

  @override
  void dispose() {
    _notifTimer?.cancel();
    super.dispose();
  }
}
