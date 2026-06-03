import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Light Theme Colors
  static const Color lightBg = Colors.white;
  static const Color lightAccent = Color(0xFFF2F2F7);
  static const Color lightBorder = Color(0xFFE5E5EA);
  static const Color lightPrimary = Color(0xFF000000);
  static const Color lightSecondary = Color(0xFF8E8E93);
  static const Color lightCardBg = Color(0xFFFAFAFA);
  static const Color lightTextPrimary = Color(0xFF1C1C1E);
  static const Color lightTextSecondary = Color(0xFF3A3A3C);

  // Dark Theme Colors
  static const Color darkBg = Color(0xFF000000);
  static const Color darkAccent = Color(0xFF1C1C1E);
  static const Color darkBorder = Color(0xFF2C2C2E);
  static const Color darkPrimary = Colors.white;
  static const Color darkSecondary = Color(0xFF8E8E93);
  static const Color darkCardBg = Color(0xFF121212);
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Color(0xFFE5E5EA);

  // Status colors (Subtle, premium)
  static const Color colorLow = Color(0xFF34C759); // Soft Green
  static const Color colorMedium = Color(0xFFFF9500); // Soft Orange
  static const Color colorHigh = Color(0xFFFF3B30); // Soft Red

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      primaryColor: lightPrimary,
      cardColor: lightCardBg,
      dividerColor: lightBorder,
      colorScheme: const ColorScheme.light(
        primary: lightPrimary,
        secondary: lightSecondary,
        background: lightBg,
        surface: lightCardBg,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onBackground: lightTextPrimary,
        onSurface: lightTextPrimary,
        outline: lightBorder,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).copyWith(
        displayLarge: const TextStyle(color: lightTextPrimary, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        headlineMedium: const TextStyle(color: lightTextPrimary, fontWeight: FontWeight.w600, letterSpacing: -0.3),
        titleLarge: const TextStyle(color: lightTextPrimary, fontWeight: FontWeight.w600, fontSize: 20, letterSpacing: -0.2),
        titleMedium: const TextStyle(color: lightTextPrimary, fontWeight: FontWeight.w500, fontSize: 16),
        bodyLarge: const TextStyle(color: lightTextPrimary, fontSize: 16, height: 1.4),
        bodyMedium: const TextStyle(color: lightTextSecondary, fontSize: 14, height: 1.4),
        labelLarge: const TextStyle(color: lightSecondary, fontSize: 12, fontWeight: FontWeight.w500),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBg,
        foregroundColor: lightTextPrimary,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightBg,
        selectedItemColor: lightPrimary,
        unselectedItemColor: lightSecondary,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: CardThemeData(
        color: lightCardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightAccent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightPrimary, width: 1),
        ),
        hintStyle: const TextStyle(color: lightSecondary),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      primaryColor: darkPrimary,
      cardColor: darkCardBg,
      dividerColor: darkBorder,
      colorScheme: const ColorScheme.dark(
        primary: darkPrimary,
        secondary: darkSecondary,
        background: darkBg,
        surface: darkCardBg,
        onPrimary: Colors.black,
        onSecondary: Colors.white,
        onBackground: darkTextPrimary,
        onSurface: darkTextPrimary,
        outline: darkBorder,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: const TextStyle(color: darkTextPrimary, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        headlineMedium: const TextStyle(color: darkTextPrimary, fontWeight: FontWeight.w600, letterSpacing: -0.3),
        titleLarge: const TextStyle(color: darkTextPrimary, fontWeight: FontWeight.w600, fontSize: 20, letterSpacing: -0.2),
        titleMedium: const TextStyle(color: darkTextPrimary, fontWeight: FontWeight.w500, fontSize: 16),
        bodyLarge: const TextStyle(color: darkTextPrimary, fontSize: 16, height: 1.4),
        bodyMedium: const TextStyle(color: darkTextSecondary, fontSize: 14, height: 1.4),
        labelLarge: const TextStyle(color: darkSecondary, fontSize: 12, fontWeight: FontWeight.w500),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkBg,
        selectedItemColor: darkPrimary,
        unselectedItemColor: darkSecondary,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: CardThemeData(
        color: darkCardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkAccent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkPrimary, width: 1),
        ),
        hintStyle: const TextStyle(color: darkSecondary),
      ),
    );
  }
}
