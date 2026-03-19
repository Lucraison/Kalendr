import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../theme.dart';

// Shared date picker theme throughout the sheet
ThemeData _pickerTheme(BuildContext ctx, {required String helpText}) {
  return Theme.of(ctx).copyWith(
    colorScheme: const ColorScheme.light(
      primary: kPrimary,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: Color(0xFF1A1A2E),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: Colors.white,
      headerBackgroundColor: kPrimary,
      headerForegroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      dayStyle: GoogleFonts.nunito(fontSize: 13),
      weekdayStyle: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700),
      yearStyle: GoogleFonts.nunito(fontSize: 13),
      headerHeadlineStyle: GoogleFonts.nunito(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
      headerHelpStyle: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 1),
      dayForegroundColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? Colors.white : const Color(0xFF1A1A2E)),
      dayBackgroundColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? kPrimary : null),
      todayBorder: const BorderSide(color: kPrimary),
      todayForegroundColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? Colors.white : kPrimary),
      todayBackgroundColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? kPrimary : Colors.transparent),
      surfaceTintColor: Colors.transparent,
    ),
  );
}

enum EventRepeat { none, daily, weekdays, weekly, custom }

class AddEventSheet extends StatefulWidget {
  final Future<void> Function(String title, String? desc, DateTime start, DateTime end, bool allDay) onAdd;
  final DateTime? initialDate;
  final bool isEditing;
  final String? initialTitle;
  final String? initialDesc;
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final bool? initialAllDay;

  const AddEventSheet({
    super.key,
    required this.onAdd,
    this.initialDate,
    this.isEditing = false,
    this.initialTitle,
    this.initialDesc,
    this.initialStart,
    this.initialEnd,
    this.initialAllDay,
  });

  @override
  State<AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends State<AddEventSheet> {
  late final TextEditingController _title;
  late final TextEditingController _desc;
  late bool _allDay;
  late DateTime _start;
  late DateTime _end;
  EventRepeat _repeat = EventRepeat.none;
  DateTime _repeatUntil = DateTime.now().add(const Duration(days: 7));
  final Map<int, ({TimeOfDay start, TimeOfDay end})> _customDays = {};
  bool _sameHours = true;
  TimeOfDay _globalHourStart = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _globalHourEnd = const TimeOfDay(hour: 17, minute: 0);
  bool _busy = false;
  String _error = '';
  int _created = 0;

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  static DateTime _nextHour([DateTime? base]) {
    final d = base ?? DateTime.now();
    return DateTime(d.year, d.month, d.day, DateTime.now().hour + 1);
  }

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initialTitle ?? '');
    _desc = TextEditingController(text: widget.initialDesc ?? '');
    _allDay = widget.initialAllDay ?? false;
    _start = widget.initialStart ?? _nextHour(widget.initialDate);
    _end = widget.initialEnd ?? _start.add(const Duration(hours: 1));
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  List<DateTime> _generateDates() {
    if (_repeat == EventRepeat.none) return [_start];
    final dates = <DateTime>[];
    var current = _start;
    while (!current.isAfter(_repeatUntil)) {
      if (_repeat == EventRepeat.weekdays) {
        if (current.weekday <= 5) dates.add(current);
      } else if (_repeat == EventRepeat.custom) {
        if (_customDays.containsKey(current.weekday)) dates.add(current);
      } else {
        dates.add(current);
      }
      current = _repeat == EventRepeat.weekly
          ? current.add(const Duration(days: 7))
          : current.add(const Duration(days: 1));
    }
    return dates;
  }

  List<(DateTime, DateTime)> _generateCustomOccurrences() {
    var current = _start;
    final result = <(DateTime, DateTime)>[];
    while (!current.isAfter(_repeatUntil)) {
      final schedule = _customDays[current.weekday];
      if (schedule != null) {
        final s = DateTime(current.year, current.month, current.day, schedule.start.hour, schedule.start.minute);
        final e = DateTime(current.year, current.month, current.day, schedule.end.hour, schedule.end.minute);
        result.add((s, e));
      }
      current = current.add(const Duration(days: 1));
    }
    return result;
  }

