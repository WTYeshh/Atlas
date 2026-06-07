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

  static ThemeData getThemeFor(String themeKey, {required bool isDark}) {
    // Determine the colors for the requested theme
    Color scaffoldBg;
    Color primaryColor;
    Color accentColor;
    Color borderColor;
    Color cardBg;
    Color textPrimary;
    Color textSecondary;
    Brightness brightness = isDark ? Brightness.dark : Brightness.light;

    switch (themeKey) {
      case 'forest_green':
        scaffoldBg = const Color(0xFF0C140F);
        primaryColor = const Color(0xFF34C759); // Forest Green Accent
        accentColor = const Color(0xFF16251C);
        borderColor = const Color(0xFF1B3224);
        cardBg = const Color(0xFF111D15);
        textPrimary = const Color(0xFFE5F9EA);
        textSecondary = const Color(0xFF8EAF96);
        brightness = Brightness.dark;
        break;
      case 'warm_sepia':
        scaffoldBg = const Color(0xFFFBF0D9); // Cozy Cream
        primaryColor = const Color(0xFF8C6239); // Sepia Brown Accent
        accentColor = const Color(0xFFF3E5C8);
        borderColor = const Color(0xFFE5D5B3);
        cardBg = const Color(0xFFFDF7EB);
        textPrimary = const Color(0xFF433422);
        textSecondary = const Color(0xFF7A6855);
        brightness = Brightness.light;
        break;
      case 'neon_cyberpunk':
        scaffoldBg = const Color(0xFF0A0118); // Dark Space
        primaryColor = const Color(0xFFBD00FF); // Neon Magenta
        accentColor = const Color(0xFF1D0E36);
        borderColor = const Color(0xFF3D1F6E);
        cardBg = const Color(0xFF130626);
        textPrimary = const Color(0xFFF3E8FF);
        textSecondary = const Color(0xFFB59BD6);
        brightness = Brightness.dark;
        break;
      case 'amoled_gold':
        scaffoldBg = const Color(0xFF000000); // Pitch black
        primaryColor = const Color(0xFFFFD700); // Gold
        accentColor = const Color(0xFF121212);
        borderColor = const Color(0xFF2C2C2E);
        cardBg = const Color(0xFF0D0D0D);
        textPrimary = const Color(0xFFFFFFFF);
        textSecondary = const Color(0xFFE5E5EA);
        brightness = Brightness.dark;
        break;
      // --- NEW THEMES ---
      case 'ocean_blue':
        scaffoldBg = const Color(0xFF040E1A); // Deep ocean midnight
        primaryColor = const Color(0xFF0A84FF); // iOS blue
        accentColor = const Color(0xFF0B1C2E);
        borderColor = const Color(0xFF112840);
        cardBg = const Color(0xFF071526);
        textPrimary = const Color(0xFFE5F0FF);
        textSecondary = const Color(0xFF6B9FCC);
        brightness = Brightness.dark;
        break;
      case 'cherry_blossom':
        scaffoldBg = const Color(0xFFFFF5F7); // Petal white
        primaryColor = const Color(0xFFE84393); // Vivid cherry pink
        accentColor = const Color(0xFFFFE8EF);
        borderColor = const Color(0xFFF5C6D6);
        cardBg = const Color(0xFFFFFAFB);
        textPrimary = const Color(0xFF3D0B1A);
        textSecondary = const Color(0xFF9E5070);
        brightness = Brightness.light;
        break;
      case 'lava_red':
        scaffoldBg = const Color(0xFF0F0500); // Volcanic dark
        primaryColor = const Color(0xFFFF4500); // Lava orange-red
        accentColor = const Color(0xFF1E0A00);
        borderColor = const Color(0xFF3D1200);
        cardBg = const Color(0xFF140700);
        textPrimary = const Color(0xFFFFE8DC);
        textSecondary = const Color(0xFFCC7755);
        brightness = Brightness.dark;
        break;
      case 'arctic_ice':
        scaffoldBg = const Color(0xFFF0F8FF); // Alice blue
        primaryColor = const Color(0xFF007AFF); // Arctic blue
        accentColor = const Color(0xFFDDEEFF);
        borderColor = const Color(0xFFBAD6F0);
        cardBg = const Color(0xFFF8FCFF);
        textPrimary = const Color(0xFF0A1929);
        textSecondary = const Color(0xFF4D7A9E);
        brightness = Brightness.light;
        break;
      case 'sage_minimal':
        scaffoldBg = const Color(0xFFF4F7F2); // Soft sage white
        primaryColor = const Color(0xFF5B7F5C); // Sage green
        accentColor = const Color(0xFFE5EDE4);
        borderColor = const Color(0xFFCCDDCA);
        cardBg = const Color(0xFFF9FBF8);
        textPrimary = const Color(0xFF1C2B1D);
        textSecondary = const Color(0xFF607860);
        brightness = Brightness.light;
        break;
      case 'midnight_indigo':
        scaffoldBg = const Color(0xFF060612); // Deep midnight
        primaryColor = const Color(0xFF5E5CE6); // Indigo-violet
        accentColor = const Color(0xFF0E0E26);
        borderColor = const Color(0xFF1E1E46);
        cardBg = const Color(0xFF0A0A1E);
        textPrimary = const Color(0xFFE8E8FF);
        textSecondary = const Color(0xFF8888C4);
        brightness = Brightness.dark;
        break;
      case 'steel_noir':
        scaffoldBg = const Color(0xFF111316); // Gunmetal dark
        primaryColor = const Color(0xFF98A0B4); // Steel grey accent
        accentColor = const Color(0xFF1A1D22);
        borderColor = const Color(0xFF2A2D35);
        cardBg = const Color(0xFF161920);
        textPrimary = const Color(0xFFDDE2ED);
        textSecondary = const Color(0xFF787E90);
        brightness = Brightness.dark;
        break;
      case 'galaxy_purple':
        scaffoldBg = const Color(0xFF050010); // Cosmic void
        primaryColor = const Color(0xFFAF52DE); // Galaxy purple
        accentColor = const Color(0xFF130030);
        borderColor = const Color(0xFF2D0060);
        cardBg = const Color(0xFF0A0020);
        textPrimary = const Color(0xFFF0E6FF);
        textSecondary = const Color(0xFF9966CC);
        brightness = Brightness.dark;
        break;
      default:
        // Fallback to classic light or classic dark
        if (isDark) {
          scaffoldBg = darkBg;
          primaryColor = darkPrimary;
          accentColor = darkAccent;
          borderColor = darkBorder;
          cardBg = darkCardBg;
          textPrimary = darkTextPrimary;
          textSecondary = darkTextSecondary;
        } else {
          scaffoldBg = lightBg;
          primaryColor = lightPrimary;
          accentColor = lightAccent;
          borderColor = lightBorder;
          cardBg = lightCardBg;
          textPrimary = lightTextPrimary;
          textSecondary = lightTextSecondary;
        }
    }

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldBg,
      primaryColor: primaryColor,
      cardColor: cardBg,
      dividerColor: borderColor,
      colorScheme: brightness == Brightness.dark
          ? ColorScheme.dark(
              primary: primaryColor,
              secondary: textSecondary,
              background: scaffoldBg,
              surface: cardBg,
              onPrimary: Colors.black,
              onSecondary: Colors.white,
              onBackground: textPrimary,
              onSurface: textPrimary,
              outline: borderColor,
            )
          : ColorScheme.light(
              primary: primaryColor,
              secondary: textSecondary,
              background: scaffoldBg,
              surface: cardBg,
              onPrimary: Colors.white,
              onSecondary: Colors.black,
              onBackground: textPrimary,
              onSurface: textPrimary,
              outline: borderColor,
            ),
      textTheme: GoogleFonts.interTextTheme(
        brightness == Brightness.dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
      ).copyWith(
        displayLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, letterSpacing: -0.3),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 20, letterSpacing: -0.2),
        titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w500, fontSize: 16),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16, height: 1.4),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 14, height: 1.4),
        labelLarge: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scaffoldBg,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondary,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: accentColor,
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
          borderSide: BorderSide(color: primaryColor, width: 1),
        ),
        hintStyle: TextStyle(color: textSecondary),
      ),
    );
  }
}
