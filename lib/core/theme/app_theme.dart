import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryPurple = Color(0xFF8E44AD);
  static const Color accentPink = Color(0xFFFF69B4);
  static const Color brightCyan = Color(0xFF00E5FF);
  static const Color warmGold = Color(0xFFFFD700);
  static const Color darkCanvasBg = Color(0xFF1E1E2C);
  static const Color panelBg = Color(0xFF2A2A3D);

  static ThemeData get theme {
    return ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: darkCanvasBg,
      colorScheme: const ColorScheme.dark(
        primary: accentPink,
        secondary: brightCyan,
        surface: panelBg,
        tertiary: warmGold,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: panelBg,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: panelBg,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentPink,
        foregroundColor: Colors.white,
      ),
    );
  }
}
