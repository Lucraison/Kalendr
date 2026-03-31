import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import '../widgets/skeleton.dart';
import '../widgets/slide_route.dart';
import '../widgets/type_picker_sheet.dart';
import '../l10n/app_strings.dart';
import 'add_event_sheet.dart';
import 'add_work_schedule_sheet.dart';
import 'event_detail_screen.dart';

class EventsScreen extends StatefulWidget {
  final Group group;
  const EventsScreen({super.key, required this.group});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  List<CalendarEvent> _events = [];
  bool _loading = true;
  String _error = '';
  bool _showPast = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final api = context.read<AppProvider>().api;
      _events = await api.getEvents(widget.group.id);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(CalendarEvent event) async {
    try {
      final api = context.read<AppProvider>().api;
      await api.deleteEvent(widget.group.id, event.id);
      setState(() => _events.removeWhere((e) => e.id == event.id));
    } catch (e) {
      if (mounted) showSnack(context, e.toString());
    }
  }

  Color _headerColor() => groupColorFor(widget.group.id);

  Color _memberColor(String userId) {
    final member = widget.group.members.firstWhere(
      (m) => m.userId == userId,
      orElse: () => GroupMember(userId: userId, username: '', color: '#FF6B6B'),
    );
    return hexToColor(member.color);
  }

