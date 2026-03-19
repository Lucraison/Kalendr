import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import '../widgets/skeleton.dart';
import '../widgets/slide_route.dart';
import 'event_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final notifs = await context.read<AppProvider>().api.getNotifications();
      if (mounted) setState(() => _notifications = notifs);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);

    // Mark all as read
    try {
      await context.read<AppProvider>().api.markAllRead();
      context.read<AppProvider>().clearUnreadCount();
      if (mounted) setState(() { for (final n in _notifications) n.isRead = true; });
    } catch (_) {}
  }

  Future<void> _openEvent(AppNotification notif) async {
    if (notif.eventId == null || notif.groupId == null) return;
    final api = context.read<AppProvider>().api;
    try {
      final results = await Future.wait([
        api.getEvent(notif.eventId!),
        api.getGroups(),
      ]);
      final event = results[0] as CalendarEvent;
      final groups = results[1] as List<Group>;
      final group = groups.firstWhere((g) => g.id == notif.groupId,
          orElse: () => Group(id: notif.groupId!, name: '', inviteCode: '', members: []));
      if (!mounted) return;
      Navigator.push(context, slideRoute(EventDetailScreen(
        event: event,
        group: group,
        color: _groupColor(notif.groupId!),
      )));
    } catch (_) {
      if (mounted) showSnack(context, 'Could not load event');
    }
  }

  Color _groupColor(String groupId) => groupColorFor(groupId);

  Future<void> _delete(AppNotification notif) async {
    try {
      await context.read<AppProvider>().api.deleteNotification(notif.id);
      setState(() => _notifications.removeWhere((n) => n.id == notif.id));
    } catch (_) {}
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KalendrTheme.bg(context),
      body: Column(children: [
        Container(
          color: KalendrTheme.surface(context),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12,
            left: 20, right: 20, bottom: 16,
          ),
          child: Row(children: [
            Text('Notifications', style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w800, color: KalendrTheme.text(context))),
            const Spacer(),
            if (_notifications.isNotEmpty)
              TextButton(
                onPressed: () async {
                  await context.read<AppProvider>().api.markAllRead();
                  setState(() {
                    _notifications.clear();
                  });
                },
                child: Text('Clear all', style: GoogleFonts.nunito(fontSize: 13, color: KalendrTheme.muted(context))),
              ),
          ]),
        ),

        Expanded(
          child: _loading
              ? _buildSkeleton()
              : RefreshIndicator(
                  color: kPrimary,
                  onRefresh: _load,
                  child: _notifications.isEmpty
                      ? ListView(children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                          Center(child: Column(children: [
                            const Text('🔔', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 16),
                            Text("You're all caught up!",
                                style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w700, color: KalendrTheme.text(context))),
                            const SizedBox(height: 4),
                            Text('New events and comments will appear here.',
                                style: GoogleFonts.nunito(fontSize: 14, color: KalendrTheme.muted(context))),
                          ])),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: _notifications.length,
                          itemBuilder: (_, i) => _notifTile(_notifications[i]),
                        ),
                ),
        ),
      ]),
    );
  }

  Widget _notifTile(AppNotification notif) {
    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: const Color(0xFFFFEEEE), borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline_rounded, color: kPrimary, size: 22),
      ),
      onDismissed: (_) => _delete(notif),
      child: GestureDetector(
        onTap: notif.eventId != null ? () => _openEvent(notif) : null,
        child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: KalendrTheme.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: notif.isRead ? null : Border.all(color: kPrimary.withOpacity(0.25)),
          boxShadow: [BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withOpacity(0.25)
                : Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: kPrimary.withOpacity(notif.isRead ? 0.08 : 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              notif.message.contains('commented') ? Icons.chat_bubble_rounded : Icons.event_rounded,
              color: kPrimary.withOpacity(notif.isRead ? 0.5 : 1),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(notif.message,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w700,
                  color: notif.isRead ? KalendrTheme.subtext(context) : KalendrTheme.text(context),
                )),
            const SizedBox(height: 3),
            Text(_relativeTime(notif.createdAt),
                style: GoogleFonts.nunito(fontSize: 12, color: KalendrTheme.muted(context))),
          ])),
          if (!notif.isRead)
            Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 4, left: 8),
                decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle)),
          if (notif.eventId != null)
            Icon(Icons.chevron_right_rounded, size: 16, color: KalendrTheme.muted(context)),
        ]),
      ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: List.generate(5, (i) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: KalendrTheme.surface(context), borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Skeleton(width: 38, height: 38, radius: 19),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Skeleton(width: double.infinity, height: 13, radius: 6),
            const SizedBox(height: 6),
            Skeleton(width: 80, height: 11, radius: 5),
          ])),
        ]),
      )),
    );
  }
}
