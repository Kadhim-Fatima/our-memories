import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ألوان دفتر الذكريات: وردي غامق مثل الحبر، وذهبي للزخارف.
class AppColors {
  final Color bg, surface, ink, muted, line, accent, accentSoft, gold, danger;
  const AppColors({
    required this.bg,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.line,
    required this.accent,
    required this.accentSoft,
    required this.gold,
    required this.danger,
  });

  static const light = AppColors(
    bg: Color(0xFFF6EFF2),
    surface: Color(0xFFFFFAFC),
    ink: Color(0xFF2B1922),
    muted: Color(0xFF7B6470),
    line: Color(0xFFE6D6DD),
    accent: Color(0xFF9B2D55),
    accentSoft: Color(0xFFF3DDE6),
    gold: Color(0xFFA8812F),
    danger: Color(0xFFB3261E),
  );

  static const dark = AppColors(
    bg: Color(0xFF191115),
    surface: Color(0xFF231920),
    ink: Color(0xFFF4E6EC),
    muted: Color(0xFFB49CA8),
    line: Color(0xFF3A2A32),
    accent: Color(0xFFE57D9F),
    accentSoft: Color(0xFF3A2230),
    gold: Color(0xFFD8B166),
    danger: Color(0xFFFF8A80),
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

TextStyle displayFont({double size = 32, Color? color, FontWeight weight = FontWeight.w700}) =>
    GoogleFonts.arefRuqaa(fontSize: size, color: color, fontWeight: weight, height: 1.3);

ThemeData buildTheme(Brightness b) {
  final c = b == Brightness.dark ? AppColors.dark : AppColors.light;
  final base = ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: b,
      primary: c.accent,
      surface: c.surface,
      error: c.danger,
    ),
    scaffoldBackgroundColor: c.bg,
    dividerColor: c.line,
  );
  return base.copyWith(
    textTheme: GoogleFonts.tajawalTextTheme(base.textTheme).apply(
      bodyColor: c.ink,
      displayColor: c.ink,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.bg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.accent, width: 1.5),
      ),
      labelStyle: TextStyle(color: c.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: c.surface,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: GoogleFonts.tajawal(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.ink,
        side: BorderSide(color: c.line),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.ink,
      contentTextStyle: GoogleFonts.tajawal(color: c.bg, fontSize: 14),
      shape: const StadiumBorder(),
    ),
  );
}
