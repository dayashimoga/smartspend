import 'package:flutter/material.dart';

class AppColors {
  // Brand accents
  static const Color primary = Color(0xFF6366F1); // Vibrant Indigo
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color accent = Color(0xFF06B6D4); // Cyan

  // Financial indicators
  static const Color income = Color(0xFF10B981); // Emerald
  static const Color expense = Color(0xFFF43F5E); // Rose
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color info = Color(0xFF38BDF8); // Sky blue
  static const Color success = income;
  static const Color danger = expense;

  // Dark Mode (Deep Midnight / AMOLED)
  static const Color darkBg = Color(0xFF0B0F19);
  static const Color darkSurface = Color(0xFF131B2E);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // Light Mode (Clean, High-Contrast Modern)
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.darkSurface,
        error: AppColors.expense,
        onPrimary: Colors.white,
        onSurface: AppColors.darkTextPrimary,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.darkTextMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
            color: AppColors.darkTextPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 32,
            letterSpacing: -1),
        headlineMedium: TextStyle(
            color: AppColors.darkTextPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 24,
            letterSpacing: -0.5),
        titleLarge: TextStyle(
            color: AppColors.darkTextPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 18),
        titleMedium: TextStyle(
            color: AppColors.darkTextPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 16),
        bodyLarge: TextStyle(color: AppColors.darkTextPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: AppColors.darkTextSecondary, fontSize: 14),
        bodySmall: TextStyle(color: AppColors.darkTextMuted, fontSize: 12),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        thickness: 1,
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryDark,
        secondary: AppColors.accent,
        surface: AppColors.lightSurface,
        error: AppColors.expense,
        onPrimary: Colors.white,
        onSurface: AppColors.lightTextPrimary,
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightBg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        selectedItemColor: AppColors.primaryDark,
        unselectedItemColor: AppColors.lightTextMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 4,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
            color: AppColors.lightTextPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 32,
            letterSpacing: -1),
        headlineMedium: TextStyle(
            color: AppColors.lightTextPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 24,
            letterSpacing: -0.5),
        titleLarge: TextStyle(
            color: AppColors.lightTextPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 18),
        titleMedium: TextStyle(
            color: AppColors.lightTextPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 16),
        bodyLarge: TextStyle(color: AppColors.lightTextPrimary, fontSize: 16),
        bodyMedium:
            TextStyle(color: AppColors.lightTextSecondary, fontSize: 14),
        bodySmall: TextStyle(color: AppColors.lightTextMuted, fontSize: 12),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightBorder,
        thickness: 1,
      ),
    );
  }
}
