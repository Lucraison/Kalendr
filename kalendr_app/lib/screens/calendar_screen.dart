import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import '../widgets/skeleton.dart';
import '../widgets/slide_route.dart';
import '../widgets/type_picker_sheet.dart';
import 'add_event_sheet.dart';
import 'add_work_schedule_sheet.dart';
import 'event_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  Map<String, List<_EventWithGroup>> _eventsByDay = {};
  List<Group> _groups = [];
  bool _loading = true;
  bool _error = false;
  final Set<String> _loadedMonths = {};

  @override
  void initState() {
    super.initState();
    _loadFormat();
    _load();
  }

  Future<void> _loadFormat() async {
    final prefs = await SharedPreferences.getInstance();
    final isWeek = prefs.getBool('calendarWeekView') ?? false;
    if (mounted && isWeek) setState(() => _calendarFormat = CalendarFormat.week);
  }

  Future<void> _saveFormat(CalendarFormat format) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('calendarWeekView', format == CalendarFormat.week);
  }

  String _dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  String _monthKey(DateTime d) => DateFormat('yyyy-MM').format(d);

  Future<void> _load() async {
    setState(() { _loading = true; _error = false; _loadedMonths.clear(); _eventsByDay.clear(); });
    try {
      _groups = await context.read<AppProvider>().api.getGroups();
      await _loadMonth(_focusedDay);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMonth(DateTime month) async {
    final key = _monthKey(month);
    if (_loadedMonths.contains(key)) return;
    _loadedMonths.add(key); // mark early to prevent duplicate fetches
    final from = DateTime(month.year, month.month, 1);
    final to = DateTime(month.year, month.month + 1, 1);
    try {
      final api = context.read<AppProvider>().api;
      final results = await Future.wait(_groups.map((g) => api.getEvents(g.id, from: from, to: to)));
      if (!mounted) return;
      final newEntries = <String, List<_EventWithGroup>>{};
      for (int i = 0; i < _groups.length; i++) {
        for (final e in results[i]) {
          newEntries.putIfAbsent(_dayKey(e.startTime), () => []).add(_EventWithGroup(e, _groups[i]));
        }
      }
      setState(() => _eventsByDay.addAll(newEntries));
    } catch (_) {
      _loadedMonths.remove(key); // allow retry on failure
    }
  }

  List<_EventWithGroup> _eventsForDay(DateTime day) =>
      _eventsByDay[_dayKey(day)] ?? [];

  Color _groupColor(Group g) => groupColorFor(g.id);

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 18) return 'Good afternoon';
    if (hour >= 18 && hour < 22) return 'Good evening';
    return 'Up late';
  }

  void _showAddEvent() {
    if (_groups.isEmpty) {
      showSnack(context, 'Join or create a group first!');
      return;
    }
    // Show type picker first
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => TypePickerSheet(
        onEvent: () {
          Navigator.pop(context);
          if (_groups.length == 1) _openAddSheet(_groups.first); else _showGroupPicker(forWork: false);
        },
        onWorkSchedule: () {
          Navigator.pop(context);
          if (_groups.length == 1) _openAddSheet(_groups.first, forWork: true); else _showGroupPicker(forWork: true);
        },
      ),
    );
  }

  void _showGroupPicker({bool forWork = false}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: KalendrTheme.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text('Add to...', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: KalendrTheme.text(context))),
          const SizedBox(height: 12),
          ..._groups.map((g) {
            final color = _groupColor(g);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.group_rounded, color: color, size: 18),
              ),
              title: Text(g.name, style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: KalendrTheme.text(context))),
              subtitle: Text('${g.members.length} member${g.members.length == 1 ? '' : 's'}',
                  style: GoogleFonts.nunito(fontSize: 12, color: KalendrTheme.muted(context))),
              onTap: () {
                Navigator.pop(context);
                _openAddSheet(g, forWork: forWork);
              },
            );
          }),
        ]),
      ),
    );
  }

  void _openAddSheet(Group group, {bool forWork = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => forWork
          ? AddWorkScheduleSheet(
              initialDate: _selectedDay,
              onAdd: (title, desc, start, end, allDay) async {
                final api = context.read<AppProvider>().api;
                final e = await api.createEvent(group.id, title, desc, start, end, allDay);
                final key = _dayKey(e.startTime);
                if (mounted) setState(() => _eventsByDay.putIfAbsent(key, () => []).add(_EventWithGroup(e, group)));
              },
            )
          : AddEventSheet(
              initialDate: _selectedDay,
              onAdd: (title, desc, start, end, allDay) async {
                final api = context.read<AppProvider>().api;
                final e = await api.createEvent(group.id, title, desc, start, end, allDay);
                final key = _dayKey(e.startTime);
                if (mounted) setState(() => _eventsByDay.putIfAbsent(key, () => []).add(_EventWithGroup(e, group)));
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AppProvider>().auth;
    final selectedEvents = _eventsForDay(_selectedDay);
    final today = DateTime.now();
    final todayEvents = _eventsForDay(today);

    return Scaffold(
      backgroundColor: KalendrTheme.bg(context),
      body: Column(
        children: [
          Container(
            color: KalendrTheme.surface(context),
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, left: 20, right: 16, bottom: 16),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${_greeting()}, ${auth.username ?? ''}! 👋',
                    style: GoogleFonts.nunito(fontSize: 13, color: KalendrTheme.subtext(context))),
                const SizedBox(height: 2),
                Text(DateFormat('EEEE, MMMM d').format(today),
                    style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, color: KalendrTheme.text(context))),
              ]),
              const Spacer(),
              if (_focusedDay.year != today.year || _focusedDay.month != today.month)
                GestureDetector(
                  onTap: () => setState(() { _focusedDay = today; _selectedDay = today; }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text('Today', style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: kPrimary)),
                  ),
                )
              else if (todayEvents.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text('${todayEvents.length} today',
                      style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: kPrimary)),
                ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  final next = _calendarFormat == CalendarFormat.month
                      ? CalendarFormat.week
                      : CalendarFormat.month;
                  setState(() => _calendarFormat = next);
                  _saveFormat(next);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: KalendrTheme.field(context),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      _calendarFormat == CalendarFormat.month
                          ? Icons.calendar_view_week_rounded
                          : Icons.calendar_month_rounded,
                      size: 14, color: KalendrTheme.subtext(context),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _calendarFormat == CalendarFormat.month ? 'Week' : 'Month',
                      style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: KalendrTheme.subtext(context)),
                    ),
                  ]),
                ),
              ),
            ]),
          ),

          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _loading
                ? _buildSkeleton()
                : _error
                    ? _buildError()
                    : RefreshIndicator(
                    color: kPrimary,
                    onRefresh: _load,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(children: [
                        Container(
                          color: KalendrTheme.surface(context),
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TableCalendar(
                            firstDay: DateTime(today.year - 1),
                            lastDay: DateTime(today.year + 5),
                            focusedDay: _focusedDay,
                            calendarFormat: _calendarFormat,
                            sixWeekMonthsEnforced: true,
                            pageAnimationDuration: const Duration(milliseconds: 180),
                            pageAnimationCurve: Curves.easeOut,
                            selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
                            eventLoader: _eventsForDay,
                            onDaySelected: (selected, focused) => setState(() { _selectedDay = selected; _focusedDay = focused; }),
                            onFormatChanged: (format) { setState(() => _calendarFormat = format); _saveFormat(format); },
                            onPageChanged: (focused) {
                              setState(() => _focusedDay = focused);
                              _loadMonth(focused);
                            },
                            calendarStyle: CalendarStyle(
                              todayDecoration: BoxDecoration(color: kPrimary.withOpacity(0.15), shape: BoxShape.circle),
                              todayTextStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: kPrimary),
                              selectedDecoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
                              selectedTextStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: Colors.white),
                              defaultTextStyle: GoogleFonts.nunito(color: KalendrTheme.text(context)),
                              weekendTextStyle: GoogleFonts.nunito(color: KalendrTheme.subtext(context)),
                              outsideTextStyle: GoogleFonts.nunito(color: KalendrTheme.muted(context)),
                              markerDecoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
                              markerSize: 5,
                              markersMaxCount: 3,
                              cellMargin: const EdgeInsets.all(4),
                            ),
                            headerStyle: HeaderStyle(
                              formatButtonVisible: false,
                              titleCentered: true,
                              titleTextStyle: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: KalendrTheme.text(context)),
                              leftChevronIcon: const Icon(Icons.chevron_left_rounded, color: kPrimary),
                              rightChevronIcon: const Icon(Icons.chevron_right_rounded, color: kPrimary),
                              headerPadding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            daysOfWeekStyle: DaysOfWeekStyle(
                              weekdayStyle: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: KalendrTheme.muted(context)),
                              weekendStyle: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: KalendrTheme.muted(context)),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(children: [
                            Text(
                              isSameDay(_selectedDay, today) ? 'Today' : DateFormat('EEEE, MMMM d').format(_selectedDay),
                              style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: KalendrTheme.text(context)),
                            ),
                            const Spacer(),
                            if (selectedEvents.isNotEmpty)
                              Text('${selectedEvents.length} event${selectedEvents.length == 1 ? '' : 's'}',
                                  style: GoogleFonts.nunito(fontSize: 13, color: KalendrTheme.muted(context))),
                          ]),
                        ),
                        const SizedBox(height: 12),

                        if (_calendarFormat == CalendarFormat.week)
                          _buildTimeline(selectedEvents, today)
                        else if (selectedEvents.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 36),
                            child: Column(children: [
                              Text(
                                isSameDay(_selectedDay, today) ? '🌿' : '📭',
                                style: const TextStyle(fontSize: 36),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                isSameDay(_selectedDay, today)
                                    ? (_groups.isEmpty ? 'Join a group to see events' : 'Free day!')
                                    : 'Nothing scheduled',
                                style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: KalendrTheme.text(context)),
                              ),
                              if (_groups.isEmpty) ...[
                                const SizedBox(height: 4),
                                Text('Go to Groups to get started', style: GoogleFonts.nunito(fontSize: 13, color: KalendrTheme.muted(context))),
                              ],
                            ]),
                          )
                        else
                          ...selectedEvents.map((ew) => _eventTile(ew)),

                        const SizedBox(height: 80),
                      ]),
                    ),
                  ),
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

  Widget _buildTimeline(List<_EventWithGroup> events, DateTime today) {
    const startHour = 0;
    const endHour = 24;
    const hourHeight = 60.0;
    const labelWidth = 50.0;
    const totalHeight = (endHour - startHour) * hourHeight;

    final now = DateTime.now();
    final isToday = isSameDay(_selectedDay, today);
    final nowMinutes = isToday ? (now.hour - startHour) * 60 + now.minute : -1;

    final allDayEvents = events.where((e) => e.event.isAllDay).toList();
    final timedEvents = events.where((e) => !e.event.isAllDay).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (allDayEvents.isNotEmpty) ...[
            ...allDayEvents.map((ew) => _eventTile(ew)),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: totalHeight,
            child: Stack(
              children: [
                // Hour grid lines and labels
                ...List.generate(endHour - startHour, (i) {
                  final hour = startHour + i;
                  final top = i * hourHeight;
                  return Positioned(
                    top: top,
                    left: 0,
                    right: 0,
                    child: Row(children: [
                      SizedBox(
                        width: labelWidth,
                        child: Text(
                          '${hour.toString().padLeft(2, '0')}:00',
                          style: GoogleFonts.nunito(fontSize: 10, color: KalendrTheme.muted(context)),
                        ),
                      ),
                      Expanded(child: Divider(height: 1, color: KalendrTheme.divider(context))),
                    ]),
                  );
                }),

                // Timed events
                ...timedEvents.map((ew) {
                  final color = _groupColor(ew.group);
                  final s = ew.event.startTime;
                  final e = ew.event.endTime;
                  final startMin = (s.hour - startHour) * 60 + s.minute;
                  final endMin = (e.hour - startHour) * 60 + e.minute;
                  final top = (startMin / 60) * hourHeight;
                  final height = ((endMin - startMin) / 60) * hourHeight;

                  return Positioned(
                    top: top,
                    left: labelWidth + 4,
                    right: 0,
                    height: height.clamp(28.0, double.infinity),
                    child: GestureDetector(
                      onTap: () => Navigator.push(context, slideRoute(EventDetailScreen(
                        event: ew.event,
                        group: ew.group,
                        color: color,
                        onUpdated: () => setState(() {}),
                      ))),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 2, right: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(left: BorderSide(color: color, width: 3)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              ew.event.title,
                              style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: KalendrTheme.text(context)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (height > 36)
                              Text(
                                '${DateFormat('HH:mm').format(s)} – ${DateFormat('HH:mm').format(e)}',
                                style: GoogleFonts.nunito(fontSize: 10, color: KalendrTheme.muted(context)),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                // Now indicator
                if (nowMinutes >= 0 && nowMinutes < (endHour - startHour) * 60)
                  Positioned(
                    top: (nowMinutes / 60) * hourHeight,
                    left: labelWidth,
                    right: 0,
                    child: Row(children: [
                      Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
                      ),
                      Expanded(child: Container(height: 2, color: kPrimary)),
                    ]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text('Could not load events', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: KalendrTheme.text(context))),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: Text('Retry', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          style: TextButton.styleFrom(foregroundColor: kPrimary),
        ),
      ]),
    );
  }

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      child: Column(children: [
        Container(
          color: KalendrTheme.surface(context),
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            // Calendar skeleton
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Skeleton(width: 24, height: 24, radius: 12),
              Skeleton(width: 120, height: 16, radius: 8),
              Skeleton(width: 24, height: 24, radius: 12),
            ]),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (_) => Skeleton(width: 32, height: 32, radius: 16))),
            const SizedBox(height: 8),
            ...List.generate(5, (_) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(7, (_) => Skeleton(width: 32, height: 32, radius: 16))),
            )),
          ]),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: List.generate(3, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              height: 68,
              decoration: BoxDecoration(color: KalendrTheme.surface(context), borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                Container(width: 5, height: 68,
                    decoration: BoxDecoration(color: KalendrTheme.divider(context),
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center, children: [
                  Skeleton(width: double.infinity, height: 13, radius: 6),
                  const SizedBox(height: 7),
                  Skeleton(width: 100, height: 11, radius: 5),
                ])),
              ]),
            ),
          ))),
        ),
      ]),
    );
  }

  Widget _eventTile(_EventWithGroup ew) {
    final color = _groupColor(ew.group);
    final timeStr = ew.event.isAllDay ? 'All day' : DateFormat('HH:mm').format(ew.event.startTime);

    return GestureDetector(
      onTap: () => Navigator.push(context, slideRoute(EventDetailScreen(
        event: ew.event,
        group: ew.group,
        color: color,
        onUpdated: () => setState(() {}),
      ))),
      child: Container(
        margin: const EdgeInsets.only(left: 20, right: 20, bottom: 10),
        decoration: BoxDecoration(
          color: KalendrTheme.surface(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )],
        ),
        child: Row(children: [
          Container(
            width: 5, height: 68,
            decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.horizontal(left: Radius.circular(16))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ew.event.title, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: KalendrTheme.text(context))),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.schedule_rounded, size: 12, color: KalendrTheme.muted(context)),
                  const SizedBox(width: 4),
                  Text(timeStr, style: GoogleFonts.nunito(fontSize: 12, color: KalendrTheme.muted(context))),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text(ew.group.name, style: GoogleFonts.nunito(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                  ),
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
}

class _EventWithGroup {
  final CalendarEvent event;
  final Group group;
  _EventWithGroup(this.event, this.group);
}

