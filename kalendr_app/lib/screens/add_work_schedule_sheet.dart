import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
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
  TimeOfDay _globalStart = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _globalEnd = const TimeOfDay(hour: 17, minute: 0);
  final Map<int, ({TimeOfDay start, TimeOfDay end})> _dayHours = {};
  late DateTime _from;
  late DateTime _until;
  int? _presetDays = 30; // null = custom
  bool _busy = false;
  String _error = '';
  int _created = 0;
  List<String> _sharedGroupIds = [];

  static const _presets = [
    (label: '1W', days: 7),
    (label: '2W', days: 14),
    (label: '1M', days: 30),
    (label: '3M', days: 90),
  ];

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: 'Work');
    final base = widget.initialDate ?? DateTime.now();
    _from = DateTime(base.year, base.month, base.day);
    _until = _from.add(const Duration(days: 30));
    for (final d in _selectedDays) {
      _dayHours[d] = (start: _globalStart, end: _globalEnd);
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
        _dayHours[weekday] = (start: _globalStart, end: _globalEnd);
      }
    });
  }

  void _applyGlobalHours() {
    for (final d in _selectedDays) {
      _dayHours[d] = (start: _globalStart, end: _globalEnd);
    }
  }

  List<(DateTime, DateTime)> _generateOccurrences() {
    final result = <(DateTime, DateTime)>[];
    var current = _from;
    while (!current.isAfter(_until)) {
      final wd = current.weekday;
      if (_selectedDays.contains(wd)) {
        final hours = _dayHours[wd] ?? (start: _globalStart, end: _globalEnd);
        final s = DateTime(current.year, current.month, current.day, hours.start.hour, hours.start.minute);
        final e = DateTime(current.year, current.month, current.day, hours.end.hour, hours.end.minute);
        result.add((s, e));
      }
      current = current.add(const Duration(days: 1));
    }
    return result;
  }

  Future<void> _pickFrom() async {
    final date = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CalendarPickerSheet(
        title: 'Starting from',
        initial: _from,
        first: DateTime.now().subtract(const Duration(days: 365)),
        last: DateTime.now().add(const Duration(days: 365 * 5)),
        accentColor: _kWorkColor,
      ),
    );
    if (date != null && mounted) {
      setState(() {
        _from = date;
        // recalculate end based on active preset
        if (_presetDays != null) {
          _until = _from.add(Duration(days: _presetDays!));
        } else if (_until.isBefore(_from)) {
          _until = _from.add(const Duration(days: 30));
        }
      });
    }
  }

  Future<void> _pickCustomUntil() async {
    final date = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CalendarPickerSheet(
        title: 'Repeat until',
        initial: _until,
        first: _from,
        last: DateTime.now().add(const Duration(days: 365 * 2)),
        highlightDate: _from,
        highlightLabel: 'Start',
        rangeStart: _from,
        accentColor: _kWorkColor,
      ),
    );
    if (date != null && mounted) setState(() { _until = date; _presetDays = null; });
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay initial) =>
      showKalendrTimePicker(context, initial, accentColor: _kWorkColor);

  Future<void> _submit() async {
    if (_busy) return;
    if (_name.text.trim().isEmpty) { setState(() => _error = 'Name is required'); return; }
    if (_selectedDays.isEmpty) { setState(() => _error = 'Select at least one day'); return; }
    final occurrences = _generateOccurrences();
    if (occurrences.isEmpty) { setState(() => _error = 'No shifts in selected date range'); return; }
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
            Text('Work Schedule', style: GoogleFonts.nunito(
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
                hintText: 'Schedule name (e.g. Work)',
                hintStyle: GoogleFonts.nunito(color: KalendrTheme.muted(context)),
                prefixIcon: Icon(Icons.badge_outlined, color: KalendrTheme.muted(context), size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Work days
          Text('Work days', style: GoogleFonts.nunito(
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
                  child: Center(child: Text(_dayLabels[wd - 1],
                      style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700,
                          color: active ? Colors.white : KalendrTheme.muted(context)))),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Hours
          _toggleRow(Icons.tune_rounded, 'Same hours every day', _sameHours, (v) {
            setState(() { _sameHours = v; if (v) _applyGlobalHours(); });
          }),
          if (_selectedDays.isNotEmpty) ...[
            const SizedBox(height: 10),
            if (_sameHours) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: KalendrTheme.field(context), borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Icon(Icons.schedule_rounded, size: 16, color: KalendrTheme.muted(context)),
                  const SizedBox(width: 10),
                  Text('Hours', style: GoogleFonts.nunito(
                      fontSize: 13, fontWeight: FontWeight.w600, color: KalendrTheme.subtext(context))),
                  const Spacer(),
                  _timePill(_globalStart, () async {
                    final t = await _pickTime(_globalStart);
                    if (t != null) setState(() { _globalStart = t; _applyGlobalHours(); });
                  }),
                  Text('–', style: GoogleFonts.nunito(color: KalendrTheme.muted(context), fontSize: 14)),
                  _timePill(_globalEnd, () async {
                    final t = await _pickTime(_globalEnd);
                    if (t != null) setState(() { _globalEnd = t; _applyGlobalHours(); });
                  }),
                ]),
              ),
            ] else ...[
              ...[1, 2, 3, 4, 5, 6, 7]
                  .where((wd) => _selectedDays.contains(wd))
                  .map((wd) => _dayHoursRow(wd)),
            ],
          ],
          const SizedBox(height: 14),

          // Date range
          Text('Date range', style: GoogleFonts.nunito(
              fontSize: 13, fontWeight: FontWeight.w700, color: KalendrTheme.subtext(context))),
          const SizedBox(height: 8),
          _dateRow('From', _from, _pickFrom),
          const SizedBox(height: 12),
          Text('Duration', style: GoogleFonts.nunito(
              fontSize: 13, fontWeight: FontWeight.w700, color: KalendrTheme.subtext(context))),
          const SizedBox(height: 8),
          Row(children: [
            ..._presets.map((p) {
              final active = _presetDays == p.days;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _presetDays = p.days;
                    _until = _from.add(Duration(days: p.days));
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
                    child: Text(p.label, style: GoogleFonts.nunito(
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
                  color: _presetDays == null ? _kWorkColor : KalendrTheme.field(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _presetDays == null ? _kWorkColor : KalendrTheme.divider(context),
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    _presetDays == null
                        ? DateFormat('MMM d').format(_until)
                        : 'Custom',
                    style: GoogleFonts.nunito(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: _presetDays == null ? Colors.white : KalendrTheme.subtext(context),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.edit_calendar_rounded, size: 12,
                      color: _presetDays == null ? Colors.white70 : KalendrTheme.muted(context)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          _rangeChip(),
          if (_shiftCount > 0) ...[
            const SizedBox(height: 6),
            Text('$_shiftCount shift${_shiftCount == 1 ? '' : 's'}',
                style: GoogleFonts.nunito(fontSize: 12, color: _kWorkColor, fontWeight: FontWeight.w600)),
          ],

          if (widget.availableGroups.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Visible to', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: KalendrTheme.subtext(context))),
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
                      _shiftCount > 0
                          ? 'Add $_shiftCount Shift${_shiftCount == 1 ? '' : 's'}'
                          : 'Add Work Schedule',
                      style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _dayHoursRow(int weekday) {
    final schedule = _dayHours[weekday]!;
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
            final t = await _pickTime(schedule.start);
            if (t != null) setState(() => _dayHours[weekday] = (start: t, end: schedule.end));
          }),
          Text('–', style: GoogleFonts.nunito(color: KalendrTheme.muted(context), fontSize: 14)),
          _timePill(schedule.end, () async {
            final t = await _pickTime(schedule.end);
            if (t != null) setState(() => _dayHours[weekday] = (start: schedule.start, end: t));
          }),
        ]),
      ),
    );
  }

  Widget _timePill(TimeOfDay t, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: _kWorkColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kWorkColor.withOpacity(0.3)),
        ),
        child: Text(t.format(context),
            style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: _kWorkColor)),
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
          Text('From', style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700,
              color: _kWorkColor.withOpacity(0.7), letterSpacing: 0.5)),
          Text(startFmt, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: _kWorkColor)),
        ])),
        Column(children: [
          Row(children: [
            Container(width: 16, height: 1.5, color: _kWorkColor.withOpacity(0.4)),
            const Icon(Icons.arrow_forward_rounded, size: 14, color: _kWorkColor),
          ]),
          const SizedBox(height: 2),
          Text('$days days', style: GoogleFonts.nunito(fontSize: 10, color: _kWorkColor.withOpacity(0.6))),
        ]),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('Until', style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700,
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

  Widget _dateRow(String label, DateTime dt, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: KalendrTheme.field(context), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(label == 'From' ? Icons.flight_takeoff_rounded : Icons.flight_land_rounded,
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
