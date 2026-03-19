import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'api_service.dart';

class AuthState {
  static const _keyToken = 'token';
  static const _keyUserId = 'userId';
  static const _keyUsername = 'username';
  static const _keyEmail = 'email';
  static const _keyProfilePic = 'profilePic';

  String? token;
  String? userId;
  String? username;
  String? email;
  String? profilePicPath;

  bool get isLoggedIn => token != null;

  String get initials {
    if (username == null || username!.isEmpty) return '?';
    final parts = username!.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return username![0].toUpperCase();
  }

  Future<void> load(ApiService api) async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(_keyToken);
    userId = prefs.getString(_keyUserId);
    username = prefs.getString(_keyUsername);
    email = prefs.getString(_keyEmail);
    profilePicPath = prefs.getString(_keyProfilePic);
    if (token != null) api.setToken(token!);
  }

  Future<void> save(AuthResponse r, ApiService api, {String? email}) async {
    token = r.token;
    userId = r.userId;
    username = r.username;
    if (email != null) this.email = email;
    api.setToken(r.token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, r.token);
    await prefs.setString(_keyUserId, r.userId);
    await prefs.setString(_keyUsername, r.username);
    if (email != null) await prefs.setString(_keyEmail, email);
  }

  Future<void> saveUsername(String name) async {
    username = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, name);
  }

  Future<void> saveProfilePic(String path) async {
    profilePicPath = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfilePic, path);
  }

  Future<void> clear(ApiService api) async {
    token = null;
    userId = null;
    username = null;
    api.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
