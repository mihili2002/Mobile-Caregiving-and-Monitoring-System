import 'package:flutter/material.dart';
 
class AppTheme {
  // Your login/register palette
  static const Color primaryColor = Color(0xFF00BBA7);  // Renamed from brown
  static const Color primaryDark = Color(0xFF009E8D);   // Renamed from brownDark
  static const Color primaryLight = Color(0xFFB2EBF2);  // Renamed from brownLight
 
  static const Color bgTop = Color(0xFFF0F9F8);
  static const Color bgBottom = Color(0xFFE0F2F1);
 
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: bgTop,
 
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryDark,
      primary: primaryDark,
      secondary: primaryLight,
      surface: Colors.white,
      background: bgTop,
      // Add these for better contrast
      onPrimary: Colors.white,
      onSecondary: Colors.black87,
      onSurface: Colors.black,
      onBackground: Colors.black,
    ),
 
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryDark,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
 
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white, // Changed from Colors.white.withOpacity(0.8)
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.white.withOpacity(0.4), width: 1),
      ),
      margin: const EdgeInsets.symmetric(vertical: 10),
    ),
 
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white, // Changed from Colors.white.withOpacity(0.7)
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      hintStyle: TextStyle(color: Colors.black38, fontSize: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.5), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: primaryDark.withOpacity(0.4), width: 1.5),
      ),
      labelStyle: const TextStyle(
        color: Colors.black, // Changed from Colors.black.withOpacity(0.6)
        fontWeight: FontWeight.w600,
      ),
    ),
 
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: primaryDark.withOpacity(0.25),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 18),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          letterSpacing: 0.5,
        ),
      ),
    ),
 
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryDark,
        side: BorderSide(color: primaryDark.withOpacity(0.2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
 
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white.withOpacity(0.7),
      selectedColor: primaryDark.withOpacity(0.15),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      side: BorderSide(color: Colors.black.withOpacity(0.04)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
 
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: Colors.black, // Changed from Colors.black87
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: Colors.black, // Changed from Colors.black87
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: Colors.black, // Changed from Colors.black87
      ),
      bodyLarge: TextStyle(
        fontSize: 17, 
        color: Colors.black, // Changed from Colors.black87
        height: 1.5
      ),
      bodyMedium: TextStyle(
        fontSize: 15, 
        color: Colors.black, // Changed from Colors.black54
        height: 1.4
      ),
    ),
  );
}