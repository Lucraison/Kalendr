import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../l10n/app_strings.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import 'add_event_sheet.dart';
import 'calendar_picker_sheet.dart';

const _kWorkColor = Color(0xFF3B82F6);

class AddWorkScheduleSheet extends StatefulWidget {
  final Future<void> Function(String title, String? desc, DateTime start, DateTime end, bool isAllDay, List<String> sharedGroupIds) onAdd;
  final Future<void> Function(String title, List<(DateTime, DateTime)> occurrences, List<String> sharedGroupIds)? onAddBatch;
  final DateTime? initialDate;
  final List<Group> availableGroups;

  const AddWorkScheduleSheet({
    super.key,
    required this.onAdd,
    this.onAddBatch,
    this.initialDate,
    this.availableGroups = const [],
  });

  @override
  State<AddWorkScheduleSheet> createState() => _AddWorkScheduleSheetState();
}

class _AddWorkScheduleSheetState extends State<AddWorkScheduleSheet> {
  late final TextEditingController _name;
  final Set<int> _selectedDays = {1, 2, 3, 4, 5}; // Mon–Fri by default
  bool _sameHours = true;
  late List<({TimeOfDay start, TimeOfDay end})> _globalShifts;
  final Map<int, List<({TimeOfDay start, TimeOfDay end})>> _dayHours = {};
  late DateTime _from;
  late DateTime _until;
  String? _presetLabel = '1M'; // null = custom
  bool _busy = false;
  String _error = '';
  int _created = 0;
  List<String> _sharedGroupIds = [];

  static const _presets = ['1W', '2W', '1M', '3M'];
  static const _defaultStart = TimeOfDay(hour: 9, minute: 0);
  static const _defaultEnd = TimeOfDay(hour: 17, minute: 0);
  static const _secondShiftStart = TimeOfDay(hour: 18, minute: 0);
  static const _secondShiftEnd = TimeOfDay(hour: 22, minute: 0);

  // ── TimeOfDay arithmetic ──────────────────────────────────────────────────

  static int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  static TimeOfDay _fromMinutes(int m) {
    final clamped = m.clamp(0, 23 * 60 + 59);
    return TimeOfDay(hour: clamped ~/ 60, minute: clamped % 60);
  }

  /// Ensures shifts are ordered with no overlaps.
  /// Rules:
  ///   • Each shift's end must be ≥ start + 30 min (auto-corrects to start + 60)
  ///   • Each shift's start must be ≥ previous shift's end + 15 min (auto-pushes forward)
  List<({TimeOfDay start, TimeOfDay end})> _correctShifts(
      List<({TimeOfDay start, TimeOfDay end})> shifts) {
    if (shifts.isEmpty) return shifts;
    final result = <({TimeOfDay start, TimeOfDay end})>[];
    for (int i = 0; i < shifts.length; i++) {
      var s = shifts[i].start;
      var e = shifts[i].end;
      if (i > 0) {
        final minStart = _fromMinutes(_toMinutes(result[i - 1].end) + 15);
        if (_toMinutes(s) < _toMinutes(minStart)) s = minStart;
      }
      final minEnd = _fromMinutes(_toMinutes(s) + 30);
      if (_toMinutes(e) < _toMinutes(minEnd)) e = _fromMinutes(_toMinutes(s) + 60);
      result.add((start: s, end: e));
    }
    return result;
  }

