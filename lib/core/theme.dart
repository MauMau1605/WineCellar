import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Application theme - Wine-inspired colors with Material 3
class AppTheme {
  AppTheme._();

  // Wine-inspired color palette
  static const Color _wineRed = Color(0xFF722F37);
  static const Color _wineGold = Color(0xFFD4A843);
  static const Color _creamWhite = Color(0xFFF5F0E8);
  static const Color _darkBrown = Color(0xFF3E2723);

  static final ColorScheme _lightColorScheme = ColorScheme.fromSeed(
    seedColor: _wineRed,
    brightness: Brightness.light,
    primary: _wineRed,
    secondary: _wineGold,
    surface: _creamWhite,
    onSurface: _darkBrown,
  );

  static final ColorScheme _darkColorScheme = ColorScheme.fromSeed(
    seedColor: _wineRed,
    brightness: Brightness.dark,
    primary: const Color(0xFFE57373),
    secondary: _wineGold,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _lightColorScheme,
      textTheme: GoogleFonts.nunitoTextTheme(),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: _lightColorScheme.surface,
        foregroundColor: _lightColorScheme.onSurface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _wineRed,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _darkColorScheme,
      textTheme: GoogleFonts.nunitoTextTheme(
        ThemeData.dark().textTheme,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
      ),
    );
  }

  /// Color for a wine color enum value
  static Color colorForWine(String colorName) {
    switch (colorName) {
      case 'red':
        return const Color(0xFF8B0000);
      case 'white':
        return const Color(0xFFFFD700);
      case 'rose':
        return const Color(0xFFFF69B4);
      case 'sparkling':
        return const Color(0xFFADD8E6);
      case 'sweet':
        return const Color(0xFFDAA520);
      default:
        return Colors.grey;
    }
  }
}
