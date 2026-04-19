import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../theme.dart';
import '../l10n/app_strings.dart';

/// A bottom-sheet calendar picker.
///
/// - [rangeStart] + [highlightDate]: both set to the event start date when
///   picking an end/repeat-until date, so the ribbon and filled start circle
///   render automatically.
/// - [accentColor]: drives every tint (ribbon, circles, buttons).
class CalendarPickerSheet extends StatefulWidget {
  final String title;
  final DateTime initial;
  final DateTime first;
  final DateTime last;
  final DateTime? highlightDate;  // reference date to mark (e.g. start date)
  final String? highlightLabel;   // label shown in the legend chip
  final DateTime? rangeStart;     // shades the range between rangeStart and selected
  final Color accentColor;
  final bool startOnMonday;

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
    this.startOnMonday = true,
  });

  @override
  State<CalendarPickerSheet> createState() => _CalendarPickerSheetState();
}

class _CalendarPickerSheetState extends State<CalendarPickerSheet> {
  late DateTime _selected;
  late DateTime _focused;

  Color get _highlightColor => widget.accentColor;
  Color get _rangeBg => widget.accentColor.withOpacity(0.13);
  static const double _barH = 36.0;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
    _focused = widget.initial;
  }

  // ─── Cell helpers ──────────────────────────────────────────────────────────

  /// Half-width ribbon bar used to connect start/end circles to the range.
  Widget _bar({bool leftHalf = false, bool rightHalf = false}) {
    return Align(
      alignment: Alignment.center,
      child: SizedBox(
        height: _barH,
        child: Row(children: [
          if (leftHalf)  Expanded(child: Container(color: _rangeBg)) else const Expanded(child: SizedBox()),
          if (rightHalf) Expanded(child: Container(color: _rangeBg)) else const Expanded(child: SizedBox()),
        ]),
      ),
    );
  }

  /// A day inside the range — full-width ribbon with the day number.
  Widget _rangeCell(DateTime day, BuildContext ctx, {bool muted = false}) {
    return Stack(children: [
      Align(alignment: Alignment.center, child: Container(height: _barH, color: _rangeBg)),
      Center(child: Text('${day.day}', style: GoogleFonts.nunito(fontSize: 13,
          color: muted ? KalendrTheme.muted(ctx) : KalendrTheme.text(ctx)))),
    ]);
  }

  /// The highlighted reference day (e.g. start date).
  ///
  /// When [inRange] is true (the day IS the rangeStart and selected > it),
  /// renders a filled circle + right-half ribbon so it connects seamlessly.
  /// When [inRange] is false, renders a standalone outline circle.
  Widget _highlightCell(DateTime day, {bool inRange = false}) {
    if (inRange) {
      return Stack(children: [
        _bar(rightHalf: true),
        Center(child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(shape: BoxShape.circle, color: _highlightColor),
          child: Center(child: Text('${day.day}',
              style: GoogleFonts.nunito(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w800))),
        )),
      ]);
    }
    return Center(child: Container(
      width: 34, height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _highlightColor, width: 2),
        color: _highlightColor.withOpacity(0.08),
      ),
      child: Center(child: Text('${day.day}',
          style: GoogleFonts.nunito(fontSize: 13, color: _highlightColor, fontWeight: FontWeight.w700))),
    ));
  }

  /// The selected (end) day — filled circle, with optional left-half ribbon
  /// connecting back to the range.
  Widget _selectedCell(DateTime day, {bool isHighlight = false, bool isRangeEnd = false}) {
    final circle = Container(
      width: 34, height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.accentColor,
        border: isHighlight ? Border.all(color: _highlightColor, width: 2.5) : null,
      ),
      child: Center(child: Text('${day.day}',
          style: GoogleFonts.nunito(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w800))),
    );
    if (!isRangeEnd) return Center(child: circle);
    return Stack(children: [_bar(leftHalf: true), Center(child: circle)]);
  }

  /// Today's cell when it is not selected or highlighted.
  Widget _todayCell(DateTime day) {
    return Center(child: Container(
      width: 34, height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: widget.accentColor, width: 1.5),
      ),
      child: Center(child: Text('${day.day}',
          style: GoogleFonts.nunito(fontSize: 13, color: widget.accentColor, fontWeight: FontWeight.w700))),
    ));
  }

  // ─── Builder helpers ───────────────────────────────────────────────────────

  // Strip time so comparisons work purely on calendar days.
  DateTime get _rangeStartDay => widget.rangeStart == null ? DateTime(0) :
      DateTime(widget.rangeStart!.year, widget.rangeStart!.month, widget.rangeStart!.day);
  DateTime get _selectedDay =>
      DateTime(_selected.year, _selected.month, _selected.day);

  bool _inRange(DateTime day) =>
      widget.rangeStart != null &&
      day.isAfter(_rangeStartDay) &&
      day.isBefore(_selectedDay);

  bool _isRangeStart(DateTime day) =>
      widget.rangeStart != null && isSameDay(day, _rangeStartDay);

  Widget? _buildDay(DateTime day, BuildContext ctx, {bool muted = false}) {
    final inRange   = _inRange(day);
    final isStart   = _isRangeStart(day);
    final isHighlight = widget.highlightDate != null && isSameDay(day, widget.highlightDate!);
    final isSelected  = isSameDay(day, _selected);

    final hasRange = widget.rangeStart != null && _selectedDay.isAfter(_rangeStartDay);
    if (isSelected) return _selectedCell(day, isHighlight: isHighlight, isRangeEnd: hasRange);
    if (isHighlight) return _highlightCell(day, inRange: isStart && hasRange);
    if (inRange) return _rangeCell(day, ctx, muted: muted);
    return null;
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final today   = DateTime.now();
    final screenH = MediaQuery.of(context).size.height;

    return SizedBox(
      height: screenH * 0.72,
      child: Container(
        decoration: BoxDecoration(
          color: KalendrTheme.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        child: Column(children: [
          // Handle
          Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: KalendrTheme.divider(context), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),

          // Title row
          Row(children: [
            Text(widget.title, style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: KalendrTheme.text(context))),
            const Spacer(),
            GestureDetector(
              onTap: () {
                final target = today.isBefore(widget.first)
                    ? widget.first
                    : today.isAfter(widget.last) ? widget.last : today;
                setState(() { _selected = target; _focused = target; });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: widget.accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(context.s.today, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: widget.accentColor)),
              ),
            ),
            const SizedBox(width: 10),
            Container(width: 10, height: 10,
                decoration: BoxDecoration(color: widget.accentColor, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(context.s.selected, style: GoogleFonts.nunito(fontSize: 12, color: widget.accentColor, fontWeight: FontWeight.w600)),
          ]),

          // Start date legend chip
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
            startingDayOfWeek: widget.startOnMonday ? StartingDayOfWeek.monday : StartingDayOfWeek.sunday,
            sixWeekMonthsEnforced: true,
            pageAnimationDuration: const Duration(milliseconds: 180),
            pageAnimationCurve: Curves.easeOut,
            selectedDayPredicate: (d) => isSameDay(d, _selected),
            onDaySelected: (selected, focused) => setState(() { _selected = selected; _focused = focused; }),
            onPageChanged: (focused) => setState(() => _focused = focused),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (ctx, day, _) => _buildDay(day, ctx),
              selectedBuilder: (ctx, day, _) => _buildDay(day, ctx),
              todayBuilder: (ctx, day, _) {
                final cell = _buildDay(day, ctx);
                return cell ?? _todayCell(day);
              },
              outsideBuilder: (ctx, day, _) => _buildDay(day, ctx, muted: true),
            ),
            calendarStyle: CalendarStyle(
              defaultTextStyle: GoogleFonts.nunito(color: KalendrTheme.text(context)),
              weekendTextStyle: GoogleFonts.nunito(color: KalendrTheme.subtext(context)),
              outsideTextStyle: GoogleFonts.nunito(color: KalendrTheme.muted(context)),
              disabledTextStyle: GoogleFonts.nunito(color: KalendrTheme.divider(context)),
              selectedDecoration: BoxDecoration(color: widget.accentColor, shape: BoxShape.circle),
              selectedTextStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: Colors.white),
              todayDecoration: BoxDecoration(border: Border.all(color: widget.accentColor), shape: BoxShape.circle),
              todayTextStyle: GoogleFonts.nunito(color: widget.accentColor, fontWeight: FontWeight.w700),
              cellMargin: EdgeInsets.zero,
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: KalendrTheme.text(context)),
              leftChevronIcon: Icon(Icons.chevron_left_rounded, color: widget.accentColor),
              rightChevronIcon: Icon(Icons.chevron_right_rounded, color: widget.accentColor),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: KalendrTheme.subtext(context)),
              weekendStyle: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: KalendrTheme.muted(context)),
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
              child: Text(context.s.confirmDate(DateFormat('MMM d').format(_selected)),
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }
}
