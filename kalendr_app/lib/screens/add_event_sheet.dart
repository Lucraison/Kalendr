import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../l10n/app_strings.dart';
import '../models/models.dart';
import '../theme.dart';
import 'calendar_picker_sheet.dart';

// ─── Custom drum-roll time picker ────────────────────────────────────────────

Future<TimeOfDay?> showKalendrTimePicker(
  BuildContext context,
  TimeOfDay initialTime, {
  Color accentColor = kPrimary,
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _KalendrTimePickerSheet(initialTime: initialTime, accentColor: accentColor),
  );
}

class _KalendrTimePickerSheet extends StatefulWidget {
  final TimeOfDay initialTime;
  final Color accentColor;
  const _KalendrTimePickerSheet({required this.initialTime, required this.accentColor});

  @override
  State<_KalendrTimePickerSheet> createState() => _KalendrTimePickerSheetState();
}

class _KalendrTimePickerSheetState extends State<_KalendrTimePickerSheet> {
  static const _minutes = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55];

  late int _hour;
  late int _minuteIdx;
  late final FixedExtentScrollController _hourCtrl;
  late final FixedExtentScrollController _minCtrl;

  static const _loopFactor = 500; // large enough to feel infinite

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minuteIdx = (widget.initialTime.minute / 5).round().clamp(0, 11);
    _hourCtrl = FixedExtentScrollController(initialItem: 24 * _loopFactor ~/ 2 + _hour);
    _minCtrl = FixedExtentScrollController(initialItem: 12 * _loopFactor ~/ 2 + _minuteIdx);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const itemH = 54.0;
    const wheelH = itemH * 5;
    final accent = widget.accentColor;
    final hh = _hour.toString().padLeft(2, '0');
    final mm = _minutes[_minuteIdx].toString().padLeft(2, '0');

    return Container(
      decoration: BoxDecoration(
        color: KalendrTheme.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
          child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(color: KalendrTheme.divider(context), borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 20),
        Text(context.s.selectTime, style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: KalendrTheme.text(context))),
        const SizedBox(height: 20),
        SizedBox(
          height: wheelH,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            // Hours 0–23
            SizedBox(
              width: 90,
              child: ListWheelScrollView.useDelegate(
                controller: _hourCtrl,
                itemExtent: itemH,
                physics: const FixedExtentScrollPhysics(),
                perspective: 0.003,
                onSelectedItemChanged: (i) => setState(() => _hour = i % 24),
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: 24 * _loopFactor,
                  builder: (ctx, i) {
                    final selected = i % 24 == _hour;
                    return Center(
                      child: Text(
                        (i % 24).toString().padLeft(2, '0'),
                        style: GoogleFonts.nunito(
                          fontSize: selected ? 36 : 24,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
                          color: selected ? accent : KalendrTheme.muted(ctx),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Text(':', style: GoogleFonts.nunito(fontSize: 36, fontWeight: FontWeight.w800, color: accent)),
            // Minutes in 5-min steps
            SizedBox(
              width: 90,
              child: ListWheelScrollView.useDelegate(
                controller: _minCtrl,
                itemExtent: itemH,
                physics: const FixedExtentScrollPhysics(),
                perspective: 0.003,
                onSelectedItemChanged: (i) => setState(() => _minuteIdx = i % _minutes.length),
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: _minutes.length * _loopFactor,
                  builder: (ctx, i) {
                    final selected = i % _minutes.length == _minuteIdx;
                    return Center(
                      child: Text(
                        _minutes[i % _minutes.length].toString().padLeft(2, '0'),
                        style: GoogleFonts.nunito(
                          fontSize: selected ? 36 : 24,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
                          color: selected ? accent : KalendrTheme.muted(ctx),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context, TimeOfDay(hour: _hour % 24, minute: _minutes[_minuteIdx % _minutes.length])),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: Text(context.s.confirmDate('$hh:$mm'), style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

// Shared date picker theme throughout the sheet

enum EventRepeat { none, daily, weekdays, weekly, custom }

class AddEventSheet extends StatefulWidget {
  final Future<void> Function(String title, String? desc, DateTime start, DateTime end, bool allDay, String? color, List<String> sharedGroupIds) onAdd;
  final Future<void> Function(String title, String? desc, List<(DateTime, DateTime)> occurrences, bool allDay, String? color, List<String> sharedGroupIds)? onAddBatch;
  final DateTime? initialDate;
  final String? groupId;
  final List<Group>? availableGroups;
  final bool isEditing;
  final String? initialTitle;
  final String? initialDesc;
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final bool? initialAllDay;
  final String? initialColor;
  final List<String>? initialSharedGroupIds;

  const AddEventSheet({
    super.key,
    required this.onAdd,
    this.onAddBatch,
    this.initialDate,
    this.groupId,
    this.availableGroups,
    this.isEditing = false,
    this.initialTitle,
    this.initialDesc,
    this.initialStart,
    this.initialEnd,
    this.initialAllDay,
    this.initialColor,
    this.initialSharedGroupIds,
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
  bool _repeatForever = false;
  DateTime get _effectiveRepeatUntil =>
      _repeatForever ? _start.add(const Duration(days: 365)) : _repeatUntil;
  final Map<int, ({TimeOfDay start, TimeOfDay end})> _customDays = {};
  bool _sameHours = true;
  TimeOfDay _globalHourStart = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _globalHourEnd = const TimeOfDay(hour: 17, minute: 0);
  bool _busy = false;
  String _error = '';
  int _created = 0;
  String? _color;
  List<String> _sharedGroupIds = [];

  Color get _accent => _color != null ? hexToColor(_color!) : _accent;

  static const _colorOptions = [
    '#FF6B6B', '#8338EC', '#3B82F6', '#0D9488',
    '#F97316', '#06D6A0', '#FFBE0B', '#EF4444',
  ];

  // Weekday labels are loaded from AppStrings at build time via context.s

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
    _color = widget.initialColor ?? _colorOptions[0];
    _sharedGroupIds = List.from(widget.initialSharedGroupIds ?? []);
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  // Advance by calendar day/week to preserve wall-clock time across DST transitions.
  static DateTime _addDays(DateTime dt, int days) =>
      DateTime(dt.year, dt.month, dt.day + days, dt.hour, dt.minute, dt.second);

  List<DateTime> _generateDates() {
    if (_repeat == EventRepeat.none) return [_start];
    final dates = <DateTime>[];
    var current = _start;
    while (!current.isAfter(_effectiveRepeatUntil)) {
      if (_repeat == EventRepeat.weekdays) {
        if (current.weekday <= 5) dates.add(current);
      } else if (_repeat == EventRepeat.custom) {
        if (_customDays.containsKey(current.weekday)) dates.add(current);
      } else {
        dates.add(current);
      }
      current = _repeat == EventRepeat.weekly
          ? _addDays(current, 7)
          : _addDays(current, 1);
    }
    return dates;
  }

  List<(DateTime, DateTime)> _generateCustomOccurrences() {
    var current = _start;
    final result = <(DateTime, DateTime)>[];
    while (!current.isAfter(_effectiveRepeatUntil)) {
      final schedule = _customDays[current.weekday];
      if (schedule != null) {
        final s = DateTime(current.year, current.month, current.day, schedule.start.hour, schedule.start.minute);
        final e = DateTime(current.year, current.month, current.day, schedule.end.hour, schedule.end.minute);
        result.add((s, e));
      }
      current = _addDays(current, 1);
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
    final s = context.s;
    final date = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CalendarPickerSheet(
        title: isStart ? s.startingFrom : s.endingOn,
        initial: isStart ? _start : _end,
        first: DateTime.now().subtract(const Duration(days: 365)),
        last: DateTime.now().add(const Duration(days: 365 * 5)),
        highlightDate: isStart ? null : _start,
        highlightLabel: isStart ? null : s.start,
      ),
    );
    if (date == null || !mounted) return;
    setState(() {
      if (isStart) {
        _start = date;
        if (!_repeatUntil.isAfter(_start)) _repeatUntil = _start.add(const Duration(days: 7));
      } else {
        _end = date;
      }
    });
  }

  Future<void> _pickDatePart(bool isStart) async {
    final s = context.s;
    final current = isStart ? _start : _end;
    final date = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CalendarPickerSheet(
        title: isStart ? s.startDate : s.endDate,
        initial: current,
        first: DateTime.now().subtract(const Duration(days: 365)),
        last: DateTime.now().add(const Duration(days: 365 * 5)),
        highlightDate: isStart ? null : _start,
        highlightLabel: isStart ? null : s.start,
        rangeStart: isStart ? null : _start,
        accentColor: _accent,
      ),
    );
    if (date == null || !mounted) return;
    DateTime dt = DateTime(date.year, date.month, date.day, current.hour, current.minute);
    setState(() {
      if (isStart) {
        _start = dt;
        _end = _start.add(const Duration(hours: 1));
        if (!_repeatUntil.isAfter(_start)) _repeatUntil = _start.add(const Duration(days: 7));
      } else {
        if (!dt.isAfter(_start)) dt = DateTime(_start.year, _start.month, _start.day + 1, dt.hour, dt.minute);
        _end = dt;
      }
    });
  }

  Future<void> _pickTimePart(bool isStart) async {
    final current = isStart ? _start : _end;
    final time = await showKalendrTimePicker(context, TimeOfDay.fromDateTime(current), accentColor: _accent);
    if (time == null || !mounted) return;
    DateTime dt = DateTime(current.year, current.month, current.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _start = dt;
        _end = _start.add(const Duration(hours: 1));
      } else {
        if (!dt.isAfter(_start)) dt = DateTime(_start.year, _start.month, _start.day + 1, dt.hour, dt.minute);
        _end = dt;
      }
    });
  }

  Future<void> _pickRepeatUntil() async {
    final s = context.s;
    final date = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CalendarPickerSheet(
        title: s.repeatUntil,
        initial: _repeatUntil,
        first: _start,
        last: DateTime.now().add(const Duration(days: 365 * 2)),
        highlightDate: _start,
        highlightLabel: s.start,
        rangeStart: _start,
      ),
    );
    if (date != null) setState(() => _repeatUntil = DateTime(date.year, date.month, date.day, 23, 59));
  }

  Future<void> _submit() async {
    final s = context.s;
    if (_title.text.trim().isEmpty) { setState(() => _error = s.titleRequired); return; }
    if (!_allDay && !_end.isAfter(_start)) { setState(() => _error = s.endAfterStart); return; }
    final title = _title.text.trim();
    final desc = _desc.text.trim().isEmpty ? null : _desc.text.trim();
    setState(() { _busy = true; _error = ''; _created = 0; });
    try {
      if (widget.isEditing) {
        // Single call for edit
        await widget.onAdd(title, desc, _start, _end, _allDay, _color, _sharedGroupIds);
      } else if (_repeat == EventRepeat.custom) {
        final occurrences = _generateCustomOccurrences();
        if (occurrences.isEmpty) { setState(() { _error = s.noDaysSelected; _busy = false; }); return; }
        if (widget.onAddBatch != null) {
          await widget.onAddBatch!(title, desc, occurrences, false, _color, _sharedGroupIds);
        } else {
          for (final (st, e) in occurrences) {
            await widget.onAdd(title, desc, st, e, false, _color, _sharedGroupIds);
            if (mounted) setState(() => _created++);
          }
        }
      } else {
        final dates = _generateDates();
        if (dates.isEmpty) { setState(() { _error = s.noDatesInRange; _busy = false; }); return; }
        final duration = _end.difference(_start);
        final occurrences = dates.map((d) => (d, d.add(duration))).toList();
        if (widget.onAddBatch != null) {
          await widget.onAddBatch!(title, desc, occurrences, _allDay, _color, _sharedGroupIds);
        } else {
          for (final (st, e) in occurrences) {
            await widget.onAdd(title, desc, st, e, _allDay, _color, _sharedGroupIds);
            if (mounted) setState(() => _created++);
          }
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

  String _submitLabel(AppStrings s) {
    if (widget.isEditing) return s.saveChanges;
    if (_repeat == EventRepeat.none) return s.addEvent;
    return s.addEvents(_totalOccurrences);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final dayLabels = s.weekdayShort;
    final weekdayNames = s.weekdayNames;
    return Container(
      decoration: BoxDecoration(color: KalendrTheme.surface(context), borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.only(left: 24, right: 24, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(children: [
            Text(widget.isEditing ? s.editEvent : s.newEvent,
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
          _sheetField(_title, s.eventTitle, Icons.title_rounded),
          const SizedBox(height: 12),
          _sheetField(_desc, s.descriptionOptional, Icons.notes_rounded),
          const SizedBox(height: 14),
          if (_repeat != EventRepeat.custom)
            _toggleRow(Icons.wb_sunny_outlined, s.allDay, _allDay, (v) => setState(() => _allDay = v)),
          if (_repeat != EventRepeat.custom) const SizedBox(height: 10),

          // Color picker and group visibility — only for personal events
          if (widget.groupId == null) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _colorOptions.map((hex) {
                final col = hexToColor(hex);
                final selected = _color?.toUpperCase() == hex.toUpperCase();
                return GestureDetector(
                  onTap: () => setState(() => _color = hex),
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
              }).toList(),
            ),
            const SizedBox(height: 8),
            if ((widget.availableGroups ?? []).isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(s.visibleTo, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: KalendrTheme.subtext(context))),
              const SizedBox(height: 8),
              ...((widget.availableGroups ?? []).map((g) {
                final isShared = _sharedGroupIds.contains(g.id);
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(color: KalendrTheme.field(context), borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    Icon(Icons.group_rounded, size: 18, color: _accent),
                    const SizedBox(width: 10),
                    Text(g.name, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w600, color: KalendrTheme.text(context))),
                    const Spacer(),
                    Switch(
                      value: isShared,
                      activeColor: _accent,
                      onChanged: (v) {
                        setState(() {
                          if (v) {
                            _sharedGroupIds.add(g.id);
                          } else {
                            _sharedGroupIds.remove(g.id);
                          }
                        });
                      },
                    ),
                  ]),
                );
              })),
              const SizedBox(height: 4),
            ],
          ],

          _dateRow(
            _repeat == EventRepeat.custom ? s.startingFrom : s.start,
            _start,
            _repeat == EventRepeat.custom ? () => _pickDateOnly(true) : () => _pickDatePart(true),
            onTimeTap: _allDay ? null : () => _pickTimePart(true),
            isStart: true,
            dateOnly: _repeat == EventRepeat.custom,
            timeOnly: widget.isEditing && !_allDay,
          ),
          if (_start.isBefore(DateTime.now())) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange.shade400),
                const SizedBox(width: 4),
                Text(s.startTimeInPast,
                    style: GoogleFonts.nunito(fontSize: 12, color: Colors.orange.shade400)),
              ]),
            ),
          ],
          if (_repeat != EventRepeat.custom && !_allDay) ...[
            const SizedBox(height: 8),
            _dateRow(
              _repeat == EventRepeat.none ? s.end : s.endTime,
              _end,
              () => _pickDatePart(false),
              onTimeTap: () => _pickTimePart(false),
              timeOnly: _repeat != EventRepeat.none || widget.isEditing,
            ),
          ],

          if (!widget.isEditing) ...[
            const SizedBox(height: 14),
            Text(s.repeat, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: KalendrTheme.subtext(context))),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _repeatChip(s.repeatNone, EventRepeat.none),
              _repeatChip(s.repeatDaily, EventRepeat.daily),
              _repeatChip(s.repeatWeekdays, EventRepeat.weekdays),
              _repeatChip(s.repeatWeekly, EventRepeat.weekly),
              _repeatChip(s.custom, EventRepeat.custom),
            ]),
            if (_repeat != EventRepeat.none) ...[
              const SizedBox(height: 10),
              _toggleRow(Icons.all_inclusive_rounded, s.noEndDate, _repeatForever,
                  (v) => setState(() => _repeatForever = v)),
              if (!_repeatForever) ...[
                const SizedBox(height: 8),
                _dateRow(s.repeatUntil, _repeatUntil, _pickRepeatUntil, icon: Icons.event_repeat_rounded, dateOnly: true),
                const SizedBox(height: 8),
                _rangeChip(),
              ],
              if (_repeatForever) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _accent.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    Icon(Icons.all_inclusive_rounded, size: 15, color: _accent),
                    const SizedBox(width: 8),
                    Text(s.repeatsUpTo1Year,
                        style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: _accent)),
                  ]),
                ),
              ],
            ],
            if (_repeat == EventRepeat.custom) ...[
              const SizedBox(height: 14),
              // Same hours toggle
              _toggleRow(Icons.tune_rounded, s.sameHoursEveryDay, _sameHours, (v) {
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
                        color: active ? _accent : KalendrTheme.divider(context),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(child: Text(dayLabels[wd - 1],
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
                      Text(s.hours, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: KalendrTheme.subtext(context))),
                      const Spacer(),
                      _timePill(_globalHourStart, () async {
                        final t = await showKalendrTimePicker(context, _globalHourStart);
                        if (t != null) setState(() { _globalHourStart = t; _applyGlobalHours(); });
                      }),
                      Text('–', style: GoogleFonts.nunito(color: KalendrTheme.muted(context), fontSize: 14)),
                      _timePill(_globalHourEnd, () async {
                        final t = await showKalendrTimePicker(context, _globalHourEnd);
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
              Text(s.addEvents(_generateDates().length),
                  style: GoogleFonts.nunito(fontSize: 12, color: _accent, fontWeight: FontWeight.w600)),
            ],
            if (_repeat == EventRepeat.custom && _customDays.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(s.addEvents(_generateCustomOccurrences().length),
                  style: GoogleFonts.nunito(fontSize: 12, color: _accent, fontWeight: FontWeight.w600)),
            ],
          ],

          if (_error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_error, style: TextStyle(color: _accent, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _busy ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
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
                  : Text(_submitLabel(s), style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _customDayHoursRow(int weekday) {
    final schedule = _customDays[weekday]!;
    final wdNames = context.s.weekdayNames;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: KalendrTheme.field(context), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Text(wdNames[weekday - 1],
              style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: KalendrTheme.text(context))),
          const Spacer(),
          _timePill(schedule.start, () async {
            final t = await showKalendrTimePicker(context, schedule.start);
            if (t != null) setState(() => _customDays[weekday] = (start: t, end: schedule.end));
          }),
          Text('–', style: GoogleFonts.nunito(color: KalendrTheme.muted(context), fontSize: 14)),
          _timePill(schedule.end, () async {
            final t = await showKalendrTimePicker(context, schedule.end);
            if (t != null) setState(() => _customDays[weekday] = (start: schedule.start, end: t));
          }),
        ]),
      ),
    );
  }

  Widget _customDayRow(int weekday) {
    final active = _customDays.containsKey(weekday);
    final schedule = _customDays[weekday];
    final s = context.s;
    final dayLabels = s.weekdayShort;
    final wdNames = s.weekdayNames;
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
              color: active ? _accent : KalendrTheme.divider(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(dayLabels[weekday - 1],
                style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700,
                    color: active ? Colors.white : KalendrTheme.muted(context)))),
          ),
        ),
        const SizedBox(width: 10),
        if (active) ...[
          Expanded(child: Text(wdNames[weekday - 1],
              style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: KalendrTheme.text(context)))),
          _timePill(schedule!.start, () async {
            final t = await showKalendrTimePicker(context, schedule.start);
            if (t != null) setState(() => _customDays[weekday] = (start: t, end: schedule.end));
          }),
          Text('–', style: GoogleFonts.nunito(color: KalendrTheme.muted(context), fontSize: 14)),
          _timePill(schedule.end, () async {
            final t = await showKalendrTimePicker(context, schedule.end);
            if (t != null) setState(() => _customDays[weekday] = (start: schedule.start, end: t));
          }),
        ] else
          Text(wdNames[weekday - 1], style: GoogleFonts.nunito(fontSize: 13, color: KalendrTheme.muted(context))),
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
    final s = context.s;
    final startFmt = DateFormat('MMM d').format(_start);
    final endFmt = DateFormat('MMM d').format(_repeatUntil);
    final days = _repeatUntil.difference(_start).inDays + 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _accent.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accent.withOpacity(0.2)),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.from, style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700,
              color: _accent.withOpacity(0.7), letterSpacing: 0.5)),
          Text(startFmt, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800,
              color: _accent)),
        ])),
        Column(children: [
          Row(children: [
            Container(width: 16, height: 1.5, color: _accent.withOpacity(0.4)),
            Icon(Icons.arrow_forward_rounded, size: 14, color: _accent),
          ]),
          const SizedBox(height: 2),
          Text(s.daysCount(days), style: GoogleFonts.nunito(fontSize: 10, color: _accent.withOpacity(0.6))),
        ]),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(s.until, style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700,
              color: _accent.withOpacity(0.7), letterSpacing: 0.5)),
          Text(endFmt, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800,
              color: _accent)),
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
          color: active ? _accent : KalendrTheme.field(context),
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
        Switch(value: value, onChanged: onChanged, activeColor: _accent),
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

  Widget _dateRow(String label, DateTime dt, VoidCallback onDateTap, {VoidCallback? onTimeTap, IconData? icon, bool isStart = false, bool dateOnly = false, bool timeOnly = false}) {
    final IconData rowIcon = icon ?? (isStart ? Icons.login_rounded : Icons.logout_rounded);
    final dateFmt = DateFormat('EEE, MMM d');
    final timeFmt = DateFormat('HH:mm');
    final showTime = !_allDay && !dateOnly;

    Widget chip(String text, VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: KalendrTheme.surface(context),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: KalendrTheme.text(context))),
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: KalendrTheme.field(context), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(rowIcon, size: 16, color: KalendrTheme.muted(context)),
        const SizedBox(width: 10),
        Text('$label  ', style: GoogleFonts.nunito(fontSize: 13, color: KalendrTheme.subtext(context))),
        const Spacer(),
        if (!timeOnly) chip(showTime ? dateFmt.format(dt) : DateFormat('EEE, MMM d, y').format(dt), onDateTap),
        if (showTime) ...[
          if (!timeOnly) const SizedBox(width: 6),
          chip(timeFmt.format(dt), onTimeTap ?? onDateTap),
        ],
      ]),
    );
  }
}

