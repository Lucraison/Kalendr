import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../l10n/app_strings.dart';

class TypePickerSheet extends StatelessWidget {
  final VoidCallback onEvent;
  final VoidCallback onWorkSchedule;

  const TypePickerSheet({super.key, required this.onEvent, required this.onWorkSchedule});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KalendrTheme.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Text(context.s.whatAreYouAdding, style: GoogleFonts.nunito(
            fontSize: 18, fontWeight: FontWeight.w800, color: KalendrTheme.text(context))),
        const SizedBox(height: 16),
        _typeCard(context,
          icon: Icons.event_rounded, color: const Color(0xFFFF6B6B),
          title: context.s.event,
          subtitle: context.s.eventTypeDesc,
          onTap: onEvent,
        ),
        const SizedBox(height: 10),
        _typeCard(context,
          icon: Icons.work_outline_rounded, color: const Color(0xFF3B82F6),
          title: context.s.workSchedule,
          subtitle: context.s.workScheduleDesc,
          onTap: onWorkSchedule,
        ),
      ]),
    );
  }

  Widget _typeCard(BuildContext context, {
    required IconData icon, required Color color,
    required String title, required String subtitle, required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: KalendrTheme.text(context))),
            const SizedBox(height: 3),
            Text(subtitle, style: GoogleFonts.nunito(fontSize: 12, color: KalendrTheme.muted(context), height: 1.4)),
          ])),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color.withOpacity(0.5)),
        ]),
      ),
    );
  }
}