  void _toggleDay(int weekday) {
    setState(() {
      if (_customDays.containsKey(weekday)) {
        _customDays.remove(weekday);
      } else {
        _customDays[weekday] = (start: _globalHourStart, end: _globalHourEnd);
      }
    });
  }

  void _applyGlobalHours() {
    for (final wd in _customDays.keys.toList()) {
      _customDays[wd] = (start: _globalHourStart, end: _globalHourEnd);
    }
  }

  Future<void> _pickDateOnly(bool isStart) async {
    final date = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CalendarPickerSheet(
        title: isStart ? 'Starting from' : 'Ending on',
        initial: isStart ? _start : _end,
        first: DateTime.now().subtract(const Duration(days: 365)),
        last: DateTime.now().add(const Duration(days: 365 * 5)),
        highlightDate: isStart ? null : _start,
        highlightLabel: isStart ? null : 'Start',
      ),
    );
    if (date == null || !mounted) return;
    setState(() => isStart ? _start = date : _end = date);
  }

  Future<void> _pick(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      helpText: isStart ? 'START DATE' : 'END DATE',
      initialDate: isStart ? _start : _end,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (ctx, child) => Theme(data: _pickerTheme(ctx, helpText: ''), child: child!),
    );
    if (date == null || !mounted) return;
    if (_allDay) {
      setState(() => isStart ? _start = date : _end = date);
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isStart ? _start : _end),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: kPrimary)),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() => isStart ? _start = dt : _end = dt);
  }

  Future<void> _pickRepeatUntil() async {
    final date = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CalendarPickerSheet(
        title: 'Repeat until',
        initial: _repeatUntil,
        first: _start,
        last: DateTime.now().add(const Duration(days: 365 * 2)),
        highlightDate: _start,
        highlightLabel: 'Start',
      ),
    );
    if (date != null) setState(() => _repeatUntil = date);
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty) { setState(() => _error = 'Title is required'); return; }
    final title = _title.text.trim();
    final desc = _desc.text.trim().isEmpty ? null : _desc.text.trim();
    setState(() { _busy = true; _error = ''; _created = 0; });
    try {
      if (widget.isEditing) {
        // Single call for edit
        await widget.onAdd(title, desc, _start, _end, _allDay);
      } else if (_repeat == EventRepeat.custom) {
        final occurrences = _generateCustomOccurrences();
        if (occurrences.isEmpty) { setState(() { _error = 'No days selected or no dates in range'; _busy = false; }); return; }
        for (final (s, e) in occurrences) {
          await widget.onAdd(title, desc, s, e, false);
          if (mounted) setState(() => _created++);
        }
      } else {
        final dates = _generateDates();
        if (dates.isEmpty) { setState(() { _error = 'No dates in range'; _busy = false; }); return; }
        final duration = _end.difference(_start);
        for (final d in dates) {
          await widget.onAdd(title, desc, d, d.add(duration), _allDay);
          if (mounted) setState(() => _created++);
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _error = e.toString(); _busy = false; });
    }
  }

  int get _totalOccurrences => _repeat == EventRepeat.custom
      ? _generateCustomOccurrences().length
      : _generateDates().length;

  String get _submitLabel {
    if (widget.isEditing) return 'Save Changes';
    if (_repeat == EventRepeat.none) return 'Add Event';
    return 'Add $_totalOccurrences Event${_totalOccurrences == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: KalendrTheme.surface(context), borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.only(left: 24, right: 24, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(children: [
            Text(widget.isEditing ? 'Edit Event' : 'New Event',
                style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w800, color: KalendrTheme.text(context))),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: KalendrTheme.divider(context), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.close_rounded, size: 18, color: KalendrTheme.subtext(context)),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          _sheetField(_title, 'Event title', Icons.title_rounded),
          const SizedBox(height: 12),
          _sheetField(_desc, 'Description (optional)', Icons.notes_rounded),
          const SizedBox(height: 14),
          if (_repeat != EventRepeat.custom)
            _toggleRow(Icons.wb_sunny_outlined, 'All day', _allDay, (v) => setState(() => _allDay = v)),
          if (_repeat != EventRepeat.custom) const SizedBox(height: 10),
          _dateRow(
            _repeat == EventRepeat.custom ? 'Starting from' : 'Start',
            _start,
            () => _repeat == EventRepeat.custom ? _pickDateOnly(true) : _pick(true),
            dateOnly: _repeat == EventRepeat.custom,
          ),
          if (_repeat != EventRepeat.custom) ...[
            const SizedBox(height: 8),
            _dateRow('End', _end, () => _pick(false)),
          ],

          if (!widget.isEditing) ...[
            const SizedBox(height: 14),
            Text('Repeat', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: KalendrTheme.subtext(context))),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _repeatChip('None', EventRepeat.none),
              _repeatChip('Daily', EventRepeat.daily),
              _repeatChip('Weekdays', EventRepeat.weekdays),
              _repeatChip('Weekly', EventRepeat.weekly),
              _repeatChip('Custom', EventRepeat.custom),
            ]),
            if (_repeat != EventRepeat.none) ...[
              const SizedBox(height: 10),
              _dateRow('Until', _repeatUntil, _pickRepeatUntil, icon: Icons.event_repeat_rounded),
              const SizedBox(height: 8),
              _rangeChip(),
            ],
            if (_repeat == EventRepeat.custom) ...[
              const SizedBox(height: 14),
              // Same hours toggle
              _toggleRow(Icons.tune_rounded, 'Same hours every day', _sameHours, (v) {
                setState(() {
                  _sameHours = v;
                  if (v) _applyGlobalHours();
                });
              }),
              const SizedBox(height: 12),
              // Day chips row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [1, 2, 3, 4, 5, 6, 7].map((wd) {
                  final active = _customDays.containsKey(wd);
                  return GestureDetector(
                    onTap: () => _toggleDay(wd),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: active ? kPrimary : KalendrTheme.divider(context),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(child: Text(_dayLabels[wd - 1],
                          style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700,
                              color: active ? Colors.white : KalendrTheme.muted(context)))),
                    ),
                  );
                }).toList(),
              ),
              if (_customDays.isNotEmpty) ...[
                const SizedBox(height: 12),
                if (_sameHours) ...[
                  // Global time picker
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: KalendrTheme.field(context), borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      Icon(Icons.schedule_rounded, size: 16, color: KalendrTheme.muted(context)),
                      const SizedBox(width: 10),
                      Text('Hours', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: KalendrTheme.subtext(context))),
                      const Spacer(),
                      _timePill(_globalHourStart, () async {
                        final t = await showTimePicker(context: context, initialTime: _globalHourStart,
                            builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: kPrimary)), child: child!));
                        if (t != null) setState(() { _globalHourStart = t; _applyGlobalHours(); });
                      }),
                      Text('–', style: GoogleFonts.nunito(color: KalendrTheme.muted(context), fontSize: 14)),
                      _timePill(_globalHourEnd, () async {
                        final t = await showTimePicker(context: context, initialTime: _globalHourEnd,
                            builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: kPrimary)), child: child!));
                        if (t != null) setState(() { _globalHourEnd = t; _applyGlobalHours(); });
                      }),
                    ]),
                  ),
                ] else ...[
                  // Per-day individual pickers (only for selected days)
                  ...[1, 2, 3, 4, 5, 6, 7]
                      .where((wd) => _customDays.containsKey(wd))
                      .map((wd) => _customDayHoursRow(wd)),
                ],
              ],
            ],
            if (_repeat != EventRepeat.none && _repeat != EventRepeat.custom) ...[
              const SizedBox(height: 6),
              Text('${_generateDates().length} occurrences',
                  style: GoogleFonts.nunito(fontSize: 12, color: kPrimary, fontWeight: FontWeight.w600)),
            ],
            if (_repeat == EventRepeat.custom && _customDays.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('${_generateCustomOccurrences().length} occurrences',
                  style: GoogleFonts.nunito(fontSize: 12, color: kPrimary, fontWeight: FontWeight.w600)),
            ],
          ],

          if (_error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_error, style: const TextStyle(color: kPrimary, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _busy ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _busy
                  ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
                      if (!widget.isEditing) ...[
                        const SizedBox(width: 12),
                        Text('$_created / $_totalOccurrences', style: GoogleFonts.nunito(fontSize: 14, color: Colors.white)),
                      ],
                    ])
                  : Text(_submitLabel, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _customDayHoursRow(int weekday) {
    final schedule = _customDays[weekday]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: KalendrTheme.field(context), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Text(_weekdayNames[weekday - 1],
              style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: KalendrTheme.text(context))),
          const Spacer(),
          _timePill(schedule.start, () async {
            final t = await showTimePicker(context: context, initialTime: schedule.start,
                builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: kPrimary)), child: child!));
            if (t != null) setState(() => _customDays[weekday] = (start: t, end: schedule.end));
          }),
          Text('–', style: GoogleFonts.nunito(color: KalendrTheme.muted(context), fontSize: 14)),
          _timePill(schedule.end, () async {
            final t = await showTimePicker(context: context, initialTime: schedule.end,
                builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: kPrimary)), child: child!));
            if (t != null) setState(() => _customDays[weekday] = (start: schedule.start, end: t));
          }),
        ]),
      ),
    );
  }

  Widget _customDayRow(int weekday) {
    final active = _customDays.containsKey(weekday);
    final schedule = _customDays[weekday];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        GestureDetector(
          onTap: () {
            setState(() {
              if (active) {
                _customDays.remove(weekday);
              } else {
                _customDays[weekday] = (start: const TimeOfDay(hour: 9, minute: 0), end: const TimeOfDay(hour: 17, minute: 0));
              }
            });
          },
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: active ? kPrimary : KalendrTheme.divider(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(_dayLabels[weekday - 1],
                style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700,
                    color: active ? Colors.white : KalendrTheme.muted(context)))),
          ),
        ),
        const SizedBox(width: 10),
        if (active) ...[
          Expanded(child: Text(_weekdayNames[weekday - 1],
              style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: KalendrTheme.text(context)))),
          _timePill(schedule!.start, () async {
            final t = await showTimePicker(context: context, initialTime: schedule.start,
                builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: kPrimary)), child: child!));
            if (t != null) setState(() => _customDays[weekday] = (start: t, end: schedule.end));
          }),
          Text('–', style: GoogleFonts.nunito(color: KalendrTheme.muted(context), fontSize: 14)),
          _timePill(schedule.end, () async {
            final t = await showTimePicker(context: context, initialTime: schedule.end,
                builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: kPrimary)), child: child!));
            if (t != null) setState(() => _customDays[weekday] = (start: schedule.start, end: t));
          }),
        ] else
          Text(_weekdayNames[weekday - 1], style: GoogleFonts.nunito(fontSize: 13, color: KalendrTheme.muted(context))),
      ]),
    );
  }

  Widget _timePill(TimeOfDay t, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(color: KalendrTheme.field(context), borderRadius: BorderRadius.circular(8)),
        child: Text(t.format(context), style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: KalendrTheme.text(context))),
      ),
    );
  }

  Widget _rangeChip() {
    final startFmt = DateFormat('MMM d').format(_start);
    final endFmt = DateFormat('MMM d').format(_repeatUntil);
    final days = _repeatUntil.difference(_start).inDays + 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kPrimary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kPrimary.withOpacity(0.2)),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('From', style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700,
              color: kPrimary.withOpacity(0.7), letterSpacing: 0.5)),
          Text(startFmt, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800,
              color: kPrimary)),
        ])),
        Column(children: [
          Row(children: [
            Container(width: 16, height: 1.5, color: kPrimary.withOpacity(0.4)),
            const Icon(Icons.arrow_forward_rounded, size: 14, color: kPrimary),
          ]),
          const SizedBox(height: 2),
          Text('$days days', style: GoogleFonts.nunito(fontSize: 10, color: kPrimary.withOpacity(0.6))),
        ]),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('Until', style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700,
              color: kPrimary.withOpacity(0.7), letterSpacing: 0.5)),
          Text(endFmt, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800,
              color: kPrimary)),
        ])),
      ]),
    );
  }

  Widget _repeatChip(String label, EventRepeat value) {
    final active = _repeat == value;
    return GestureDetector(
      onTap: () => setState(() => _repeat = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? kPrimary : KalendrTheme.field(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600,
            color: active ? Colors.white : KalendrTheme.subtext(context))),
      ),
    );
  }

  Widget _toggleRow(IconData icon, String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: KalendrTheme.field(context), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.grey.shade400),
        const SizedBox(width: 10),
        Text(label, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w600, color: KalendrTheme.text(context))),
        const Spacer(),
        Switch(value: value, onChanged: onChanged, activeColor: kPrimary),
      ]),
    );
  }

  Widget _sheetField(TextEditingController ctrl, String hint, IconData icon) {
    return Container(
      decoration: BoxDecoration(color: KalendrTheme.field(context), borderRadius: BorderRadius.circular(14)),
      child: TextField(
        controller: ctrl,
        style: GoogleFonts.nunito(color: KalendrTheme.text(context), fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.nunito(color: KalendrTheme.muted(context)),
          prefixIcon: Icon(icon, color: KalendrTheme.muted(context), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _dateRow(String label, DateTime dt, VoidCallback onTap, {IconData? icon, bool dateOnly = false}) {
    final fmt = (_allDay || dateOnly) ? DateFormat('EEE, MMM d, y') : DateFormat('EEE, MMM d · HH:mm');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: KalendrTheme.field(context), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(icon ?? (label == 'Start' ? Icons.flight_takeoff_rounded : Icons.flight_land_rounded),
              size: 16, color: KalendrTheme.muted(context)),
          const SizedBox(width: 10),
          Text('$label  ', style: GoogleFonts.nunito(fontSize: 13, color: KalendrTheme.subtext(context))),
          Text(fmt.format(dt), style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: KalendrTheme.text(context))),
          const Spacer(),
          Icon(Icons.edit_calendar_rounded, size: 16, color: KalendrTheme.muted(context)),
        ]),
      ),
    );
  }
}

