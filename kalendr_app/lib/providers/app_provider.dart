import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_state.dart';
import '../services/hub_service.dart';

class AppProvider extends ChangeNotifier {
  final ApiService api = ApiService();
  final AuthState auth = AuthState();
  final HubService hub = HubService();

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
    _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
    await auth.load(api);
    _initialized = true;
    notifyListeners();
    if (auth.isLoggedIn) {
      _startPolling();
      _connectHub();
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

  Future<void> login(String username, String password) async {
    final r = await api.login(username, password);
    await auth.save(r, api);
    notifyListeners();
    _startPolling();
    _connectHub();
  }

  Future<void> register(String username, String email, String password) async {
    final r = await api.register(username, email, password);
    await auth.save(r, api);
    notifyListeners();
    _startPolling();
  }

  Future<void> joinHubGroup(String groupId) => hub.joinGroup(groupId);

  void refresh() => notifyListeners();

  Future<void> logout() async {
    _notifTimer?.cancel();
    _unreadCount = 0;
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