  void _showMembers() {
    final color = _headerColor();
    final myPicPath = context.read<AppProvider>().auth.profilePicPath;
    final myId = context.read<AppProvider>().auth.userId;
    final amOwner = widget.group.members.any((m) => m.userId == myId && m.isOwner);

    const palette = [
      '#EF4444', '#F97316', '#EAB308', '#22C55E',
      '#14B8A6', '#3B82F6', '#8B5CF6', '#EC4899',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: BoxDecoration(
            color: KalendrTheme.surface(ctx),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).padding.bottom + 32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Row(children: [
                  Text(ctx.s.members, style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, color: KalendrTheme.text(ctx))),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text('${widget.group.members.length}', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                  ),
                ]),
                const SizedBox(height: 16),
                ...widget.group.members.map((m) {
                  final c = _memberColor(m.userId);
                  final isMe = m.userId == myId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: c.withOpacity(0.15),
                          backgroundImage: isMe && myPicPath != null ? FileImage(File(myPicPath)) : null,
                          child: isMe && myPicPath != null ? null : Text(m.username[0].toUpperCase(),
                              style: TextStyle(fontSize: 15, color: c, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text(m.username, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w600, color: KalendrTheme.text(ctx))),
                            if (m.isOwner) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                child: Text(ctx.s.owner, style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                              ),
                            ],
                          ]),
                          if (isMe)
                            Text(ctx.s.yourColor, style: GoogleFonts.nunito(fontSize: 11, color: KalendrTheme.muted(ctx))),
                        ])),
                        // Owner actions on other members
                        if (amOwner && !isMe) ...[
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert_rounded, size: 18, color: KalendrTheme.muted(ctx)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            onSelected: (action) async {
                              if (action == 'kick') {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    title: Text(context.s.removeMemberConfirm(m.username), style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
                                    content: Text(context.s.rejoinWithInviteCode, style: GoogleFonts.nunito()),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.s.cancel, style: GoogleFonts.nunito())),
                                      TextButton(onPressed: () => Navigator.pop(context, true),
                                          child: Text(context.s.remove, style: GoogleFonts.nunito(color: kPrimary, fontWeight: FontWeight.w700))),
                                    ],
                                  ),
                                );
                                if (confirm != true) return;
                                try {
                                  await context.read<AppProvider>().api.kickMember(widget.group.id, m.userId);
                                  widget.group.members.remove(m);
                                  setState(() {});
                                  setSheet(() {});
                                } catch (e) {
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString()), backgroundColor: kPrimary),
                                  );
                                }
                              } else if (action == 'transfer') {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    title: Text(context.s.transferOwnershipConfirm(m.username), style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
                                    content: Text(context.s.becomeRegularMember, style: GoogleFonts.nunito()),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.s.cancel, style: GoogleFonts.nunito())),
                                      TextButton(onPressed: () => Navigator.pop(context, true),
                                          child: Text(context.s.transfer, style: GoogleFonts.nunito(color: color, fontWeight: FontWeight.w700))),
                                    ],
                                  ),
                                );
                                if (confirm != true) return;
                                try {
                                  await context.read<AppProvider>().api.transferOwnership(widget.group.id, m.userId);
                                  for (final mem in widget.group.members) {
                                    mem.isOwner = mem.userId == m.userId;
                                  }
                                  setState(() {});
                                  setSheet(() {});
                                } catch (e) {
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString()), backgroundColor: kPrimary),
                                  );
                                }
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(value: 'transfer', child: Row(children: [
                                Icon(Icons.swap_horiz_rounded, size: 16, color: color),
                                const SizedBox(width: 8),
                                Text(ctx.s.transferOwnership, style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
                              ])),
                              PopupMenuItem(value: 'kick', child: Row(children: [
                                const Icon(Icons.person_remove_rounded, size: 16, color: kPrimary),
                                const SizedBox(width: 8),
                                Text(ctx.s.removeFromGroup, style: GoogleFonts.nunito(fontWeight: FontWeight.w600, color: kPrimary)),
                              ])),
                            ],
                          ),
                        ],
                      ]),
                      if (isMe) ...[
                        const SizedBox(height: 10),
                        Center(child: Wrap(spacing: 8, runSpacing: 8, children: palette.map((hex) {
                          final col = hexToColor(hex);
                          final selected = m.color.toUpperCase() == hex.toUpperCase();
                          return GestureDetector(
                            onTap: () async {
                              HapticFeedback.selectionClick();
                              await context.read<AppProvider>().api.updateMemberColor(widget.group.id, hex);
                              m.color = hex;
                              setState(() {});
                              setSheet(() {});
                              if (context.mounted) showSnack(context, context.s.colorUpdated, color: col);
                            },
                            child: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: selected ? Border.all(color: col, width: 2.5) : null,
                              ),
                              padding: const EdgeInsets.all(3),
                              child: Container(
                                decoration: BoxDecoration(color: col, shape: BoxShape.circle),
                                child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
                              ),
                            ),
                          );
                        }).toList())),
                        const SizedBox(height: 4),
                      ],
                    ]),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddEvent() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => TypePickerSheet(
        onEvent: () {
          Navigator.pop(context);
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => AddEventSheet(
              groupId: widget.group.id,
              onAdd: (title, desc, start, end, allDay, color, sharedGroupIds) async {
                final api = context.read<AppProvider>().api;
                final e = await api.createEvent(widget.group.id, title, desc, start, end, allDay,
                    color: color, sharedGroupIds: sharedGroupIds.isEmpty ? null : sharedGroupIds);
                if (mounted) setState(() => _events.insert(0, e));
              },
            ),
          );
        },
        onWorkSchedule: () {
          Navigator.pop(context);
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => AddWorkScheduleSheet(
              onAdd: (title, desc, start, end, allDay, sharedGroupIds) async {
                final api = context.read<AppProvider>().api;
                final e = await api.createEvent(widget.group.id, title, desc, start, end, true,
                    color: '#3B82F6', sharedGroupIds: sharedGroupIds.isEmpty ? null : sharedGroupIds);
                if (mounted) setState(() => _events.insert(0, e));
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AppProvider>().auth.userId ?? '';

    return Scaffold(
      backgroundColor: KalendrTheme.bg(context),
      body: Column(
        children: [
          Container(
            color: KalendrTheme.surface(context),
            child: Column(children: [
              Padding(
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 4, left: 4, right: 20, bottom: 12),
                child: Row(children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: KalendrTheme.text(context)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.group.name,
                          style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, color: KalendrTheme.text(context)),
                          overflow: TextOverflow.ellipsis),
                      Text(context.s.memberCount(widget.group.members.length),
                          style: GoogleFonts.nunito(fontSize: 12, color: KalendrTheme.muted(context))),
                    ]),
                  ),
                  GestureDetector(
                    onTap: _showMembers,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _headerColor().withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.people_rounded, color: _headerColor(), size: 16),
                        const SizedBox(width: 5),
                        Text('${widget.group.members.length}',
                            style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: _headerColor())),
                      ]),
                    ),
                  ),
                ]),
              ),
              Container(height: 3, color: _headerColor()),
            ]),
          ),

          Expanded(
            child: RefreshIndicator(
              color: kPrimary,
              onRefresh: _load,
              child: _loading
                  ? _buildSkeleton()
                  : _error.isNotEmpty
                      ? _buildError()
                      : _buildAgenda(currentUserId),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEvent,
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        elevation: 4,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  Widget _buildError() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(child: Column(children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(context.s.couldNotLoadEventsScreen, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: KalendrTheme.text(context))),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(context.s.retry, style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
            style: TextButton.styleFrom(foregroundColor: _headerColor()),
          ),
        ])),
      ],
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      children: List.generate(4, (i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          height: 86,
          decoration: BoxDecoration(
            color: KalendrTheme.surface(context),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(children: [
            Container(width: 5, height: 86, decoration: BoxDecoration(
              color: KalendrTheme.divider(context),
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
            )),
            const SizedBox(width: 16),
            Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Skeleton(width: double.infinity, height: 14, radius: 7),
                const SizedBox(height: 8),
                Skeleton(width: 120, height: 11, radius: 5),
                const SizedBox(height: 6),
                Skeleton(width: 80, height: 11, radius: 5),
              ]),
            )),
          ]),
        ),
      )),
    );
  }

  Widget _buildAgenda(String currentUserId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picPath = context.read<AppProvider>().auth.profilePicPath;

    final sorted = [..._events]..sort((a, b) => a.startTime.compareTo(b.startTime));
    final upcoming = sorted.where((e) => !e.startTime.isBefore(today)).toList();
    final past = sorted.where((e) => e.startTime.isBefore(today)).toList();

    if (sorted.isEmpty) {
      return ListView(children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(child: Column(children: [
          Icon(Icons.calendar_month_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(context.s.noEventsYet, style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w700, color: KalendrTheme.text(context))),
          const SizedBox(height: 4),
          Text(context.s.tapPlusToAdd, style: GoogleFonts.nunito(fontSize: 14, color: KalendrTheme.muted(context))),
        ])),
      ]);
    }

    Map<String, List<CalendarEvent>> groupByDate(List<CalendarEvent> events) {
      final map = <String, List<CalendarEvent>>{};
      for (final e in events) {
        final key = DateFormat('yyyy-MM-dd').format(e.startTime);
        map.putIfAbsent(key, () => []).add(e);
      }
      return map;
    }

    final items = <Widget>[];

    if (past.isNotEmpty) {
      items.add(Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        child: GestureDetector(
          onTap: () => setState(() => _showPast = !_showPast),
          child: Row(children: [
            Icon(_showPast ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                size: 16, color: KalendrTheme.muted(context)),
            const SizedBox(width: 6),
            Text(context.s.pastEvents(past.length),
                style: GoogleFonts.nunito(fontSize: 13, color: KalendrTheme.muted(context), fontWeight: FontWeight.w600)),
          ]),
        ),
      ));
      if (_showPast) {
        final groups = groupByDate(past);
        for (final key in groups.keys) {
          items.add(_dateHeader(groups[key]!.first.startTime, isPast: true));
          for (final e in groups[key]!) {
            final isOwner = e.createdByUserId == currentUserId;
            items.add(_eventCard(e, _memberColor(e.createdByUserId), isOwner, isOwner ? picPath : null));
          }
        }
      }
    }

    if (upcoming.isEmpty) {
      items.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text(context.s.noUpcomingEvents, style: GoogleFonts.nunito(fontSize: 14, color: KalendrTheme.muted(context)))),
      ));
    } else {
      final groups = groupByDate(upcoming);
      for (final key in groups.keys) {
        final isToday = key == DateFormat('yyyy-MM-dd').format(today);
        items.add(_dateHeader(groups[key]!.first.startTime, isToday: isToday));
        for (final e in groups[key]!) {
          final isOwner = e.createdByUserId == currentUserId;
          items.add(_eventCard(e, _memberColor(e.createdByUserId), isOwner, isOwner ? picPath : null));
        }
      }
    }

    items.add(const SizedBox(height: 100));
    return ListView(padding: EdgeInsets.zero, children: items);
  }

  Widget _dateHeader(DateTime dt, {bool isToday = false, bool isPast = false}) {
    final label = isToday ? context.s.today : DateFormat('EEE, MMM d').format(dt);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(children: [
        Text(label, style: GoogleFonts.nunito(
          fontSize: 13, fontWeight: FontWeight.w800,
          color: isToday ? kPrimary : isPast ? KalendrTheme.muted(context) : KalendrTheme.text(context),
        )),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: KalendrTheme.divider(context))),
      ]),
    );
  }

  Widget _eventCard(CalendarEvent e, Color color, bool isOwner, String? picPath) {
    final dateStr = e.isAllDay
        ? DateFormat('EEE, MMM d').format(e.startTime)
        : DateFormat('EEE, MMM d · HH:mm').format(e.startTime);

    return Dismissible(
      key: Key(e.id.toString()),
      direction: isOwner ? DismissDirection.endToStart : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEEEE),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: kPrimary, size: 22),
      ),
      confirmDismiss: (_) async {
        final api = context.read<AppProvider>().api;
        final myId = context.read<AppProvider>().auth.userId ?? '';
        final similar = _events.where((x) =>
            x.id != e.id &&
            x.title == e.title &&
            x.createdByUserId == myId &&
            e.createdByUserId == myId).toList();

        if (similar.isEmpty) {
          return await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(context.s.deleteEvent, style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
              content: Text(context.s.deleteEventTitle(e.title), style: GoogleFonts.nunito()),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.s.cancel, style: GoogleFonts.nunito())),
                TextButton(onPressed: () => Navigator.pop(context, true),
                    child: Text(context.s.delete, style: GoogleFonts.nunito(color: kPrimary, fontWeight: FontWeight.w700))),
              ],
            ),
          );
        }

        // Multiple events with same title — offer group delete
        final choice = await showDialog<String>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(context.s.deleteEvent, style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
            content: Text(context.s.multipleEventDelete(e.title, similar.length + 1),
                style: GoogleFonts.nunito()),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, null),
                  child: Text(context.s.cancel, style: GoogleFonts.nunito())),
              TextButton(onPressed: () => Navigator.pop(context, 'one'),
                  child: Text(context.s.justThisOne, style: GoogleFonts.nunito(color: kPrimary))),
              TextButton(onPressed: () => Navigator.pop(context, 'all'),
                  child: Text(context.s.allCount(similar.length + 1), style: GoogleFonts.nunito(
                      color: kPrimary, fontWeight: FontWeight.w800))),
            ],
          ),
        );

        if (choice == null) return false;
        if (choice == 'all') {
          final toDelete = [e, ...similar];
          setState(() { for (final ev in toDelete) _events.removeWhere((x) => x.id == ev.id); });
          for (final ev in toDelete) {
            try { await api.deleteEvent(widget.group.id, ev.id); } catch (_) {}
          }
          return false;
        }
        return true; // single delete — let onDismissed handle
      },
      onDismissed: (_) => _delete(e),
      child: GestureDetector(
        onTap: () => Navigator.push(context, slideRoute(EventDetailScreen(
          event: e,
          group: widget.group,
          color: color,
          creatorPicPath: picPath,
          onDeleted: () => setState(() => _events.removeWhere((x) => x.id == e.id)),
          onUpdated: () => setState(() {}),
        ))),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: KalendrTheme.surface(context),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            )],
          ),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 86,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 14, right: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.title, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: KalendrTheme.text(context))),
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(e.isAllDay ? Icons.calendar_today_rounded : Icons.schedule_rounded,
                            size: 13, color: KalendrTheme.muted(context)),
                        const SizedBox(width: 4),
                        Text(dateStr, style: GoogleFonts.nunito(fontSize: 12, color: KalendrTheme.muted(context))),
                      ]),
                      if (e.description != null && e.description!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(e.description!,
                            style: GoogleFonts.nunito(fontSize: 12, color: KalendrTheme.subtext(context)),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                      const SizedBox(height: 5),
                      Row(children: [
                        CircleAvatar(
                          radius: 8,
                          backgroundColor: color.withOpacity(0.15),
                          backgroundImage: picPath != null ? FileImage(File(picPath)) : null,
                          child: picPath == null
                              ? Text(e.createdByUsername[0].toUpperCase(),
                                  style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold))
                              : null,
                        ),
                        const SizedBox(width: 5),
                        Text(e.createdByUsername, style: GoogleFonts.nunito(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