  DateTime _untilForPreset(String label, DateTime from) {
    switch (label) {
      case '1W': return from.add(const Duration(days: 6));
      case '2W': return from.add(const Duration(days: 13));
      case '1M': return DateTime(from.year, from.month + 1, from.day).subtract(const Duration(days: 1));
      case '3M': return DateTime(from.year, from.month + 3, from.day).subtract(const Duration(days: 1));
      default:   return from.add(const Duration(days: 6));
    }
  }

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: 'Work');
    final base = widget.initialDate ?? DateTime.now();
    _from = DateTime(base.year, base.month, base.day);
    _until = _untilForPreset('1M', _from);
    _globalShifts = [(start: _defaultStart, end: _defaultEnd)];
    for (final d in _selectedDays) {
      _dayHours[d] = List.from(_globalShifts);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _toggleDay(int weekday) {
    setState(() {
      if (_selectedDays.contains(weekday)) {
        _selectedDays.remove(weekday);
        _dayHours.remove(weekday);
      } else {
        _selectedDays.add(weekday);
        _dayHours[weekday] = List.from(_globalShifts);
      }
    });
  }

  void _applyGlobalHours() {
    for (final d in _selectedDays) {
      _dayHours[d] = List.from(_globalShifts);
    }
  }

  List<(DateTime, DateTime)> _generateOccurrences() {
    final result = <(DateTime, DateTime)>[];
    var current = _from;
    while (!current.isAfter(_until)) {
      final wd = current.weekday;
      if (_selectedDays.contains(wd)) {
        final shifts = _dayHours[wd] ?? _globalShifts;
        for (final shift in shifts) {
          final s = DateTime(current.year, current.month, current.day, shift.start.hour, shift.start.minute);
          final e = DateTime(current.year, current.month, current.day, shift.end.hour, shift.end.minute);
          result.add((s, e));
        }
      }
      current = current.add(const Duration(days: 1));
    }
    return result;
  }

  Future<void> _pickFrom() async {
    final s = context.s;
    final date = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CalendarPickerSheet(
        title: s.startingFrom,
        initial: _from,
        first: DateTime.now().subtract(const Duration(days: 365)),
        last: DateTime.now().add(const Duration(days: 365 * 5)),
        accentColor: _kWorkColor,
      ),
    );
    if (date != null && mounted) {
      setState(() {
        _from = date;
        if (_presetLabel != null) {
          _until = _untilForPreset(_presetLabel!, _from);
        } else if (_until.isBefore(_from)) {
          _until = _untilForPreset('1M', _from);
        }
      });
    }
  }

  Future<void> _pickCustomUntil() async {
    final s = context.s;
    final date = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CalendarPickerSheet(
        title: s.repeatUntil,
        initial: _until,
        first: _from,
        last: DateTime.now().add(const Duration(days: 365 * 2)),
        highlightDate: _from,
        highlightLabel: s.start,
        rangeStart: _from,
        accentColor: _kWorkColor,
      ),
    );
    if (date != null && mounted) setState(() { _until = date; _presetLabel = null; });
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay initial) =>
      showKalendrTimePicker(context, initial, accentColor: _kWorkColor);

  Future<void> _submit() async {
    if (_busy) return;
    final s = context.s;
    if (_name.text.trim().isEmpty) { setState(() => _error = s.nameRequired); return; }
    if (_selectedDays.isEmpty) { setState(() => _error = s.selectAtLeastOneDay); return; }
    final occurrences = _generateOccurrences();
    if (occurrences.isEmpty) { setState(() => _error = s.noShiftsInRange); return; }
    setState(() { _busy = true; _error = ''; _created = 0; });
    try {
      final title = _name.text.trim();
      if (widget.onAddBatch != null) {
        await widget.onAddBatch!(title, occurrences, _sharedGroupIds);
      } else {
        for (final (s, e) in occurrences) {
          await widget.onAdd(title, null, s, e, false, _sharedGroupIds);
          if (mounted) setState(() => _created++);
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (_created > 0) {
        if (mounted) Navigator.pop(context);
      } else {
        setState(() { _error = e.toString(); _busy = false; });
      }
    }
  }

  int get _shiftCount => _generateOccurrences().length;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final dayLabels = s.weekdayShort;
    return Container(
      decoration: BoxDecoration(
        color: KalendrTheme.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),

          // Header
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _kWorkColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.work_outline_rounded, color: _kWorkColor, size: 18),
            ),
            const SizedBox(width: 12),
            Text(s.workSchedule, style: GoogleFonts.nunito(
                fontSize: 22, fontWeight: FontWeight.w800, color: KalendrTheme.text(context))),
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

          // Name field
          Container(
            decoration: BoxDecoration(color: KalendrTheme.field(context), borderRadius: BorderRadius.circular(14)),
            child: TextField(
              controller: _name,
              style: GoogleFonts.nunito(color: KalendrTheme.text(context), fontSize: 15),
              decoration: InputDecoration(
                hintText: s.scheduleNameHint,
                hintStyle: GoogleFonts.nunito(color: KalendrTheme.muted(context)),
                prefixIcon: Icon(Icons.badge_outlined, color: KalendrTheme.muted(context), size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Work days
          Text(s.workDays, style: GoogleFonts.nunito(
              fontSize: 13, fontWeight: FontWeight.w700, color: KalendrTheme.subtext(context))),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [1, 2, 3, 4, 5, 6, 7].map((wd) {
              final active = _selectedDays.contains(wd);
              return GestureDetector(
                onTap: () => _toggleDay(wd),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: active ? _kWorkColor : KalendrTheme.divider(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: Text(dayLabels[wd - 1],
                      style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700,
                          color: active ? Colors.white : KalendrTheme.muted(context)))),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Hours toggle
          _toggleRow(Icons.tune_rounded, s.sameHoursEveryDay, _sameHours, (v) {
            setState(() { _sameHours = v; if (v) _applyGlobalHours(); });
          }),
          if (_selectedDays.isNotEmpty) ...[
            const SizedBox(height: 10),
            if (_sameHours)
              _globalShiftsCard()
            else ...[
              ...[1, 2, 3, 4, 5, 6, 7]
                  .where((wd) => _selectedDays.contains(wd))
                  .map((wd) => _dayHoursRow(wd)),
            ],
          ],
          const SizedBox(height: 14),

          // Date range
          Text(s.dateRange, style: GoogleFonts.nunito(
              fontSize: 13, fontWeight: FontWeight.w700, color: KalendrTheme.subtext(context))),
          const SizedBox(height: 8),
          _dateRow(s.from, _from, _pickFrom, isStart: true),
          const SizedBox(height: 12),
          Text(s.duration, style: GoogleFonts.nunito(
              fontSize: 13, fontWeight: FontWeight.w700, color: KalendrTheme.subtext(context))),
          const SizedBox(height: 8),
          Row(children: [
            ..._presets.map((p) {
              final active = _presetLabel == p;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _presetLabel = p;
                    _until = _untilForPreset(p, _from);
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: active ? _kWorkColor : KalendrTheme.field(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: active ? _kWorkColor : KalendrTheme.divider(context),
                      ),
                    ),
                    child: Text(p, style: GoogleFonts.nunito(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: active ? Colors.white : KalendrTheme.subtext(context),
                    )),
                  ),
                ),
              );
            }),
            GestureDetector(
              onTap: _pickCustomUntil,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: _presetLabel == null ? _kWorkColor : KalendrTheme.field(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _presetLabel == null ? _kWorkColor : KalendrTheme.divider(context),
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    _presetLabel == null
                        ? DateFormat('MMM d').format(_until)
                        : s.custom,
                    style: GoogleFonts.nunito(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: _presetLabel == null ? Colors.white : KalendrTheme.subtext(context),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.edit_calendar_rounded, size: 12,
                      color: _presetLabel == null ? Colors.white70 : KalendrTheme.muted(context)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          _rangeChip(),
          if (_shiftCount > 0) ...[
            const SizedBox(height: 6),
            Text(s.shiftCount(_shiftCount),
                style: GoogleFonts.nunito(fontSize: 12, color: _kWorkColor, fontWeight: FontWeight.w600)),
          ],

          if (widget.availableGroups.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(s.visibleTo, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: KalendrTheme.subtext(context))),
            const SizedBox(height: 8),
            ...widget.availableGroups.map((g) {
              final isShared = _sharedGroupIds.contains(g.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: KalendrTheme.field(context), borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    Icon(Icons.group_rounded, size: 18, color: _kWorkColor),
                    const SizedBox(width: 10),
                    Text(g.name, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w600, color: KalendrTheme.text(context))),
                    const Spacer(),
                    Switch(
                      value: isShared,
                      activeColor: _kWorkColor,
                      onChanged: (v) => setState(() {
                        if (v) _sharedGroupIds.add(g.id);
                        else _sharedGroupIds.remove(g.id);
                      }),
                    ),
                  ]),
                ),
              );
            }),
          ],

          if (_error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_error, style: const TextStyle(color: _kWorkColor, fontSize: 13)),
          ],
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton(
              onPressed: _busy ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kWorkColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _busy
                  ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
                      const SizedBox(width: 12),
                      Text('$_created / $_shiftCount',
                          style: GoogleFonts.nunito(fontSize: 14, color: Colors.white)),
                    ])
                  : Text(
                      _shiftCount > 0 ? s.addShifts(_shiftCount) : s.addWorkSchedule,
                      style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Global shifts card (same hours mode) ─────────────────────────────────

  Widget _globalShiftsCard() {
    final s = context.s;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: KalendrTheme.field(context), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...List.generate(_globalShifts.length, (i) {
            final shift = _globalShifts[i];
            final isLast = i == _globalShifts.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
              child: Row(children: [
                if (i == 0) ...[
                  Icon(Icons.schedule_rounded, size: 16, color: KalendrTheme.muted(context)),
                  const SizedBox(width: 10),
                  Text(s.hours, style: GoogleFonts.nunito(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: KalendrTheme.subtext(context),
                  )),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(left: 26),
                    child: Text('↳', style: GoogleFonts.nunito(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: KalendrTheme.muted(context),
                    )),
                  ),
                const Spacer(),
                _timePill(shift.start, () async {
                  final t = await _pickTime(shift.start);
                  if (t != null) {
                    setState(() {
                      final updated = List<({TimeOfDay start, TimeOfDay end})>.from(_globalShifts);
                      updated[i] = (start: t, end: shift.end);
                      _globalShifts = _correctShifts(updated);
                      _applyGlobalHours();
                    });
                  }
                }),
                Text('–', style: GoogleFonts.nunito(color: KalendrTheme.muted(context), fontSize: 14)),
                _timePill(shift.end, () async {
                  final t = await _pickTime(shift.end);
                  if (t != null) {
                    setState(() {
                      final updated = List<({TimeOfDay start, TimeOfDay end})>.from(_globalShifts);
                      updated[i] = (start: shift.start, end: t);
                      _globalShifts = _correctShifts(updated);
                      _applyGlobalHours();
                    });
                  }
                }),
                if (_globalShifts.length > 1) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        final updated = List<({TimeOfDay start, TimeOfDay end})>.from(_globalShifts);
                        updated.removeAt(i);
                        _globalShifts = updated;
                        _applyGlobalHours();
                      });
                    },
                    child: Icon(Icons.remove_circle_outline_rounded, size: 18, color: Colors.red.shade300),
                  ),
                ],
              ]),
            );
          }),
          if (_globalShifts.length < 2) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                setState(() {
                  final afterEnd = _fromMinutes(_toMinutes(_globalShifts.last.end) + 60);
                  final proposed = (start: afterEnd, end: _fromMinutes(_toMinutes(afterEnd) + 120));
                  _globalShifts = _correctShifts([..._globalShifts, proposed]);
                  _applyGlobalHours();
                });
              },
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.add_circle_outline_rounded, size: 16, color: _kWorkColor),
                const SizedBox(width: 6),
                Text(s.addSecondShift,
                    style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: _kWorkColor)),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  // ── Per-day shift row (different hours mode) ──────────────────────────────

  Widget _dayHoursRow(int weekday) {
    final shifts = _dayHours[weekday]!;
    final wdNames = context.s.weekdayNames;
    final s = context.s;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: KalendrTheme.field(context), borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...List.generate(shifts.length, (i) {
              final shift = shifts[i];
              final isLast = i == shifts.length - 1;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                child: Row(children: [
                  if (i == 0)
                    Text(wdNames[weekday - 1],
                        style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: KalendrTheme.text(context)))
                  else
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text('↳', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: KalendrTheme.muted(context))),
                    ),
                  const Spacer(),
                  _timePill(shift.start, () async {
                    final t = await _pickTime(shift.start);
                    if (t != null) {
                      setState(() {
                        final updated = List<({TimeOfDay start, TimeOfDay end})>.from(shifts);
                        updated[i] = (start: t, end: shift.end);
                        _dayHours[weekday] = _correctShifts(updated);
                      });
                    }
                  }),
                  Text('–', style: GoogleFonts.nunito(color: KalendrTheme.muted(context), fontSize: 14)),
                  _timePill(shift.end, () async {
                    final t = await _pickTime(shift.end);
                    if (t != null) {
                      setState(() {
                        final updated = List<({TimeOfDay start, TimeOfDay end})>.from(shifts);
                        updated[i] = (start: shift.start, end: t);
                        _dayHours[weekday] = _correctShifts(updated);
                      });
                    }
                  }),
                  if (shifts.length > 1) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          final updated = List<({TimeOfDay start, TimeOfDay end})>.from(shifts);
                          updated.removeAt(i);
                          _dayHours[weekday] = updated;
                        });
                      },
                      child: Icon(Icons.remove_circle_outline_rounded, size: 18, color: Colors.red.shade300),
                    ),
                  ],
                ]),
              );
            }),
            if (shifts.length < 2) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    final afterEnd = _fromMinutes(_toMinutes(shifts.last.end) + 60);
                    final proposed = (start: afterEnd, end: _fromMinutes(_toMinutes(afterEnd) + 120));
                    _dayHours[weekday] = _correctShifts([...shifts, proposed]);
                  });
                },
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add_circle_outline_rounded, size: 14, color: _kWorkColor),
                  const SizedBox(width: 4),
                  Text(s.addSecondShift,
                      style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: _kWorkColor)),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  Widget _timePill(TimeOfDay t, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 90),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _kWorkColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kWorkColor.withOpacity(0.3)),
        ),
        child: Center(
          child: Text(context.read<AppProvider>().formatTime(t),
              style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: _kWorkColor)),
        ),
      ),
    );
  }

  Widget _rangeChip() {
    final startFmt = DateFormat('MMM d').format(_from);
    final endFmt = DateFormat('MMM d').format(_until);
    final days = _until.difference(_from).inDays + 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kWorkColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kWorkColor.withOpacity(0.2)),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.s.from, style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700,
              color: _kWorkColor.withOpacity(0.7), letterSpacing: 0.5)),
          Text(startFmt, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: _kWorkColor)),
        ])),
        Column(children: [
          Row(children: [
            Container(width: 16, height: 1.5, color: _kWorkColor.withOpacity(0.4)),
            const Icon(Icons.arrow_forward_rounded, size: 14, color: _kWorkColor),
          ]),
          const SizedBox(height: 2),
          Text(context.s.daysCount(days), style: GoogleFonts.nunito(fontSize: 10, color: _kWorkColor.withOpacity(0.6))),
        ]),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(context.s.until, style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700,
              color: _kWorkColor.withOpacity(0.7), letterSpacing: 0.5)),
          Text(endFmt, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: _kWorkColor)),
        ])),
      ]),
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
        Switch(value: value, onChanged: onChanged, activeColor: _kWorkColor),
      ]),
    );
  }

  Widget _dateRow(String label, DateTime dt, VoidCallback onTap, {bool isStart = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: KalendrTheme.field(context), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(isStart ? Icons.flight_takeoff_rounded : Icons.flight_land_rounded,
              size: 16, color: KalendrTheme.muted(context)),
          const SizedBox(width: 10),
          Text('$label  ', style: GoogleFonts.nunito(fontSize: 13, color: KalendrTheme.subtext(context))),
          Text(DateFormat('EEE, MMM d, y').format(dt),
              style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: KalendrTheme.text(context))),
          const Spacer(),
          Icon(Icons.edit_calendar_rounded, size: 16, color: KalendrTheme.muted(context)),
        ]),
      ),
    );
  }
}
