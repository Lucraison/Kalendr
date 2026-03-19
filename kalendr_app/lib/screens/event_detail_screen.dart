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
  final Group group;
  final Color color;
  final String? creatorPicPath;
  final VoidCallback? onDeleted;
  final VoidCallback? onUpdated;

  const EventDetailScreen({
    super.key,
    required this.event,
    required this.group,
    required this.color,
    this.creatorPicPath,
    this.onDeleted,
    this.onUpdated,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  List<Reaction> _reactions = [];
  List<EventRsvp> _rsvps = [];
  List<EventComment> _comments = [];
  bool _reactionsLoaded = false;
  bool _rsvpsLoaded = false;
  bool _commentsLoaded = false;
  final _commentCtrl = TextEditingController();
  bool _postingComment = false;

  static const _quickEmojis = ['👍', '❤️', '😂', '😮', '🎉', '🔥'];

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

  Future<void> _loadReactions() async {
    try {
      final r = await context.read<AppProvider>().api.getReactions(widget.event.id);
      if (mounted) setState(() { _reactions = r; _reactionsLoaded = true; });
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

  Map<String, List<Reaction>> get _grouped {
    final map = <String, List<Reaction>>{};
    for (final r in _reactions) {
      map.putIfAbsent(r.emoji, () => []).add(r);
    }
    return map;
  }

  void _showEditSheet() {
    final e = widget.event;
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
        onAdd: (title, desc, start, end, allDay) async {
          final updated = await context.read<AppProvider>().api
              .updateEvent(e.id, title, desc, start, end, allDay);
          e.title = updated.title;
          e.description = updated.description;
          e.startTime = updated.startTime;
          e.endTime = updated.endTime;
          e.isAllDay = updated.isAllDay;
          if (mounted) setState(() {});
          widget.onUpdated?.call();
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
    final grouped = _grouped;

    final myRsvp = _rsvps.where((r) => r.userId == currentUserId).firstOrNull;
    final goingCount = _rsvps.where((r) => r.status == RsvpStatus.going).length;
    final maybeCount = _rsvps.where((r) => r.status == RsvpStatus.maybe).length;
    final declinedCount = _rsvps.where((r) => r.status == RsvpStatus.declined).length;

    return Scaffold(
      backgroundColor: KalendrTheme.bg(context),
      body: Column(children: [
        Container(
          color: KalendrTheme.surface(context),
          child: Column(children: [
            Padding(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 4, left: 4, right: 8, bottom: 0),
              child: Row(children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: KalendrTheme.text(context)),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                if (isOwner) ...[
                  IconButton(
                    icon: Icon(Icons.edit_rounded, size: 20, color: widget.color),
                    onPressed: _showEditSheet,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 22, color: kPrimary),
                    onPressed: () => _confirmDelete(context),
                  ),
                ],
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.group_rounded, size: 12, color: widget.color),
                    const SizedBox(width: 5),
                    Text(widget.group.name, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: widget.color)),
                  ]),
                ),
                const SizedBox(height: 10),
                Text(e.title, style: GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w800, color: KalendrTheme.text(context))),
              ]),
            ),
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [widget.color, widget.color.withOpacity(0.35)]),
              ),
            ),
          ]),
        ),

        Expanded(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.opaque,
            child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 4),

              _infoCard(children: [
                _infoRow(Icons.calendar_today_rounded, 'Date', dateStr, widget.color),
                if (!e.isAllDay) ...[
                  Divider(height: 1, color: KalendrTheme.divider(context)),
                  _infoRow(Icons.schedule_rounded, 'Time', '$startStr – $endStr', widget.color),
                ],
              ]),
              const SizedBox(height: 12),

              if (e.description != null && e.description!.isNotEmpty) ...[
                _infoCard(children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(Icons.notes_rounded, size: 16, color: widget.color),
                        const SizedBox(width: 10),
                        Text('Notes', style: GoogleFonts.nunito(fontSize: 13, color: KalendrTheme.subtext(context), fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 8),
                      Text(e.description!, style: GoogleFonts.nunito(fontSize: 15, color: KalendrTheme.text(context), height: 1.5)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
              ],

              _infoCard(children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Icon(Icons.person_rounded, size: 16, color: widget.color),
                    const SizedBox(width: 10),
                    Text('Added by', style: GoogleFonts.nunito(fontSize: 13, color: KalendrTheme.subtext(context), fontWeight: FontWeight.w600)),
                    const Spacer(),
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: widget.color.withOpacity(0.15),
                      backgroundImage: widget.creatorPicPath != null ? FileImage(File(widget.creatorPicPath!)) : null,
                      child: widget.creatorPicPath == null
                          ? Text(e.createdByUsername[0].toUpperCase(),
                              style: TextStyle(fontSize: 11, color: widget.color, fontWeight: FontWeight.bold))
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(e.createdByUsername, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: KalendrTheme.text(context))),
                  ]),
                ),
              ]),
              const SizedBox(height: 24),

              // RSVP
              _sectionHeader('Are you going?'),
              Row(children: [
                _rsvpButton('Going', RsvpStatus.going, Icons.check_circle_outline_rounded, const Color(0xFF06D6A0), myRsvp, goingCount),
                const SizedBox(width: 8),
                _rsvpButton('Maybe', RsvpStatus.maybe, Icons.help_outline_rounded, const Color(0xFFFFBE0B), myRsvp, maybeCount),
                const SizedBox(width: 8),
                _rsvpButton("Can't", RsvpStatus.declined, Icons.cancel_outlined, kPrimary, myRsvp, declinedCount),
              ]),
              const SizedBox(height: 24),

              // Reactions
              _sectionHeader('Reactions'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ..._quickEmojis.map((emoji) {
                  final myReacted = _reactions.any((r) => r.userId == currentUserId && r.emoji == emoji);
                  return GestureDetector(
                    onTap: () => _toggleReaction(emoji),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: myReacted ? widget.color.withOpacity(0.12) : KalendrTheme.divider(context),
                        borderRadius: BorderRadius.circular(20),
                        border: myReacted ? Border.all(color: widget.color.withOpacity(0.4)) : null,
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(emoji, style: const TextStyle(fontSize: 16)),
                        if (grouped.containsKey(emoji)) ...[
                          const SizedBox(width: 5),
                          Text('${grouped[emoji]!.length}',
                              style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700,
                                  color: myReacted ? widget.color : KalendrTheme.subtext(context))),
                        ],
                      ]),
                    ),
                  );
                }),
              ]),
              const SizedBox(height: 24),

              // Comments
              _sectionHeader('Comments'),

              if (!_commentsLoaded) ...[
                Row(children: [
                  Skeleton(width: 32, height: 32, radius: 16),
                  const SizedBox(width: 10),
                  Expanded(child: Skeleton(width: double.infinity, height: 36, radius: 10)),
                ]),
              ] else ...[
                ..._comments.map((c) => _commentTile(c, currentUserId)),
                if (_comments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('No comments yet. Be the first!',
                        style: GoogleFonts.nunito(fontSize: 13, color: KalendrTheme.muted(context))),
                  ),
              ],
              const SizedBox(height: 12),

              // Comment input
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: KalendrTheme.field(context), borderRadius: BorderRadius.circular(14)),
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _postingComment ? null : _postComment,
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(14)),
                    child: _postingComment
                        ? const Center(child: SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ]),
              const SizedBox(height: 24),
            ]),
          ),
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
          padding: const EdgeInsets.symmetric(vertical: 10),
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete event?', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text('This removes "${widget.event.title}" for everyone.', style: GoogleFonts.nunito()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.nunito())),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.nunito(color: kPrimary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    await context.read<AppProvider>().api.deleteEvent(widget.group.id, widget.event.id);
    widget.onDeleted?.call();
    if (context.mounted) Navigator.pop(context);
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
