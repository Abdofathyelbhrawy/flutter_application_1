// utils/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  static const Color backgroundColor = Color(0xFF0A0E1A);
  static const Color cardColor = Color(0xFF141929);
  static const Color primaryColor = Color(0xFF4B6EF5);
  static const Color accentColor = Color(0xFF6C8EFF);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4B6EF5), Color(0xFF7C53FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: accentColor,
        surface: cardColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: cardColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        hintStyle: TextStyle(color: Colors.white.withAlpha(102)),
      ),
    );
  }
  /// يعرض وقت التأخير بصيغة ذكية:
  ///   < 60 دقيقة  →  "15 دقيقة"
  ///   >= 60 دقيقة →  "1 ساعة و30 دقيقة"  أو "ساعة" إذا الدقائق = 0
  static String formatLateTime(int minutes) {
    if (minutes < 60) return '$minutes دقيقة';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final hLabel = h == 1 ? 'ساعة' : '$h ساعات';
    if (m == 0) return hLabel;
    return '$hLabel و$m دقيقة';
  }
}

