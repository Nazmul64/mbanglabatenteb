import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors - Premium Obsidian & Glowing Accent Palettes
  static const Color primaryDark = Color(0xFF8B5CF6);  // Violet
  static const Color primaryLight = Color(0xFF6366F1); // Indigo
  
  static const Color accentCyan = Color(0xFF06B6D4);   // Neon Cyan
  static const Color accentTeal = Color(0xFF10B981);   // Emerald Green
  static const Color accentPink = Color(0xFFF43F5E);   // Rose Pink
  static const Color accentAmber = Color(0xFFF59E0B);  // Amber Gold
  
  // Backgrounds
  static const Color bgDark = Color(0xFF090D1A);       // Deep Obsidian Space
  static const Color bgLight = Color(0xFFF4F7FA);      // Soft Ice Grey
  
  static const Color cardDark = Color(0xFF121829);      // Dark Glass Slate
  static const Color cardLight = Color(0xFFFFFFFF);     // Pure White

  // Premium Gradients
  static Gradient get primaryGradient => const LinearGradient(
        colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)], // Neon Cyan to Blue
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static Gradient get purpleGradient => const LinearGradient(
        colors: [Color(0xFFD946EF), Color(0xFF8B5CF6)], // Magenta to Violet
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static Gradient get sunsetGradient => const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFEF4444)], // Gold Amber to Rose Red
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static Gradient get greenGradient => const LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF047857)], // Vivid Emerald to Forest Teal
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static Gradient get darkGlassGradient => LinearGradient(
        colors: [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.02)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  // Dark Theme configuration
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      primaryColor: primaryDark,
      colorScheme: const ColorScheme.dark(
        primary: primaryDark,
        secondary: accentCyan,
        surface: cardDark,
        onSurface: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withOpacity(0.08), width: 1.2),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.8,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: bgDark,
        selectedItemColor: accentCyan,
        unselectedItemColor: Colors.white30,
        elevation: 10,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  // Light Theme configuration
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgLight,
      primaryColor: primaryLight,
      colorScheme: const ColorScheme.light(
        primary: primaryLight,
        secondary: primaryLight,
        surface: cardLight,
        onSurface: Color(0xFF0F172A),
      ),
      cardTheme: CardThemeData(
        color: cardLight,
        elevation: 4,
        shadowColor: const Color(0xFF0F172A).withOpacity(0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: const Color(0xFFE2E8F0).withOpacity(0.8), width: 1.2),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: Color(0xFF0F172A),
          letterSpacing: 0.8,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardLight,
        selectedItemColor: primaryLight,
        unselectedItemColor: Color(0xFF94A3B8),
        elevation: 10,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
