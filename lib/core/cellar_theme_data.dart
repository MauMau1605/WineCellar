import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_theme.dart';

/// Maps each [VirtualCellarTheme] to a full [ThemeData] so the entire
/// interface can adopt the cellar's visual identity.
class CellarThemeData {
  CellarThemeData._();

  /// Returns the [ThemeData] for the given cellar theme.
  /// [platformBrightness] is used for classic/wineFridge to follow the system.
  static ThemeData forTheme(
    VirtualCellarTheme theme, {
    Brightness platformBrightness = Brightness.light,
  }) {
    switch (theme) {
      case VirtualCellarTheme.classic:
      case VirtualCellarTheme.wineFridge:
        // These themes don't override — caller checks overridesAppTheme first.
        // Return a fallback that won't be used in practice.
        return ThemeData.light();
      case VirtualCellarTheme.premiumCave:
        return _premiumCave;
    }
  }

  /// Whether the given theme overrides the default app theme.
  static bool overridesAppTheme(VirtualCellarTheme? theme) {
    if (theme == null) return false;
    switch (theme) {
      case VirtualCellarTheme.classic:
      case VirtualCellarTheme.wineFridge:
        return false;
      case VirtualCellarTheme.premiumCave:
        return true;
    }
  }

  // ─── Premium Cave: dark luxurious wood & gold ─────────────────────

  static const Color _darkWood = Color(0xFF1A0E0A);
  static const Color _darkPanel = Color(0xFF2A1810);
  static const Color _warmGold = Color(0xFFD4A843);
  static const Color _cream = Color(0xFFE8DCC8);
  static const Color _lightGold = Color(0xFFF0D890);

  static final ThemeData _premiumCave = _buildPremiumCave();

  static ThemeData _buildPremiumCave() {
    final colorScheme = ColorScheme.dark(
      brightness: Brightness.dark,
      primary: _warmGold,
      onPrimary: _darkWood,
      secondary: const Color(0xFFA07828),
      onSecondary: _cream,
      surface: _darkPanel,
      onSurface: _cream,
      surfaceContainerLowest: _darkWood,
      surfaceContainerLow: const Color(0xFF221410),
      surfaceContainer: const Color(0xFF2E1A12),
      surfaceContainerHigh: const Color(0xFF3A2218),
      surfaceContainerHighest: const Color(0xFF462A1E),
      error: const Color(0xFFCF6679),
      onError: Colors.black,
      outline: const Color(0xFF6D5040),
      outlineVariant: const Color(0xFF4A3428),
    );

    final textTheme = GoogleFonts.nunitoTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _darkWood,
      textTheme: textTheme,

      // AppBar
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: _cream,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: _cream),
      ),

      // Cards
      cardTheme: CardThemeData(
        elevation: 4,
        color: _darkPanel.withValues(alpha: 0.85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _warmGold.withValues(alpha: 0.15)),
        ),
      ),

      // FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _warmGold,
        foregroundColor: _darkWood,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _warmGold.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _warmGold.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _warmGold),
        ),
        filled: true,
        fillColor: _darkPanel,
        labelStyle: const TextStyle(color: _cream),
        hintStyle: TextStyle(color: _cream.withValues(alpha: 0.5)),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: _darkPanel,
        selectedColor: _warmGold.withValues(alpha: 0.25),
        labelStyle: const TextStyle(color: _cream),
        secondaryLabelStyle: const TextStyle(color: _lightGold),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: _warmGold.withValues(alpha: 0.2)),
        ),
        checkmarkColor: _warmGold,
      ),

      // NavigationBar (bottom)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _darkPanel,
        indicatorColor: _warmGold.withValues(alpha: 0.2),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? _warmGold : _cream.withValues(alpha: 0.6),
            fontSize: 12,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? _warmGold : _cream.withValues(alpha: 0.6),
          );
        }),
      ),

      // NavigationRail (desktop)
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: _darkPanel,
        indicatorColor: _warmGold.withValues(alpha: 0.2),
        selectedIconTheme: const IconThemeData(color: _warmGold),
        unselectedIconTheme:
            IconThemeData(color: _cream.withValues(alpha: 0.6)),
        selectedLabelTextStyle: const TextStyle(color: _warmGold),
        unselectedLabelTextStyle:
            TextStyle(color: _cream.withValues(alpha: 0.6)),
      ),

      // PopupMenu
      popupMenuTheme: PopupMenuThemeData(
        color: _darkPanel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _warmGold.withValues(alpha: 0.15)),
        ),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF2A1810),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF3A2218),
        contentTextStyle: const TextStyle(color: _cream),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: _warmGold.withValues(alpha: 0.15),
      ),

      // Icon
      iconTheme: const IconThemeData(color: _cream),

      // FilledButton
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(_warmGold),
          foregroundColor: WidgetStatePropertyAll(_darkWood),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),

      // TextButton
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(_warmGold),
        ),
      ),

      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(_cream),
          side: WidgetStatePropertyAll(
            BorderSide(color: _warmGold.withValues(alpha: 0.3)),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),

      // BottomSheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _darkPanel,
      ),

      // Tooltip
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF3A2218),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: _cream, fontSize: 12),
      ),
    );
  }
}
