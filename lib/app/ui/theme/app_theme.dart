import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Theme Color System (Dark Mode)
  static const Color darkBackground = Color(0xFF0D0E12); // Deep Space Obsidian
  static const Color darkCardBg = Color(0xFF1A1C24); // Card & Surface background
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF8E929E);
  static const Color darkBorder = Color(0xFF2C2F3D);

  // Theme Color System (Light Mode)
  static const Color lightBackground = Color(0xFFF7F8FA); // Cool white/grey
  static const Color lightCardBg = Color(0xFFFFFFFF); // Pure White
  static const Color lightTextPrimary = Color(0xFF1C1E24);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  static const Color lightBorder = Color(0xFFE5E7EB);

  // Constants
  static const Color primary = Color(0xFFFF007F); // Neon Dance Pink
  static const Color secondary = Color(0xFF7B2CBF); // Energetic Purple
  static const Color accent = Color(0xFF00E5FF); // Cyan Accent

  // Static Fallbacks for styling references
  static const Color border = darkBorder;
  static const Color textSecondary = darkTextSecondary;
  static const Color textPrimary = darkTextPrimary;
  static const Color cardBg = darkCardBg;

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        tertiary: accent,
        surface: darkCardBg,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: darkTextPrimary,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: darkTextPrimary,
          letterSpacing: -0.5,
        ),
        titleLarge: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: darkTextPrimary),
        bodyLarge: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.normal, color: darkTextPrimary),
        bodyMedium: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.normal, color: darkTextSecondary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkTextPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkBackground,
        selectedItemColor: primary,
        unselectedItemColor: darkTextSecondary,
        elevation: 10,
        type: BottomNavigationBarType.fixed,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCardBg,
        hintStyle: const TextStyle(color: darkTextSecondary, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      primaryColor: primary,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        tertiary: accent,
        surface: lightCardBg,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightTextPrimary,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: lightTextPrimary,
          letterSpacing: -0.5,
        ),
        titleLarge: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: lightTextPrimary),
        bodyLarge: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.normal, color: lightTextPrimary),
        bodyMedium: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.normal, color: lightTextSecondary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: lightTextPrimary),
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: lightTextPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightCardBg,
        selectedItemColor: primary,
        unselectedItemColor: lightTextSecondary,
        elevation: 10,
        type: BottomNavigationBarType.fixed,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightCardBg,
        hintStyle: const TextStyle(color: lightTextSecondary, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
    );
  }
}
