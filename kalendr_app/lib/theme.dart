import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void showSnack(BuildContext context, String message, {Color? color, Duration duration = const Duration(seconds: 2)}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message, style: GoogleFonts.nunito()),
    backgroundColor: color ?? kPrimary,
    behavior: SnackBarBehavior.floating,
    duration: duration,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ));
}

const kPrimary = Color(0xFFFF6B6B);

const kGroupColors = [
  Color(0xFFFF6B6B), Color(0xFF4ECDC4), Color(0xFFFFBE0B),
  Color(0xFF8338EC), Color(0xFF06D6A0), Color(0xFFFF6B9D),
];

Color groupColorFor(String id) => kGroupColors[id.hashCode.abs() % kGroupColors.length];

Color hexToColor(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

class KalendrTheme {
  static ThemeData light() => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimary, brightness: Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFF7F3F0),
        textTheme: GoogleFonts.nunitoTextTheme(),
        useMaterial3: true,
        cardColor: Colors.white,
        dividerColor: const Color(0xFFF0EDEB),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: kPrimary.withOpacity(0.12),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
      );

  static ThemeData dark() => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimary, brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF121212),
        textTheme: GoogleFonts.nunitoTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
        cardColor: const Color(0xFF1E1E1E),
        dividerColor: const Color(0xFF2A2A2A),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF1E1E1E),
          indicatorColor: kPrimary.withOpacity(0.18),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
      );

  // Semantic color helpers
  static Color surface(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white;

  static Color bg(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFF121212) : const Color(0xFFF7F3F0);

  static Color text(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFFF0F0F0) : const Color(0xFF1A1A1A);

  static Color subtext(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFF9E9E9E) : const Color(0xFF9E9E9E);

  static Color muted(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFF555555) : const Color(0xFFBDBDBD);

  static Color divider(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFF2A2A2A) : const Color(0xFFF0EDEB);

  static Color field(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFF2A2A2A) : const Color(0xFFF7F3F0);
}
