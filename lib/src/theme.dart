import 'package:flutter/material.dart';

class AppColors {
  /// Fundo azul-marinho bem escuro, como o da logo.
  static const bg = Color(0xFF060E18);
  static const sidebar = Color(0xFF040B13);
  static const card = Color(0xFF0F1B27);
  static const cardAlt = Color(0xFF15222F);
  static const line = Color(0xFF243543);
  static const text = Color(0xFFEFF4F8);
  static const muted = Color(0xFF95A5B6);

  /// Verde do meio da letra da logo: cor principal dos botões e destaques.
  static const green = Color(0xFF45CF6F);

  /// Verde-limão do topo da seta e do pingo do "i".
  static const lime = Color(0xFF97F151);

  /// Verde-água da base da letra.
  static const teal = Color(0xFF04AB9A);

  static const greenInk = Color(0xFF04230F);
  static const red = Color(0xFFFF6B7D);
  static const amber = Color(0xFFF0B429);
  static const blue = Color(0xFF7EB6FF);

  /// Degradê da marca, do verde-água ao verde-limão.
  static const brandGradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [teal, green, lime],
  );
}

ThemeData buildTheme() {
  final scheme = const ColorScheme.dark(
    surface: AppColors.bg,
    primary: AppColors.green,
    onPrimary: AppColors.greenInk,
    secondary: AppColors.teal,
    error: AppColors.red,
    onSurface: AppColors.text,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.sidebar,
      foregroundColor: AppColors.text,
      elevation: 0,
      centerTitle: false,
    ),
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
    chipTheme: const ChipThemeData(
      backgroundColor: AppColors.cardAlt,
      selectedColor: AppColors.green,
      checkmarkColor: AppColors.greenInk,
      side: BorderSide(color: AppColors.line),
      labelStyle: TextStyle(color: AppColors.text),
      secondaryLabelStyle: TextStyle(color: AppColors.greenInk, fontWeight: FontWeight.w700),
    ),
    scrollbarTheme: const ScrollbarThemeData(
      thumbVisibility: WidgetStatePropertyAll(true),
    ),
  );
}