// ─── Custom calendar date picker sheet ───────────────────────────────────────

class CalendarPickerSheet extends StatefulWidget {
  final String title;
  final DateTime initial;
  final DateTime first;
  final DateTime last;
  final DateTime? highlightDate;   // reference date to mark (e.g. start date)
  final String? highlightLabel;    // label shown under the highlighted day
  final DateTime? rangeStart;      // when set, shades the range between rangeStart and selected
  final Color accentColor;         // main selection color

  const CalendarPickerSheet({
    super.key,
    required this.title,
    required this.initial,
    required this.first,
    required this.last,
    this.highlightDate,
    this.highlightLabel,
    this.rangeStart,
    this.accentColor = kPrimary,
  });

  @override
  State<CalendarPickerSheet> createState() => _CalendarPickerSheetState();
}

class _CalendarPickerSheetState extends State<CalendarPickerSheet> {
  late DateTime _selected;
  late DateTime _focused;

  static const _highlightColor = Color(0xFF3B82F6); // blue for the start marker

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
    _focused = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 14),

        // Title + legend
        Row(children: [
          Text(widget.title, style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF1A1A2E))),
          const Spacer(),
          Container(width: 10, height: 10,
              decoration: BoxDecoration(color: widget.accentColor, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text('Selected', style: GoogleFonts.nunito(fontSize: 12, color: widget.accentColor, fontWeight: FontWeight.w600)),
        ]),
        if (widget.highlightDate != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _highlightColor.withOpacity(0.07),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(border: Border.all(color: _highlightColor, width: 2), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(
                '${widget.highlightLabel ?? 'Ref'}: ${DateFormat('EEE, MMM d').format(widget.highlightDate!)}',
                style: GoogleFonts.nunito(fontSize: 12, color: _highlightColor, fontWeight: FontWeight.w600),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 8),

        TableCalendar(
          firstDay: widget.first,
          lastDay: widget.last,
          focusedDay: _focused,
          sixWeekMonthsEnforced: true,
          pageAnimationDuration: const Duration(milliseconds: 180),
          pageAnimationCurve: Curves.easeOut,
          selectedDayPredicate: (d) => isSameDay(d, _selected),
          rangeStartDay: widget.rangeStart,
          rangeEndDay: widget.rangeStart != null ? _selected : null,
          rangeSelectionMode: RangeSelectionMode.disabled,
          onDaySelected: (selected, focused) => setState(() { _selected = selected; _focused = focused; }),
          onPageChanged: (focused) => setState(() => _focused = focused),
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (ctx, day, _) {
              if (widget.highlightDate != null && isSameDay(day, widget.highlightDate!)) {
                return _highlightCell(day);
              }
              return null;
            },
            selectedBuilder: (ctx, day, _) {
              final isHighlight = widget.highlightDate != null && isSameDay(day, widget.highlightDate!);
              return _selectedCell(day, isHighlight: isHighlight);
            },
            todayBuilder: (ctx, day, _) {
              final isHighlight = widget.highlightDate != null && isSameDay(day, widget.highlightDate!);
              final isSelected = isSameDay(day, _selected);
              if (isSelected) return _selectedCell(day, isHighlight: isHighlight);
              if (isHighlight) return _highlightCell(day);
              return _todayCell(day);
            },
          ),
          calendarStyle: CalendarStyle(
            defaultTextStyle: GoogleFonts.nunito(color: const Color(0xFF1A1A2E)),
            weekendTextStyle: GoogleFonts.nunito(color: const Color(0xFF6B7280)),
            outsideTextStyle: GoogleFonts.nunito(color: Colors.grey.shade300),
            disabledTextStyle: GoogleFonts.nunito(color: Colors.grey.shade200),
            selectedDecoration: BoxDecoration(color: widget.accentColor, shape: BoxShape.circle),
            selectedTextStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: Colors.white),
            todayDecoration: BoxDecoration(border: Border.all(color: widget.accentColor), shape: BoxShape.circle),
            todayTextStyle: GoogleFonts.nunito(color: widget.accentColor, fontWeight: FontWeight.w700),
            rangeHighlightColor: widget.accentColor.withOpacity(0.15),
            rangeStartDecoration: BoxDecoration(color: widget.accentColor, shape: BoxShape.circle),
            rangeEndDecoration: BoxDecoration(color: widget.accentColor, shape: BoxShape.circle),
            withinRangeTextStyle: GoogleFonts.nunito(color: const Color(0xFF1A1A2E)),
            withinRangeDecoration: const BoxDecoration(shape: BoxShape.circle),
            cellMargin: const EdgeInsets.all(4),
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E)),
            leftChevronIcon: Icon(Icons.chevron_left_rounded, color: widget.accentColor),
            rightChevronIcon: Icon(Icons.chevron_right_rounded, color: widget.accentColor),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade500),
            weekendStyle: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade400),
          ),
        ),

        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context, _selected),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.accentColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: Text('Confirm ${DateFormat("MMM d").format(_selected)}',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
      ]),
    );
  }

  Widget _highlightCell(DateTime day) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _highlightColor, width: 2),
        color: _highlightColor.withOpacity(0.08),
      ),
      child: Center(child: Text('${day.day}',
          style: GoogleFonts.nunito(fontSize: 13, color: _highlightColor, fontWeight: FontWeight.w700))),
    );
  }

  Widget _selectedCell(DateTime day, {bool isHighlight = false}) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.accentColor,
        border: isHighlight ? Border.all(color: _highlightColor, width: 2.5) : null,
      ),
      child: Center(child: Text('${day.day}',
          style: GoogleFonts.nunito(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w800))),
    );
  }

  Widget _todayCell(DateTime day) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: widget.accentColor, width: 1.5),
      ),
      child: Center(child: Text('${day.day}',
          style: GoogleFonts.nunito(fontSize: 13, color: widget.accentColor, fontWeight: FontWeight.w700))),
    );
  }
}
