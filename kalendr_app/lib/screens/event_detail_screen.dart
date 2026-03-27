import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import '../widgets/skeleton.dart';
import 'add_event_sheet.dart';

class EventDetailScreen extends StatefulWidget {
  final CalendarEvent event;
  final Group? group;
  final Color color;
  final String? creatorPicPath;
  final VoidCallback? onDeleted;
  final VoidCallback? onUpdated;
  final List<CalendarEvent>? similarEvents;
  final List<Group> availableGroups;

  const EventDetailScreen({
    super.key,
    required this.event,
    this.group,
    required this.color,
    this.creatorPicPath,
    this.onDeleted,
    this.onUpdated,
    this.similarEvents,
    this.availableGroups = const [],
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  List<Reaction> _reactions = [];
  List<EventRsvp> _rsvps = [];
  List<EventComment> _comments = [];
  Map<String, List<Reaction>> _groupedReactions = {};
  bool _reactionsLoaded = false;
  bool _rsvpsLoaded = false;
  bool _commentsLoaded = false;
  final _commentCtrl = TextEditingController();
  bool _postingComment = false;

  static const _quickEmojis = ['👍', '❤️', '😂', '😮', '🎉', '🔥', '😡'];

  @override
  void initState() {
    super.initState();
    _loadReactions();
    _loadRsvps();
    _loadComments();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Map<String, List<Reaction>> _buildGrouped(List<Reaction> reactions) {
    final map = <String, List<Reaction>>{};
    for (final r in reactions) {
      map.putIfAbsent(r.emoji, () => []).add(r);
    }
    return map;
  }

  Future<void> _loadReactions() async {
    try {
      final r = await context.read<AppProvider>().api.getReactions(widget.event.id);
      if (mounted) setState(() { _reactions = r; _groupedReactions = _buildGrouped(r); _reactionsLoaded = true; });
    } catch (_) {
      if (mounted) setState(() => _reactionsLoaded = true);
    }
  }

  Future<void> _loadRsvps() async {
    try {
      final r = await context.read<AppProvider>().api.getRsvps(widget.event.id);
      if (mounted) setState(() { _rsvps = r; _rsvpsLoaded = true; });
    } catch (_) {
      if (mounted) setState(() => _rsvpsLoaded = true);
    }
  }

  Future<void> _loadComments() async {
    try {
      final c = await context.read<AppProvider>().api.getComments(widget.event.id);
      if (mounted) setState(() { _comments = c; _commentsLoaded = true; });
    } catch (_) {
      if (mounted) setState(() => _commentsLoaded = true);
    }
  }

  Future<void> _postComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _postingComment = true);
    try {
      final c = await context.read<AppProvider>().api.addComment(widget.event.id, text);
      _commentCtrl.clear();
      if (mounted) setState(() => _comments.add(c));
    } catch (e) {
      if (mounted) showSnack(context, e.toString());
    }
    if (mounted) setState(() => _postingComment = false);
  }

  Future<void> _deleteComment(EventComment comment) async {
    try {
      await context.read<AppProvider>().api.deleteComment(comment.id);
      setState(() => _comments.removeWhere((c) => c.id == comment.id));
    } catch (_) {}
  }

  Future<void> _toggleReaction(String emoji) async {
    HapticFeedback.lightImpact();
    try {
      final result = await context.read<AppProvider>().api.toggleReaction(widget.event.id, emoji);
      final myId = context.read<AppProvider>().auth.userId ?? '';
      setState(() {
        _reactions.removeWhere((r) => r.userId == myId && r.emoji == emoji);
        if (result != null) _reactions.add(result);
        _groupedReactions = _buildGrouped(_reactions);
      });
    } catch (_) {}
  }

  Future<void> _toggleRsvp(String status) async {
    HapticFeedback.selectionClick();
    try {
      final myId = context.read<AppProvider>().auth.userId ?? '';
      final result = await context.read<AppProvider>().api.setRsvp(widget.event.id, status);
      if (!mounted) return;
      setState(() {
        _rsvps.removeWhere((r) => r.userId == myId);
        if (result != null) _rsvps.add(result);
      });
      final removed = result == null;
      final label = removed ? 'RSVP removed' : const {
        'going': 'Marked as Going ✓',
        'maybe': 'Marked as Maybe',
        'declined': "Marked as Can't go",
      }[status] ?? 'RSVP updated';
      showSnack(context, label, color: removed ? Colors.grey.shade600 : const Color(0xFF06D6A0));
    } catch (_) {}
  }


  Future<void> _toggleGroupShare(String groupId) async {
    final e = widget.event;
    final current = List<String>.from(e.sharedGroupIds);
    if (current.contains(groupId)) {
      current.remove(groupId);
    } else {
      current.add(groupId);
    }
    try {
      final api = context.read<AppProvider>().api;
      if (e.recurrenceId != null) {
        await api.updateRecurrenceSeries(
          e.recurrenceId!,
          title: e.title,
          description: e.description,
          color: e.color,
          sharedGroupIds: current,
        );
        if (!mounted) return;
        setState(() => e.sharedGroupIds = current);
      } else {
        final updated = await api.updateEvent(
          e.id, e.title, e.description, e.startTime, e.endTime, e.isAllDay,
          color: e.color, sharedGroupIds: current,
        );
        if (!mounted) return;
        setState(() => e.sharedGroupIds = List<String>.from(updated.sharedGroupIds));
      }
      widget.onUpdated?.call();
    } catch (err) {
      if (mounted) showSnack(context, err.toString(), color: Colors.red.shade400);
    }
  }

  void _showEditSheet() {
    final e = widget.event;
    if (e.recurrenceId != null) {
      _askEditScope(e);
    } else {
      _openEditSheet(e, editSeries: false);
    }
  }

  Future<void> _askEditScope(CalendarEvent e) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: KalendrTheme.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: KalendrTheme.divider(context), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text('Edit recurring event', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: KalendrTheme.text(context))),
          const SizedBox(height: 6),
          Text('This event repeats. What do you want to edit?',
              style: GoogleFonts.nunito(fontSize: 14, color: KalendrTheme.subtext(context))),
          const SizedBox(height: 20),
          _scopeOption(Icons.event_rounded, 'This event only', 'Changes apply only to ${DateFormat('MMM d').format(e.startTime)}', 'one'),
          const SizedBox(height: 10),
          _scopeOption(Icons.event_repeat_rounded, 'All events in series', 'Changes apply to every occurrence', 'series', accent: true),
        ]),
      ),
    );
    if (choice == null || !mounted) return;
    _openEditSheet(e, editSeries: choice == 'series');
  }

  Widget _scopeOption(IconData icon, String title, String subtitle, String value, {bool accent = false}) {
    final color = accent ? widget.color : KalendrTheme.text(context);
    return GestureDetector(
      onTap: () => Navigator.pop(context, value),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: accent ? widget.color.withOpacity(0.08) : KalendrTheme.bg(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent ? widget.color.withOpacity(0.3) : KalendrTheme.divider(context)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
            Text(subtitle, style: GoogleFonts.nunito(fontSize: 12, color: KalendrTheme.subtext(context))),
          ])),
          Icon(Icons.chevron_right_rounded, color: KalendrTheme.muted(context), size: 20),
        ]),
      ),
    );
  }

  void _openEditSheet(CalendarEvent e, {required bool editSeries}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEventSheet(
        isEditing: true,
        initialTitle: e.title,
        initialDesc: e.description,
        initialStart: e.startTime,
        initialEnd: e.endTime,
        initialAllDay: e.isAllDay,
        initialColor: e.color,
        initialSharedGroupIds: e.sharedGroupIds,
        groupId: e.groupId,
        availableGroups: e.groupId == null ? widget.availableGroups : null,
        onAdd: (title, desc, start, end, allDay, color, sharedGroupIds) async {
          final api = context.read<AppProvider>().api;
          if (editSeries && e.recurrenceId != null) {
            final duration = end.difference(start).inMinutes;
            final count = await api.updateRecurrenceSeries(
              e.recurrenceId!,
              title: title,
              description: desc,
              color: color,
              sharedGroupIds: sharedGroupIds.isEmpty ? null : sharedGroupIds,
              startHour: start.hour,
              startMinute: start.minute,
              durationMinutes: duration,
            );
            e.title = title;
            e.description = desc;
            e.color = color;
            e.startTime = DateTime(e.startTime.year, e.startTime.month, e.startTime.day, start.hour, start.minute);
            e.endTime = e.startTime.add(Duration(minutes: duration));
            if (mounted) setState(() {});
            widget.onUpdated?.call();
            if (mounted) showSnack(context, 'Updated $count event${count == 1 ? '' : 's'}',
                color: const Color(0xFF06D6A0));
          } else {
            final updated = await api.updateEvent(e.id, title, desc, start, end, allDay,
                color: color, sharedGroupIds: sharedGroupIds.isEmpty ? null : sharedGroupIds);
            e.title = updated.title;
            e.description = updated.description;
            e.startTime = updated.startTime;
            e.endTime = updated.endTime;
            e.isAllDay = updated.isAllDay;
            e.color = updated.color;
            if (mounted) setState(() {});
            widget.onUpdated?.call();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AppProvider>().auth.userId ?? '';
    final isOwner = widget.event.createdByUserId == currentUserId;

    final e = widget.event;
    final dateStr = DateFormat('EEE, MMM d, y').format(e.startTime);
    final startStr = e.isAllDay ? 'All day' : DateFormat('HH:mm').format(e.startTime);
    final endStr = e.isAllDay ? '' : DateFormat('HH:mm').format(e.endTime);
    final grouped = _groupedReactions;

    final myRsvp = _rsvps.where((r) => r.userId == currentUserId).firstOrNull;
    final goingCount = _rsvps.where((r) => r.status == RsvpStatus.going).length;
    final maybeCount = _rsvps.where((r) => r.status == RsvpStatus.maybe).length;
    final declinedCount = _rsvps.where((r) => r.status == RsvpStatus.declined).length;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: KalendrTheme.bg(context),
      body: Column(children: [
        // ── Header ───────────────────────────────────────────────
        Container(
          color: KalendrTheme.surface(context),
          child: Column(children: [
            // Nav row
            Padding(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 4, left: 4, right: 8),
              child: Row(children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: KalendrTheme.text(context)),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            // Event info
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Badge row + creator
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(widget.group != null ? Icons.group_rounded : Icons.person_rounded, size: 12, color: widget.color),
                      const SizedBox(width: 5),
                      Text(widget.group?.name ?? 'Personal',
                          style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: widget.color)),
                    ]),
                  ),
                  const Spacer(),
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: widget.color.withOpacity(0.15),
                    backgroundImage: widget.creatorPicPath != null ? FileImage(File(widget.creatorPicPath!)) : null,
                    child: widget.creatorPicPath == null
                        ? Text(e.createdByUsername[0].toUpperCase(),
                            style: TextStyle(fontSize: 10, color: widget.color, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  const SizedBox(width: 6),
                  Text(e.createdByUsername,
                      style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: KalendrTheme.subtext(context))),
                ]),
                const SizedBox(height: 12),
                Text(e.title,
                    style: GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w800, color: KalendrTheme.text(context))),
                const SizedBox(height: 5),
                Row(children: [
                  Icon(e.isAllDay ? Icons.wb_sunny_outlined : Icons.schedule_rounded,
                      size: 13, color: widget.color.withOpacity(0.8)),
                  const SizedBox(width: 5),
                  Text(
                    e.isAllDay
                        ? DateFormat('EEEE, MMMM d, y').format(e.startTime)
                        : () {
                            final sameDay = e.startTime.year == e.endTime.year &&
                                e.startTime.month == e.endTime.month &&
                                e.startTime.day == e.endTime.day;
                            final endPart = sameDay
                                ? DateFormat('HH:mm').format(e.endTime)
                                : '${DateFormat('HH:mm').format(e.endTime)} (${DateFormat('MMM d').format(e.endTime)})';
                            return '${DateFormat('EEE, MMM d').format(e.startTime)}  ·  ${DateFormat('HH:mm').format(e.startTime)} – $endPart';
                          }(),
                    style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: widget.color.withOpacity(0.85)),
                  ),
                ]),
              ]),
            ),
            // Color bar
            Container(height: 3, color: widget.color.withOpacity(0.4)),
          ]),
        ),

        // ── Body ─────────────────────────────────────────────────
        Expanded(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.opaque,
            child: Column(children: [
              Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Description
                if (e.description != null && e.description!.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: KalendrTheme.surface(context),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Text(e.description!,
                        style: GoogleFonts.nunito(fontSize: 14, color: KalendrTheme.text(context), height: 1.55)),
                  ),
                  const SizedBox(height: 16),
                ],

                // Visible to (personal events only, owner only)
                if (widget.group == null && isOwner && widget.availableGroups.isNotEmpty) ...[
                  _sectionHeader('Visible to'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.availableGroups.map((g) {
                      final shared = e.sharedGroupIds.contains(g.id);
                      final gc = groupColorFor(g.id);
                      return GestureDetector(
                        onTap: () => _toggleGroupShare(g.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: shared ? gc.withOpacity(0.12) : KalendrTheme.surface(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: shared ? gc.withOpacity(0.5) : KalendrTheme.divider(context)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(shared ? Icons.visibility_rounded : Icons.visibility_off_outlined,
                                size: 14, color: shared ? gc : KalendrTheme.muted(context)),
                            const SizedBox(width: 6),
                            Text(g.name, style: GoogleFonts.nunito(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: shared ? gc : KalendrTheme.muted(context),
                            )),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                // RSVP
                _sectionHeader('Are you going?'),
                Row(children: [
                  _rsvpButton('Going', RsvpStatus.going, Icons.check_circle_outline_rounded, const Color(0xFF06D6A0), myRsvp, goingCount),
                  const SizedBox(width: 8),
                  _rsvpButton('Maybe', RsvpStatus.maybe, Icons.help_outline_rounded, const Color(0xFFFFBE0B), myRsvp, maybeCount),
                  const SizedBox(width: 8),
                  _rsvpButton("Can't", RsvpStatus.declined, Icons.cancel_outlined, kPrimary, myRsvp, declinedCount),
                ]),
                const SizedBox(height: 20),

                // Reactions
                _sectionHeader('Reactions'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: KalendrTheme.surface(context),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: _quickEmojis.map((emoji) {
                      final myReacted = _reactions.any((r) => r.userId == currentUserId && r.emoji == emoji);
                      final count = grouped[emoji]?.length ?? 0;
                      return GestureDetector(
                        onTap: () => _toggleReaction(emoji),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: myReacted ? widget.color.withOpacity(0.12) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: myReacted ? Border.all(color: widget.color.withOpacity(0.3)) : null,
                          ),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(emoji, style: const TextStyle(fontSize: 22)),
                            if (count > 0) ...[
                              const SizedBox(height: 2),
                              Text('$count',
                                  style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700,
                                      color: myReacted ? widget.color : KalendrTheme.muted(context))),
                            ],
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // Comments
                _sectionHeader('Comments'),

                if (!_commentsLoaded) ...[
                  Row(children: [
                    Skeleton(width: 32, height: 32, radius: 16),
                    const SizedBox(width: 10),
                    Expanded(child: Skeleton(width: double.infinity, height: 36, radius: 10)),
                  ]),
                ] else ...[
                  if (_comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text('No comments yet. Be the first!',
                          style: GoogleFonts.nunito(fontSize: 13, color: KalendrTheme.muted(context))),
                    )
                  else
                    ..._comments.map((c) => _commentTile(c, currentUserId)),
                ],
                const SizedBox(height: 8),

                // Comment input
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(color: KalendrTheme.surface(context), borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 6, offset: const Offset(0, 1))],
                      ),
                      child: TextField(
                        controller: _commentCtrl,
                        style: GoogleFonts.nunito(fontSize: 14, color: KalendrTheme.text(context)),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _postComment(),
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: GoogleFonts.nunito(color: KalendrTheme.muted(context), fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _postingComment ? null : _postComment,
                    child: Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        color: widget.color,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: widget.color.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: _postingComment
                          ? const Center(child: SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ]),
              ]),
            )),

            // ── Owner action buttons ──────────────────────────────
            if (isOwner)
              Container(
                padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 12),
                decoration: BoxDecoration(
                  color: KalendrTheme.surface(context),
                  border: Border(top: BorderSide(color: KalendrTheme.divider(context))),
                ),
                child: Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _showEditSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: widget.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.edit_rounded, size: 18, color: widget.color),
                          const SizedBox(width: 8),
                          Text('Edit', style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: widget.color)),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _confirmDelete(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red.shade400),
                          const SizedBox(width: 8),
                          Text('Delete', style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.red.shade400)),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ),
          ]),
        ),
      ),
      ]),
    );
  }

  Widget _commentTile(EventComment comment, String currentUserId) {
    final isMe = comment.userId == currentUserId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onLongPress: isMe ? () {
          HapticFeedback.mediumImpact();
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (_) => Container(
              decoration: BoxDecoration(color: KalendrTheme.surface(context), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Center(child: Container(width: 36, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.delete_outline_rounded, color: kPrimary, size: 18),
                  ),
                  title: Text('Delete comment', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: kPrimary)),
                  onTap: () { Navigator.pop(context); _deleteComment(comment); },
                ),
              ]),
            ),
          );
        } : null,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: widget.color.withOpacity(0.15),
            child: Text(comment.username[0].toUpperCase(),
                style: TextStyle(fontSize: 12, color: widget.color, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: KalendrTheme.surface(context),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withOpacity(0.2)
                    : Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 1),
              )],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(comment.username, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, color: widget.color)),
                const Spacer(),
                Text(
                  _relativeTime(comment.createdAt),
                  style: GoogleFonts.nunito(fontSize: 11, color: KalendrTheme.muted(context)),
                ),
              ]),
              const SizedBox(height: 3),
              Text(comment.content, style: GoogleFonts.nunito(fontSize: 13, color: KalendrTheme.text(context))),
            ]),
          )),
        ]),
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }

  Widget _rsvpButton(String label, RsvpStatus status, IconData icon, Color color, EventRsvp? myRsvp, int count) {
    final active = myRsvp?.status == status;
    return Expanded(
      child: GestureDetector(
        onTap: () => _toggleRsvp(status.name),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: active ? color.withOpacity(0.12) : KalendrTheme.surface(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: active ? color.withOpacity(0.5) : KalendrTheme.divider(context)),
            boxShadow: active ? [BoxShadow(color: color.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))] : null,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 20, color: active ? color : KalendrTheme.muted(context)),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700,
                color: active ? color : KalendrTheme.subtext(context))),
            if (count > 0) ...[
              const SizedBox(height: 2),
              Text('$count', style: GoogleFonts.nunito(fontSize: 11, color: active ? color : KalendrTheme.muted(context))),
            ],
          ]),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final e = widget.event;
    final isSeries = e.recurrenceId != null;
    final choice = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text('Delete event?', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 22)),
        content: Text(
          isSeries
              ? 'Delete just this occurrence, or the entire "${e.title}" series?'
              : 'This will permanently delete "${e.title}".',
          style: GoogleFonts.nunito(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('Cancel', style: GoogleFonts.nunito(fontWeight: FontWeight.w600, fontSize: 15, color: KalendrTheme.subtext(context))),
          ),
          if (isSeries) TextButton(
            onPressed: () => Navigator.pop(context, 'one'),
            child: Text('Just this one', style: GoogleFonts.nunito(fontWeight: FontWeight.w600, fontSize: 15, color: KalendrTheme.text(context))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, isSeries ? 'series' : 'one'),
            child: Text(isSeries ? 'Delete series' : 'Delete',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.red)),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    final api = context.read<AppProvider>().api;
    if (choice == 'series' && e.recurrenceId != null) {
      try {
        final deleted = await api.deleteRecurrenceSeries(e.recurrenceId!);
        widget.onDeleted?.call();
        if (context.mounted) Navigator.pop(context);
        if (context.mounted) showSnack(context, 'Deleted $deleted event${deleted == 1 ? '' : 's'}', color: Colors.red.shade400);
      } catch (err) {
        if (context.mounted) showSnack(context, err.toString(), color: Colors.red.shade400);
      }
    } else {
      try { await api.deleteEvent(e.groupId, e.id); } catch (_) {}
      widget.onDeleted?.call();
      if (context.mounted) Navigator.pop(context);
    }
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          width: 3, height: 16,
          decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(title, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: KalendrTheme.text(context))),
      ]),
    );
  }

  Widget _infoCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: KalendrTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.black.withOpacity(0.3)
              : Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        )],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 4, color: widget.color.withOpacity(0.6)),
            Expanded(child: Column(children: children)),
          ]),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Text(label, style: GoogleFonts.nunito(fontSize: 13, color: KalendrTheme.subtext(context), fontWeight: FontWeight.w600)),
        const Spacer(),
        Expanded(child: Text(value, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: KalendrTheme.text(context)), textAlign: TextAlign.end)),
      ]),
    );
  }
}
