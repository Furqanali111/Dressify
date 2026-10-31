import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  const AppTypography._();

  /// Editorial serif for headings, grotesk sans for UI.
  static TextTheme textTheme(Color textColor) {
    final TextStyle sans = GoogleFonts.hankenGrotesk(color: textColor);
    final TextStyle serif = GoogleFonts.instrumentSerif(
      color: textColor,
      letterSpacing: -0.6,
      fontWeight: FontWeight.w400,
    );

    return TextTheme(
      displayLarge: serif.copyWith(fontSize: 40, height: 1.1),
      displayMedium: serif.copyWith(fontSize: 34, height: 1.1),
      headlineLarge: serif.copyWith(fontSize: 28, height: 1.15),
      headlineMedium: serif.copyWith(fontSize: 24, height: 1.2),
      titleLarge: serif.copyWith(fontSize: 22, height: 1.2),
      titleMedium: sans.copyWith(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
      bodyLarge: sans.copyWith(fontSize: 16, fontWeight: FontWeight.w400, height: 1.6),
      bodyMedium: sans.copyWith(fontSize: 15, fontWeight: FontWeight.w400, height: 1.55),
      bodySmall: sans.copyWith(fontSize: 13, fontWeight: FontWeight.w400, height: 1.5),
      labelLarge: sans.copyWith(fontSize: 14, fontWeight: FontWeight.w600, height: 1.2, letterSpacing: 0.2),
      labelMedium: sans.copyWith(fontSize: 13, fontWeight: FontWeight.w500, height: 1.2),
      labelSmall: sans.copyWith(fontSize: 11, fontWeight: FontWeight.w600, height: 1.2, letterSpacing: 0.8),
    );
  }
}
