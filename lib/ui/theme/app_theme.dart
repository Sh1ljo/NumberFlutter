import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color surface = Color(0xFF131313);
  static const Color surfaceContainerLowest = Color(0xFF0E0E0E);
  static const Color surfaceContainerLow = Color(0xFF1B1B1B);
  static const Color surfaceContainer = Color(0xFF1F1F1F);
  static const Color surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color surfaceContainerHighest = Color(0xFF353535);

  static const Color primary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFD4D4D4);
  static const Color onPrimary = Color(0xFF1A1C1C);

  static const Color secondary = Color(0xFFC6C6C7);
  static const Color onSurface = Color(0xFFE2E2E2);
  static const Color outline = Color(0xFF919191);
  static const Color outlineVariant = Color(0xFF474747);
  static const Color error = Color(0xFFFFB4AB);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: surface,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: onPrimary,
        secondary: secondary,
        surface: surface,
        onSurface: onSurface,
        error: error,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.spaceGrotesk(
          color: primary,
          fontWeight: FontWeight.w900,
          letterSpacing: -2.0,
        ),
        displayMedium: GoogleFonts.spaceGrotesk(
          color: primary,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.0,
        ),
        titleLarge: GoogleFonts.spaceGrotesk(
          color: primary,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: GoogleFonts.manrope(
          color: onSurface,
          fontWeight: FontWeight.normal,
        ),
        bodyMedium: GoogleFonts.manrope(
          color: onSurface,
          fontWeight: FontWeight.w300,
        ),
        labelSmall: GoogleFonts.manrope(
          color: outline,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
      useMaterial3: true,
    );
  }
}
