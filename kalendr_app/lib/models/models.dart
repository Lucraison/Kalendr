class AuthResponse {
  final String token;
  final String userId;
  final String username;

  AuthResponse({required this.token, required this.userId, required this.username});

  factory AuthResponse.fromJson(Map<String, dynamic> j) => AuthResponse(
        token: j['token'],
        userId: j['userId'].toString(),
        username: j['username'],
      );
}

class GroupMember {
  final String userId;
  final String username;
  String color;
  bool isOwner;

  GroupMember({required this.userId, required this.username, required this.color, this.isOwner = false});

  factory GroupMember.fromJson(Map<String, dynamic> j) => GroupMember(
        userId: j['userId'].toString(),
        username: j['username'],
        color: j['color'] ?? '#FF6B6B',
        isOwner: j['isOwner'] ?? false,
      );
}

class Group {
  final String id;
  String name;
  final String inviteCode;
  List<GroupMember> members;

  Group({required this.id, required this.name, required this.inviteCode, required this.members});

  factory Group.fromJson(Map<String, dynamic> j) => Group(
        id: j['id'].toString(),
        name: j['name'],
        inviteCode: j['inviteCode'],
        members: (j['members'] as List).map((m) => GroupMember.fromJson(m)).toList(),
      );
}

class Reaction {
  final String id;
  final String userId;
  final String username;
  final String emoji;

  Reaction({required this.id, required this.userId, required this.username, required this.emoji});

  factory Reaction.fromJson(Map<String, dynamic> j) => Reaction(
        id: j['id'].toString(),
        userId: j['userId'].toString(),
        username: j['username'],
        emoji: j['emoji'],
      );
}

enum RsvpStatus { going, maybe, declined }

class EventRsvp {
  final String userId;
  final String username;
  final RsvpStatus status;

  EventRsvp({required this.userId, required this.username, required this.status});

  factory EventRsvp.fromJson(Map<String, dynamic> j) => EventRsvp(
        userId: j['userId'].toString(),
        username: j['username'],
        status: RsvpStatus.values.firstWhere(
          (s) => s.name == j['status'],
          orElse: () => RsvpStatus.going,
        ),
      );
}

class AppNotification {
  final String id;
  final String message;
  final String? eventId;
  final String? groupId;
  bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.message,
    this.eventId,
    this.groupId,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'].toString(),
        message: j['message'],
        eventId: j['eventId']?.toString(),
        groupId: j['groupId']?.toString(),
        isRead: j['isRead'] ?? false,
        createdAt: DateTime.parse(j['createdAt']).toLocal(),
      );
}

class EventComment {
  final String id;
  final String eventId;
  final String userId;
  final String username;
  final String content;
  final DateTime createdAt;

  EventComment({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.username,
    required this.content,
    required this.createdAt,
  });

  factory EventComment.fromJson(Map<String, dynamic> j) => EventComment(
        id: j['id'].toString(),
        eventId: j['eventId']?.toString() ?? '',
        userId: j['userId'].toString(),
        username: j['username'],
        content: j['content'],
        createdAt: DateTime.parse(j['createdAt']).toLocal(),
      );
}

class CalendarEvent {
  final String id;
  String title;
  String? description;
  DateTime startTime;
  DateTime endTime;
  bool isAllDay;
  bool isWorkHours;
  final String createdByUserId;
  final String createdByUsername;
  final String? groupId;
  String? color;
  List<String> sharedGroupIds;
  final String? recurrenceId;

  CalendarEvent({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    required this.isAllDay,
    this.isWorkHours = false,
    required this.createdByUserId,
    required this.createdByUsername,
    this.groupId,
    this.color,
    this.sharedGroupIds = const [],
    this.recurrenceId,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> j) => CalendarEvent(
        id: j['id'].toString(),
        title: j['title'],
        description: j['description'],
        startTime: DateTime.parse(j['startTime']),
        endTime: DateTime.parse(j['endTime']),
        isAllDay: j['isAllDay'] ?? false,
        isWorkHours: j['isWorkHours'] ?? false,
        createdByUserId: j['createdByUserId'].toString(),
        createdByUsername: j['createdByUsername'],
        groupId: j['groupId']?.toString(),
        color: j['color'],
        sharedGroupIds: (j['sharedGroupIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
        recurrenceId: j['recurrenceId']?.toString(),
      );
}
