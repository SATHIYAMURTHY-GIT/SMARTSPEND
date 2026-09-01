import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _violetSeed = Color(0xFF6D3FE8);
  static const _magenta = Color(0xFFB23AD2);
  static const _darkMagenta = Color(0xFFE5A2EF);
  static const _darkFoundation = Color(0xFF100B24);
  static const _darkSurface = Color(0xFF15102E);
  static const _darkSurfaceContainer = Color(0xFF1D1739);
  static const _darkSurfaceHighest = Color(0xFF2A2248);
  static const _lightSurface = Color(0xFFFCF9FE);
  static const _lightSurfaceContainer = Color(0xFFF3EDF8);

  static ThemeData get light => _buildTheme(Brightness.light);

  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = _colorScheme(brightness);

    return ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: isDark ? _darkFoundation : _lightSurface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: isDark ? _darkFoundation : _lightSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? _darkSurface : _lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? _darkSurface : _lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? _darkSurfaceContainer : _lightSurfaceContainer,
        indicatorColor: colorScheme.secondaryContainer,
        height: 76,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurface),
        ),
      ),
    );
  }

  static ColorScheme _colorScheme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _violetSeed,
      brightness: brightness,
    );

    if (brightness == Brightness.dark) {
      return scheme.copyWith(
        surface: _darkSurface,
        surfaceContainer: _darkSurfaceContainer,
        surfaceContainerHighest: _darkSurfaceHighest,
        primary: const Color(0xFFCFB5FF),
        onPrimary: const Color(0xFF321067),
        primaryContainer: const Color(0xFF4B2389),
        onPrimaryContainer: const Color(0xFFEBDCFF),
        secondary: _darkMagenta,
        onSecondary: const Color(0xFF3B0A45),
        secondaryContainer: const Color(0xFF55205E),
        onSecondaryContainer: const Color(0xFFFFD9FF),
      );
    }

    return scheme.copyWith(
      surface: _lightSurface,
      surfaceContainer: _lightSurfaceContainer,
      primary: const Color(0xFF5E2BBF),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFEADDFF),
      onPrimaryContainer: const Color(0xFF21005D),
      secondary: _magenta,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFF5D8FA),
      onSecondaryContainer: const Color(0xFF3A0A48),
    );
  }
}