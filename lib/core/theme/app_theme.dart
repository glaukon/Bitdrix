import 'package:flutter/material.dart';

/// Bitdrix application theme.
///
/// Dark theme optimised for a media-heavy torrent client.
/// Primary: deep violet (#7C4DFF)
/// Background: near-black (#0A0A0F)
/// Surface: dark card (#12121A)
/// Accent / secondary: cyan (#00E5FF)
class AppTheme {
  AppTheme._();

  // ── Brand colours ──────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF7C4DFF);
  static const Color primaryLight = Color(0xFFB47CFF);
  static const Color primaryDark = Color(0xFF4A00E0);

  static const Color accent = Color(0xFF00E5FF);
  static const Color accentDark = Color(0xFF00B8D4);

  static const Color background = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF12121A);
  static const Color surfaceVariant = Color(0xFF1C1C28);
  static const Color cardColor = Color(0xFF1A1A24);

  static const Color onBackground = Color(0xFFEEEEFF);
  static const Color onSurface = Color(0xFFCCCCDD);
  static const Color onSurfaceVariant = Color(0xFF888899);

  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFFD740);
  static const Color error = Color(0xFFFF5252);
  static const Color paused = Color(0xFF8888AA);
  static const Color queued = Color(0xFFFFD740);

  // ── Status colours ─────────────────────────────────────────────────────────
  static Color statusColor(String status) {
    switch (status) {
      case 'downloading':
        return accent;
      case 'completed':
        return success;
      case 'paused':
        return paused;
      case 'error':
        return error;
      case 'queued':
        return queued;
      default:
        return onSurfaceVariant;
    }
  }

  // ── ThemeData ──────────────────────────────────────────────────────────────
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: primaryDark,
        onPrimaryContainer: primaryLight,
        secondary: accent,
        onSecondary: Colors.black,
        secondaryContainer: accentDark,
        onSecondaryContainer: Colors.white,
        surface: surface,
        onSurface: onSurface,
        surfaceContainerHighest: surfaceVariant,
        onSurfaceVariant: onSurfaceVariant,
        error: error,
        onError: Colors.white,
        outline: Color(0xFF333348),
        outlineVariant: Color(0xFF222233),
      ),
      scaffoldBackgroundColor: background,
      cardColor: cardColor,
      dividerColor: const Color(0xFF222233),

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onBackground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: onBackground,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: onBackground),
      ),

      // Bottom navigation
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withAlpha(51),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary, size: 24);
          }
          return const IconThemeData(color: onSurfaceVariant, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(
            color: onSurfaceVariant,
            fontSize: 12,
          );
        }),
      ),

      // Cards
      cardTheme: CardTheme(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF222233), width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      // Elevated button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Text button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
        ),
      ),

      // Icon button
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: onSurface,
        ),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF333348)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF333348)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error),
        ),
        hintStyle: const TextStyle(color: onSurfaceVariant),
        labelStyle: const TextStyle(color: onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // FAB
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),

      // Tab bar
      tabBarTheme: const TabBarTheme(
        labelColor: primary,
        unselectedLabelColor: onSurfaceVariant,
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.tab,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariant,
        selectedColor: primary.withAlpha(51),
        labelStyle: const TextStyle(color: onSurface, fontSize: 12),
        side: const BorderSide(color: Color(0xFF333348)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      // List tile
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: onSurfaceVariant,
        textColor: onSurface,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceVariant,
        contentTextStyle: const TextStyle(color: onBackground),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Dialog
      dialogTheme: DialogTheme(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: const TextStyle(
          color: onBackground,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(
          color: onSurface,
          fontSize: 14,
        ),
      ),

      // Text theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: onBackground, fontWeight: FontWeight.w800),
        displayMedium: TextStyle(color: onBackground, fontWeight: FontWeight.w700),
        displaySmall: TextStyle(color: onBackground, fontWeight: FontWeight.w700),
        headlineLarge: TextStyle(color: onBackground, fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(color: onBackground, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(color: onBackground, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: onBackground, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: onSurface, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(color: onSurface, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: onSurface),
        bodyMedium: TextStyle(color: onSurface),
        bodySmall: TextStyle(color: onSurfaceVariant),
        labelLarge: TextStyle(color: onBackground, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(color: onSurfaceVariant),
        labelSmall: TextStyle(color: onSurfaceVariant, fontSize: 10),
      ),
    );
  }
}
