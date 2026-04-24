import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() {
    const bg = Color(0xFFF6F7FB);
    const card = Colors.white;
    const text = Color(0xFF111827);
    const subtext = Color(0xFF6B7280);
    const accent = Color(0xFF111827);

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(seedColor: accent).copyWith(
        surface: card,
        onSurface: text,
        primary: accent,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: text),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: text),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: text),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: subtext),
      ),
      cardTheme: const CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }
}