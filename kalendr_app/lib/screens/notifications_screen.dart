import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import '../widgets/skeleton.dart';
import '../widgets/slide_route.dart';
import '../l10n/app_strings.dart';
import 'event_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Events grouped by day key (yyyy-MM-dd)
  final Map<String, List<_EventEntry>> _byDay = {};
  List<String> _sortedDays = [];
  List<Group> _groups = [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = false; });
    try {
      final api = context.read<AppProvider>().api;
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day); // start of today
      final to = from.add(const Duration(days: 14));

      _groups = await api.getGroups();

      final results = await Future.wait([
        ..._groups.map((g) => api.getEvents(g.id, from: from, to: to)),
        api.getPersonalEvents(from: from, to: to),
      ]);

      if (!mounted) return;

      final seen = <String>{};
      final newByDay = <String, List<_EventEntry>>{};

      for (int i = 0; i < _groups.length; i++) {
        for (final e in results[i]) {
          if (seen.add(e.id)) {
            final key = _dayKey(e.startTime);
            newByDay.putIfAbsent(key, () => []).add(_EventEntry(e, _groups[i]));
          }
        }
      }
      for (final e in results[_groups.length]) {
        if (seen.add(e.id)) {
          final key = _dayKey(e.startTime);
          newByDay.putIfAbsent(key, () => []).add(_EventEntry(e, null));
        }
      }

      // Sort events within each day by start time
      for (final list in newByDay.values) {
        list.sort((a, b) => a.event.startTime.compareTo(b.event.startTime));
      }

      setState(() {
        _byDay
          ..clear()
          ..addAll(newByDay);
        _sortedDays = newByDay.keys.toList()..sort();
      });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
    if (mounted) setState(() => _loading = false);
  }

  String _dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  String _dayHeader(String key, AppStrings s) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime.parse(key);
    if (date == today) return s.today;
    if (date == today.add(const Duration(days: 1))) return s.tomorrow;
    // Within this week: show day name
    if (date.difference(today).inDays < 7) return DateFormat('EEEE').format(date);
    return DateFormat('EEE, MMM d').format(date);
  }

  Color _eventColor(_EventEntry entry) {
    final e = entry.event;
    if (e.color != null) return hexToColor(e.color!);
    if (e.isWorkHours) return const Color(0xFF3B82F6);
    if (entry.group != null) {
      final member = entry.group!.members.cast<GroupMember?>().firstWhere(
        (m) => m?.userId == e.createdByUserId, orElse: () => null);
      if (member != null) return hexToColor(member.color);
      return groupColorFor(entry.group!.id);
    }
    return kPrimary;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final provider = context.read<AppProvider>();

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
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.soonTitle,
                  style: GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w800,
                      color: KalendrTheme.text(context))),
              Text(
                DateFormat('MMM d').format(DateTime.now()) +
                    ' – ' +
                    DateFormat('MMM d').format(DateTime.now().add(const Duration(days: 14))),
                style: GoogleFonts.nunito(fontSize: 13, color: KalendrTheme.muted(context)),
              ),
            ]),
          ]),
        ),

        Expanded(
          child: _loading
              ? _buildSkeleton()
              : RefreshIndicator(
                  color: kPrimary,
                  onRefresh: _load,
                  child: _error
                      ? ListView(children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                          Center(child: Column(children: [
                            Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(context.s.couldNotLoadEvents,
                                style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700,
                                    color: KalendrTheme.text(context))),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: Text(context.s.retry, style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                              style: TextButton.styleFrom(foregroundColor: kPrimary),
                            ),
                          ])),
                        ])
                      : _sortedDays.isEmpty
                          ? ListView(children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                              Center(child: Column(children: [
                                const Text('🌿', style: TextStyle(fontSize: 48)),
                                const SizedBox(height: 16),
                                Text(s.nothingComingUp,
                                    style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800,
                                        color: KalendrTheme.text(context))),
                                const SizedBox(height: 6),
                                Text(s.nothingComingUpSub,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.nunito(fontSize: 14, color: KalendrTheme.muted(context))),
                              ])),
                            ])
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                              itemCount: _sortedDays.length,
                              itemBuilder: (_, i) {
                                final day = _sortedDays[i];
                                final entries = _byDay[day]!;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8, top: 4),
                                      child: Text(
                                        _dayHeader(day, s),
                                        style: GoogleFonts.nunito(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: day == _dayKey(DateTime.now())
                                              ? kPrimary
                                              : KalendrTheme.subtext(context),
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                    ...entries.map((entry) => _eventTile(entry, provider)),
                                    const SizedBox(height: 12),
                                  ],
                                );
                              },
                            ),
                ),
        ),
      ]),
    );
  }

  Widget _eventTile(_EventEntry entry, AppProvider provider) {
    final e = entry.event;
    final color = _eventColor(entry);
    final timeStr = e.isAllDay
        ? context.s.allDay
        : provider.formatDateTime(e.startTime);

    return GestureDetector(
      onTap: () => Navigator.push(context, slideRoute(EventDetailScreen(
        event: e,
        group: entry.group,
        color: color,
        availableGroups: _groups,
        onDeleted: () => setState(() {
          for (final list in _byDay.values) {
            list.removeWhere((x) => x.event.id == e.id);
          }
          _sortedDays = _byDay.entries
              .where((kv) => kv.value.isNotEmpty)
              .map((kv) => kv.key)
              .toList()..sort();
        }),
        onUpdated: () => _load(),
      ))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: KalendrTheme.surface(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withOpacity(0.25)
                : Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )],
        ),
        child: Row(children: [
          Container(
            width: 5, height: 68,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.title,
                    style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700,
                        color: KalendrTheme.text(context))),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.schedule_rounded, size: 12, color: KalendrTheme.muted(context)),
                  const SizedBox(width: 4),
                  Text(timeStr,
                      style: GoogleFonts.nunito(fontSize: 12, color: KalendrTheme.muted(context))),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      entry.group?.name ?? context.s.personal,
                      style: GoogleFonts.nunito(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (e.createdByUsername.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      e.createdByUsername,
                      style: GoogleFonts.nunito(fontSize: 11, color: KalendrTheme.muted(context)),
                    ),
                  ],
                ]),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade300, size: 18),
          ),
        ]),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: List.generate(6, (i) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (i == 0 || i == 3) ...[
            Skeleton(width: 80, height: 13, radius: 6),
            const SizedBox(height: 8),
          ],
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: KalendrTheme.surface(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              Container(width: 5, height: 40, decoration: BoxDecoration(
                color: KalendrTheme.divider(context),
                borderRadius: BorderRadius.circular(4),
              )),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Skeleton(width: 160, height: 13, radius: 6),
                const SizedBox(height: 6),
                Skeleton(width: 100, height: 11, radius: 5),
              ])),
            ]),
          ),
        ],
      )),
    );
  }
}

class _EventEntry {
  final CalendarEvent event;
  final Group? group;
  _EventEntry(this.event, this.group);
}
