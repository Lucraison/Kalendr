import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  static const String _base = bool.fromEnvironment('dart.vm.product')
      ? 'https://kalendr.nherrera.dev'
      : 'http://10.0.2.2:5115';

  String? _token;

  void setToken(String token) => _token = token;
  void clearToken() => _token = null;

  // Format as naive local ISO (no Z, no offset) so the server stores wall-clock time
  static String iso(DateTime dt) {
    final d = dt.toLocal();
    String p(int n) => n.toString().padLeft(2, '0');
    return '${d.year.toString().padLeft(4, '0')}-${p(d.month)}-${p(d.day)}T${p(d.hour)}:${p(d.minute)}:00';
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<T> _handle<T>(Future<http.Response> Function() call, T Function(dynamic) parse) async {
    try {
      final res = await call().timeout(const Duration(seconds: 10));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        if (res.body.isEmpty) return parse(null);
        return parse(jsonDecode(res.body));
      }
      String msg;
      if (res.statusCode == 401) {
        msg = 'Wrong username or password.';
      } else {
        msg = 'Error ${res.statusCode}';
        try {
          final body = jsonDecode(res.body);
          msg = body['message'] ?? body['title'] ?? msg;
        } catch (_) {
          if (res.statusCode == 409) msg = 'Already in use.';
        }
      }
      throw ApiException(msg);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Error: ${e.runtimeType}: $e');
    }
  }

  Future<AuthResponse> register(String username, String email, String password) =>
      _handle(() => http.post(Uri.parse('$_base/api/auth/register'),
          headers: _headers, body: jsonEncode({'username': username, 'email': email, 'password': password})),
          (j) => AuthResponse.fromJson(j));

  Future<AuthResponse> login(String username, String password) =>
      _handle(() => http.post(Uri.parse('$_base/api/auth/login'),
          headers: _headers, body: jsonEncode({'username': username, 'password': password})),
          (j) => AuthResponse.fromJson(j));

  Future<List<Group>> getGroups() =>
      _handle(() => http.get(Uri.parse('$_base/api/groups'), headers: _headers),
          (j) => (j as List).map((g) => Group.fromJson(g)).toList());

  Future<Group> createGroup(String name) =>
      _handle(() => http.post(Uri.parse('$_base/api/groups'),
          headers: _headers, body: jsonEncode({'name': name})),
          (j) => Group.fromJson(j));

  Future<Group> joinGroup(String inviteCode) =>
      _handle(() => http.post(Uri.parse('$_base/api/groups/join'),
          headers: _headers, body: jsonEncode({'inviteCode': inviteCode})),
          (j) => Group.fromJson(j));

  Future<CalendarEvent> getEvent(String eventId) =>
      _handle(() => http.get(Uri.parse('$_base/api/events/$eventId'), headers: _headers),
          (j) => CalendarEvent.fromJson(j));

  Future<List<CalendarEvent>> getEvents(String groupId, {DateTime? from, DateTime? to}) {
    final params = <String, String>{};
    if (from != null) params['from'] = iso(from);
    if (to != null) params['to'] = iso(to);
    final uri = Uri.parse('$_base/api/events/group/$groupId')
        .replace(queryParameters: params.isEmpty ? null : params);
    return _handle(() => http.get(uri, headers: _headers),
        (j) => (j as List).map((e) => CalendarEvent.fromJson(e)).toList());
  }

  Future<List<CalendarEvent>> getPersonalEvents({DateTime? from, DateTime? to}) {
    final params = <String, String>{};
    if (from != null) params['from'] = iso(from);
    if (to != null) params['to'] = iso(to);
    final uri = Uri.parse('$_base/api/events/personal')
        .replace(queryParameters: params.isEmpty ? null : params);
    return _handle(() => http.get(uri, headers: _headers),
        (j) => (j as List).map((e) => CalendarEvent.fromJson(e)).toList());
  }

  Future<CalendarEvent> createEvent(String? groupId, String title, String? description,
      DateTime startTime, DateTime endTime, bool isAllDay, {String? color, List<String>? sharedGroupIds}) =>
      _handle(() => http.post(Uri.parse('$_base/api/events'),
          headers: _headers,
          body: jsonEncode({
            'groupId': groupId,
            'title': title,
            'description': description,
            'startTime': iso(startTime),
            'endTime': iso(endTime),
            'isWorkHours': isAllDay,
            'color': color,
            'sharedGroupIds': sharedGroupIds,
          })),
          (j) => CalendarEvent.fromJson(j));

  Future<List<CalendarEvent>> createEventsBatch(
      String? groupId, List<Map<String, dynamic>> occurrences) =>
      _handle(
        () => http.post(Uri.parse('$_base/api/events/batch'),
            headers: _headers,
            body: jsonEncode({'events': occurrences})),
        (j) => (j as List).map((e) => CalendarEvent.fromJson(e)).toList(),
      );

  Future<CalendarEvent> updateEvent(String eventId, String title, String? description,
      DateTime startTime, DateTime endTime, bool isAllDay, {String? color, List<String>? sharedGroupIds}) =>
      _handle(() => http.put(Uri.parse('$_base/api/events/$eventId'),
          headers: _headers,
          body: jsonEncode({
            'title': title,
            'description': description,
            'startTime': iso(startTime),
            'endTime': iso(endTime),
            'isWorkHours': isAllDay,
            'color': color,
            'sharedGroupIds': sharedGroupIds,
          })),
          (j) => CalendarEvent.fromJson(j));

  Future<int> updateSeries(String title, String? groupId, int startHour, int startMinute,
      int durationMinutes, bool isAllDay, {String? color, String? description, List<String>? sharedGroupIds}) =>
      _handle(() => http.post(Uri.parse('$_base/api/events/update-series'),
          headers: _headers,
          body: jsonEncode({
            'title': title,
            'groupId': groupId,
            'startHour': startHour,
            'startMinute': startMinute,
            'durationMinutes': durationMinutes,
            'isWorkHours': isAllDay,
            'color': color,
            'description': description,
            'sharedGroupIds': sharedGroupIds,
          })),
          (j) => (j['updated'] as int?) ?? 0);

  Future<void> patchEventMetadata(String eventId, String title, String? description,
      {String? color, List<String>? sharedGroupIds}) =>
      _handle(() => http.patch(Uri.parse('$_base/api/events/$eventId/metadata'),
          headers: _headers,
          body: jsonEncode({
            'title': title,
            'description': description,
            'color': color,
            'sharedGroupIds': sharedGroupIds,
          })),
          (_) => null);

  Future<void> deleteEvent(String? groupId, String eventId) =>
      _handle(() => http.delete(Uri.parse('$_base/api/events/$eventId'), headers: _headers),
          (_) => null);

  Future<int> deleteEventSeries(String title, String? groupId) {
    final params = <String, String>{'title': title};
    if (groupId != null) params['groupId'] = groupId;
    final uri = Uri.parse('$_base/api/events/delete-series').replace(queryParameters: params);
    return _handle(() => http.delete(uri, headers: _headers),
        (j) => (j['deleted'] as int?) ?? 0);
  }

  Future<int> updateRecurrenceSeries(String recurrenceId, {
    required String title,
    String? description,
    String? color,
    List<String>? sharedGroupIds,
    int? startHour,
    int? startMinute,
    int? durationMinutes,
  }) =>
      _handle(() => http.put(Uri.parse('$_base/api/events/series/$recurrenceId'),
          headers: _headers,
          body: jsonEncode({
            'title': title,
            'description': description,
            'color': color,
            'sharedGroupIds': sharedGroupIds,
            'startHour': startHour,
            'startMinute': startMinute,
            'durationMinutes': durationMinutes,
          })),
          (j) => (j['updated'] as int?) ?? 0);

  Future<int> deleteRecurrenceSeries(String recurrenceId) =>
      _handle(() => http.delete(Uri.parse('$_base/api/events/series/$recurrenceId'), headers: _headers),
          (j) => (j['deleted'] as int?) ?? 0);

  Future<List<EventRsvp>> getRsvps(String eventId) =>
      _handle(() => http.get(Uri.parse('$_base/api/events/$eventId/rsvps'), headers: _headers),
          (j) => (j as List).map((r) => EventRsvp.fromJson(r)).toList());

  Future<EventRsvp?> setRsvp(String eventId, String status) =>
      _handle(() => http.post(Uri.parse('$_base/api/events/$eventId/rsvp'),
          headers: _headers, body: jsonEncode({'status': status})),
          (j) => j != null ? EventRsvp.fromJson(j) : null);

  Future<List<Reaction>> getReactions(String eventId) =>
      _handle(() => http.get(Uri.parse('$_base/api/events/$eventId/reactions'), headers: _headers),
          (j) => (j as List).map((r) => Reaction.fromJson(r)).toList());

  Future<Reaction?> toggleReaction(String eventId, String emoji) =>
      _handle(() => http.post(Uri.parse('$_base/api/events/$eventId/reactions'),
          headers: _headers, body: jsonEncode({'emoji': emoji})),
          (j) => j != null ? Reaction.fromJson(j) : null);

  Future<void> updateMemberColor(String groupId, String color) =>
      _handle(() => http.patch(Uri.parse('$_base/api/groups/$groupId/color'),
          headers: _headers, body: jsonEncode({'color': color})),
          (_) => null);

  Future<void> renameGroup(String groupId, String name) =>
      _handle(() => http.patch(Uri.parse('$_base/api/groups/$groupId/rename'),
          headers: _headers, body: jsonEncode({'name': name})),
          (_) => null);

  Future<void> kickMember(String groupId, String userId) =>
      _handle(() => http.delete(Uri.parse('$_base/api/groups/$groupId/members/$userId'), headers: _headers),
          (_) => null);

  Future<void> transferOwnership(String groupId, String userId) =>
      _handle(() => http.post(Uri.parse('$_base/api/groups/$groupId/transfer/$userId'), headers: _headers),
          (_) => null);

  Future<void> leaveGroup(String groupId) =>
      _handle(() => http.delete(Uri.parse('$_base/api/groups/$groupId/leave'), headers: _headers),
          (_) => null);

  // Notifications
  Future<List<AppNotification>> getNotifications() =>
      _handle(() => http.get(Uri.parse('$_base/api/notifications'), headers: _headers),
          (j) => (j as List).map((n) => AppNotification.fromJson(n)).toList());

  Future<void> markAllRead() =>
      _handle(() => http.post(Uri.parse('$_base/api/notifications/mark-read'), headers: _headers),
          (_) => null);

  Future<void> deleteNotification(String id) =>
      _handle(() => http.delete(Uri.parse('$_base/api/notifications/$id'), headers: _headers),
          (_) => null);

  // Comments
  Future<List<EventComment>> getComments(String eventId) =>
      _handle(() => http.get(Uri.parse('$_base/api/events/$eventId/comments'), headers: _headers),
          (j) => (j as List).map((c) => EventComment.fromJson(c)).toList());

  Future<EventComment> addComment(String eventId, String content) =>
      _handle(() => http.post(Uri.parse('$_base/api/events/$eventId/comments'),
          headers: _headers, body: jsonEncode({'content': content})),
          (j) => EventComment.fromJson(j));

  Future<void> deleteComment(String commentId) =>
      _handle(() => http.delete(Uri.parse('$_base/api/events/comments/$commentId'), headers: _headers),
          (_) => null);

  Future<void> changePassword(String currentPassword, String newPassword) =>
      _handle(() => http.patch(Uri.parse('$_base/api/auth/password'),
          headers: _headers, body: jsonEncode({'currentPassword': currentPassword, 'newPassword': newPassword})),
          (_) => null);

  Future<void> changeEmail(String currentPassword, String newEmail) =>
      _handle(() => http.patch(Uri.parse('$_base/api/auth/email'),
          headers: _headers, body: jsonEncode({'currentPassword': currentPassword, 'newEmail': newEmail})),
          (_) => null);

  Future<String> forgotPassword(String username) =>
      _handle(() => http.post(Uri.parse('$_base/api/auth/forgot-password'),
          headers: _headers, body: jsonEncode({'username': username})),
          (j) => (j as Map<String, dynamic>)['maskedEmail'] as String? ?? '');

  Future<void> resetPassword(String username, String code, String newPassword) =>
      _handle(() => http.post(Uri.parse('$_base/api/auth/reset-password'),
          headers: _headers, body: jsonEncode({'username': username, 'code': code, 'newPassword': newPassword})),
          (_) => null);

  // Account
  Future<void> deleteAccount() =>
      _handle(() => http.delete(Uri.parse('$_base/api/auth/account'), headers: _headers),
          (_) => null);
}
