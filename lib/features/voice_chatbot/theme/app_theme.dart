import 'package:flutter/material.dart';

class AppTheme {
  // ✅ Main Green Theme Color (matches your chip/button green)
  static const Color primaryGreen = Color(0xFF00A693);
  static const Color primaryGreenDark = Color(0xFF00897B);

  // ✅ Light background (soft, elder-friendly)
  static const Color bgTop = Color(0xFFF6FBFA);
  static const Color bgBottom = Color(0xFFEFF7F6);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,

    scaffoldBackgroundColor: bgTop,

    // ✅ Color Scheme
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryGreen,
      primary: primaryGreen,
      secondary: primaryGreenDark,
      surface: Colors.white,
      background: bgTop,
    ),

    // ✅ AppBar Theme
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryGreenDark,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
    ),

    // ✅ Cards
    cardTheme: CardThemeData(
      elevation: 4,
      color: Colors.white.withOpacity(0.97),
      shadowColor: Colors.black.withOpacity(0.10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: const EdgeInsets.symmetric(vertical: 10),
    ),

    // ✅ Inputs (TextFields, Dropdowns)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withOpacity(0.95),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: primaryGreen.withOpacity(0.85), width: 1.6),
      ),
      labelStyle: TextStyle(
        color: Colors.black.withOpacity(0.55),
        fontWeight: FontWeight.w600,
      ),
    ),

    // ✅ Elevated Buttons (your submit button will become GREEN)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 8,
        shadowColor: primaryGreen.withOpacity(0.35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),

    // ✅ Outlined Buttons
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryGreenDark,
        side: BorderSide(color: primaryGreenDark.withOpacity(0.35)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),

    // ✅ ChoiceChips / Filter Chips (Dietary + Conditions)
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: primaryGreen,
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        color: Colors.black,
      ),
      secondaryLabelStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      side: BorderSide(color: Colors.black.withOpacity(0.06)),
    ),

    // ✅ Switch Theme
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return primaryGreen;
        return Colors.grey.shade400;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return primaryGreen.withOpacity(0.35);
        return Colors.grey.shade300;
      }),
    ),

    // ✅ Text Theme
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 16),
      bodyLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
  );
}
