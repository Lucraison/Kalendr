import 'dart:async';
import 'package:signalr_netcore/signalr_client.dart';
import '../models/models.dart';

class ReactionAddedEvent {
  final String eventId;
  final Reaction reaction;
  ReactionAddedEvent(this.eventId, this.reaction);
}

class ReactionRemovedEvent {
  final String eventId;
  final String reactionId;
  ReactionRemovedEvent(this.eventId, this.reactionId);
}

class HubService {
  static const String _base = bool.fromEnvironment('dart.vm.product')
      ? 'https://kalendr.nherrera.dev'
      : 'http://10.0.2.2:5115';

  HubConnection? _connection;

  final _createdCtrl = StreamController<CalendarEvent>.broadcast();
  final _updatedCtrl = StreamController<CalendarEvent>.broadcast();
  final _deletedCtrl = StreamController<String>.broadcast();
  final _seriesDeletedCtrl = StreamController<String>.broadcast();
  final _reactionAddedCtrl = StreamController<ReactionAddedEvent>.broadcast();
  final _reactionRemovedCtrl = StreamController<ReactionRemovedEvent>.broadcast();

  Stream<CalendarEvent> get onEventCreated => _createdCtrl.stream;
  Stream<CalendarEvent> get onEventUpdated => _updatedCtrl.stream;
  Stream<String> get onEventDeleted => _deletedCtrl.stream;
  Stream<String> get onSeriesDeleted => _seriesDeletedCtrl.stream;
  Stream<ReactionAddedEvent> get onReactionAdded => _reactionAddedCtrl.stream;
  Stream<ReactionRemovedEvent> get onReactionRemoved => _reactionRemovedCtrl.stream;

  Future<void> connect(String token, List<String> groupIds) async {
    await disconnect();

    _connection = HubConnectionBuilder()
        .withUrl(
          '$_base/hubs/calendar',
          options: HttpConnectionOptions(
            accessTokenFactory: () async => token,
          ),
        )
        .withAutomaticReconnect()
        .build();

    _connection!.on('EventCreated', (args) {
      if (args == null || args.isEmpty) return;
      try {
        final event = CalendarEvent.fromJson(args[0] as Map<String, dynamic>);
        _createdCtrl.add(event);
      } catch (_) {}
    });

    _connection!.on('EventUpdated', (args) {
      if (args == null || args.isEmpty) return;
      try {
        final event = CalendarEvent.fromJson(args[0] as Map<String, dynamic>);
        _updatedCtrl.add(event);
      } catch (_) {}
    });

    _connection!.on('EventDeleted', (args) {
      if (args == null || args.isEmpty) return;
      try {
        _deletedCtrl.add(args[0].toString());
      } catch (_) {}
    });

    _connection!.on('SeriesDeleted', (args) {
      if (args == null || args.isEmpty) return;
      try {
        _seriesDeletedCtrl.add(args[0].toString());
      } catch (_) {}
    });

    _connection!.on('ReactionAdded', (args) {
      if (args == null || args.length < 2) return;
      try {
        final eventId = args[0].toString();
        final reaction = Reaction.fromJson(args[1] as Map<String, dynamic>);
        _reactionAddedCtrl.add(ReactionAddedEvent(eventId, reaction));
      } catch (_) {}
    });

    _connection!.on('ReactionRemoved', (args) {
      if (args == null || args.length < 2) return;
      try {
        final eventId = args[0].toString();
        final reactionId = args[1].toString();
        _reactionRemovedCtrl.add(ReactionRemovedEvent(eventId, reactionId));
      } catch (_) {}
    });

    await _connection!.start();

    for (final gid in groupIds) {
      try {
        await _connection!.invoke('JoinGroup', args: [gid]);
      } catch (_) {}
    }
  }

  Future<void> joinGroup(String groupId) async {
    if (_connection?.state != HubConnectionState.Connected) return;
    try {
      await _connection!.invoke('JoinGroup', args: [groupId]);
    } catch (_) {}
  }

  Future<void> disconnect() async {
    try {
      await _connection?.stop();
    } catch (_) {}
    _connection = null;
  }

  void dispose() {
    disconnect();
    _createdCtrl.close();
    _updatedCtrl.close();
    _deletedCtrl.close();
    _seriesDeletedCtrl.close();
    _reactionAddedCtrl.close();
    _reactionRemovedCtrl.close();
  }
}
