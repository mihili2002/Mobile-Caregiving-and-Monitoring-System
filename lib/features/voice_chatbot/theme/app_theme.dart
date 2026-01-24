import 'package:flutter/material.dart';

class AppTheme {
  // Your login/register palette
  static const Color brown = Color(0xFF00BBA7);
  static const Color brownDark = Color(0xFF009E8D);
  static const Color brownLight = Color(0xFF2FE6D2);

  static const Color bgTop = Color(0xFFE9FBF8);
  static const Color bgBottom = Color(0xFFF4FFFD);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,

    scaffoldBackgroundColor: bgTop,

    colorScheme: ColorScheme.fromSeed(
      seedColor: brownDark,
      primary: brownDark,
      secondary: brownLight,
      surface: Colors.white,
      background: bgTop,
    ),

    // AppBar matches screenshots
    appBarTheme: const AppBarTheme(
      backgroundColor: brownDark,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
    ),

    // Global card design
    cardTheme: CardThemeData(
      elevation: 4,
      color: Colors.white.withOpacity(0.95),
      shadowColor: Colors.black.withOpacity(0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: const EdgeInsets.symmetric(vertical: 10),
    ),

    // Global inputs (same as Login/Register soft inputs)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withOpacity(0.90),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: brownDark.withOpacity(0.6), width: 1.5),
      ),
      labelStyle: TextStyle(
        color: Colors.black.withOpacity(0.55),
        fontWeight: FontWeight.w600,
      ),
    ),

    // Elevated buttons match your login/register button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: brownDark,
        foregroundColor: Colors.white,
        elevation: 8,
        shadowColor: brownDark.withOpacity(0.35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),

    // Outlined buttons match
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: brownDark,
        side: BorderSide(color: brownDark.withOpacity(0.35)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),

    // ChoiceChips for PatientHealthDetailsScreen
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: brownDark.withOpacity(0.12),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      side: BorderSide(color: Colors.black.withOpacity(0.06)),
    ),

    // Switch styling
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return brownDark;
        return Colors.grey.shade400;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return brownDark.withOpacity(0.35);
        return Colors.grey.shade300;
      }),
    ),

    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 16),
      bodyLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
  );
}