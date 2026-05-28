import 'package:flutter/material.dart';

class BrandColors {
  // Brand Electric Blue (#0E5BFF)
  static const Color primary = Color(0xFF0E5BFF);
  // Secondary Royal Blue (#0944C6)
  static const Color accentOrange = Color(0xFF0944C6);
  // Success Emerald Green (#10B981)
  static const Color accentGreen = Color(0xFF10B981);
  
  static const Color creamBg = Color(0xFFFAF7F2);
  static const Color creamCard = Color(0xFFFFFFFF);
  static const Color creamBorder = Color(0xFFE2DCD0);
  
  static const Color textMain = Color(0xFF0E1726);
  static const Color textMuted = Color(0xFF64748B);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: BrandColors.primary,
      primary: BrandColors.primary,
      secondary: BrandColors.accentOrange,
      brightness: Brightness.light,
    ),
    fontFamily: 'Inter',
  );
  return base.copyWith(
    scaffoldBackgroundColor: BrandColors.creamBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: BrandColors.creamCard,
      foregroundColor: BrandColors.primary,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: BrandColors.creamCard,
      iconTheme: IconThemeData(color: BrandColors.primary),
      titleTextStyle: TextStyle(
        color: BrandColors.primary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: BrandColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: BrandColors.creamBorder,
        disabledForegroundColor: BrandColors.textMuted,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        elevation: 0,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BrandColors.creamBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BrandColors.creamBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BrandColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      hintStyle: const TextStyle(color: BrandColors.textMuted),
    ),
  );
}
