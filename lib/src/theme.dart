import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF0E141B);
  static const sidebar = Color(0xFF0B1016);
  static const card = Color(0xFF171F2B);
  static const cardAlt = Color(0xFF1C2633);
  static const line = Color(0xFF2C3A4C);
  static const text = Color(0xFFE7EDF5);
  static const muted = Color(0xFF93A0B4);
  static const green = Color(0xFF3DDC97);
  static const greenInk = Color(0xFF06281C);
  static const red = Color(0xFFFF6B7D);
  static const amber = Color(0xFFF0B429);
  static const blue = Color(0xFF7EB6FF);
}

ThemeData buildTheme() {
  final scheme = const ColorScheme.dark(
    surface: AppColors.bg,
    primary: AppColors.green,
    onPrimary: AppColors.greenInk,
    secondary: AppColors.blue,
    error: AppColors.red,
    onSurface: AppColors.text,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    dividerColor: AppColors.line,
    cardTheme: const CardThemeData(
      color: AppColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.cardAlt,
      labelStyle: const TextStyle(color: AppColors.muted),
      hintStyle: const TextStyle(color: AppColors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.green),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.green,
        foregroundColor: AppColors.greenInk,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.line),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.green),
    ),
    scrollbarTheme: const ScrollbarThemeData(
      thumbVisibility: WidgetStatePropertyAll(true),
    ),
  );
}
