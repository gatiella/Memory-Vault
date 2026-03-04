import 'package:flutter/material.dart';

class AppTheme {
  // Brand colors
  static const Color indigo = Color(0xFF4F6EF7);
  static const Color violet = Color(0xFF7C3AED);
  static const Color indigoLight = Color(0xFF8BA4FA);

  // Dark palette
  static const Color darkBg = Color(0xFF0A0A0F);
  static const Color darkSurface = Color(0xFF13131A);
  static const Color darkCard = Color(0xFF1C1C26);
  static const Color darkBorder = Color(0xFF2A2A38);
  static const Color darkText = Color(0xFFE8E8F0);
  static const Color darkSubtext = Color(0xFF8888A8);

  // Light palette
  static const Color lightBg = Color(0xFFF4F4FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E2EE);
  static const Color lightText = Color(0xFF0A0A1A);
  static const Color lightSubtext = Color(0xff6666888);

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBg,
    colorScheme: const ColorScheme.dark(
      primary: indigo,
      secondary: violet,
      surface: darkSurface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: darkBg,
      elevation: 0,
      iconTheme: IconThemeData(color: darkText),
      titleTextStyle: TextStyle(
        color: darkText,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
    ),
    cardTheme: CardThemeData(
      color: darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: darkBorder, width: 1),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: darkSurface,
      selectedItemColor: indigo,
      unselectedItemColor: darkSubtext,
      elevation: 0,
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: darkSurface),
    dividerColor: darkBorder,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: indigo, width: 1.5),
      ),
      labelStyle: const TextStyle(color: darkSubtext),
      hintStyle: const TextStyle(color: darkSubtext),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? indigo : Colors.transparent),
      side: const BorderSide(color: darkBorder, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: indigo,
      foregroundColor: Colors.white,
      elevation: 4,
    ),
  );

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightBg,
    colorScheme: const ColorScheme.light(
      primary: indigo,
      secondary: violet,
      surface: lightSurface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: lightBg,
      elevation: 0,
      iconTheme: IconThemeData(color: lightText),
      titleTextStyle: TextStyle(
        color: lightText,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
    ),
    cardTheme: CardThemeData(
      color: lightCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: lightBorder, width: 1),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: lightSurface,
      selectedItemColor: indigo,
      unselectedItemColor: Color(0xFF9999AA),
      elevation: 0,
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: lightSurface),
    dividerColor: lightBorder,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: indigo, width: 1.5),
      ),
      labelStyle: const TextStyle(color: Color(0xFF666688)),
      hintStyle: const TextStyle(color: Color(0xFF9999AA)),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? indigo : Colors.transparent),
      side: const BorderSide(color: lightBorder, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: indigo,
      foregroundColor: Colors.white,
      elevation: 4,
    ),
  );
}