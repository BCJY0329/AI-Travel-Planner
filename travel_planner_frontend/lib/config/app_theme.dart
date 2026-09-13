import 'package:flutter/material.dart';

class AppTheme {
  // Brand Lavender & Periwinkle Palette
  static const Color primary = Color(0xFF6E7BF5);       // Periwinkle primary
  static const Color primaryDark = Color(0xFF5864E0);   // Darker periwinkle for hover/emphasis
  static const Color primaryLight = Color(0xFF909CFC);  // Soft periwinkle light
  static const Color lavenderTint = Color(0xFFEDE9FE);  // Soft lavender container/badge
  static const Color lavenderSubtle = Color(0xFFF4F2FF);// Very subtle lavender highlight
  static const Color background = Color(0xFFF8F7FD);    // Soft off-white lavender page background
  static const Color surface = Color(0xFFFFFFFF);       // Clean pure white card surface
  static const Color border = Color(0xFFE5E2F8);        // Gentle periwinkle border
  static const Color borderLight = Color(0xFFF0EDFC);

  // Text colors
  static const Color textPrimary = Color(0xFF1E1B4B);   // Deep indigo-slate
  static const Color textSecondary = Color(0xFF64748B); // Slate muted
  static const Color textMuted = Color(0xFF94A3B8);     // Light muted slate

  // Accent colors
  static const Color accentLemon = Color(0xFFFBBF24);   // Lemon gold accent for Lemon.ai
  static const Color accentLemonDark = Color(0xFFD97706);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: lavenderTint,
        onPrimaryContainer: textPrimary,
        secondary: primaryLight,
        onSecondary: Colors.white,
        secondaryContainer: lavenderSubtle,
        onSecondaryContainer: textPrimary,
        surface: surface,
        onSurface: textPrimary,
        surfaceContainerLowest: surface,
        surfaceContainerLow: background,
        surfaceContainer: Color(0xFFF2F0FC),
        error: error,
        onError: Colors.white,
        outline: border,
        outlineVariant: borderLight,
      ),
      fontFamily: 'Segoe UI',
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.8),
        ),
      ),
    );
  }
}
