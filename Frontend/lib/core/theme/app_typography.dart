import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  const AppTypography._();

  static TextTheme textTheme(Color textColor) {
    final TextStyle base = GoogleFonts.manrope(color: textColor);
    // Editorial serif for display/headline moments.
    final TextStyle serif = GoogleFonts.fraunces(color: textColor);

    return TextTheme(
      displayLarge: serif.copyWith(fontSize: 32, fontWeight: FontWeight.w600, height: 1.15, letterSpacing: -0.4),
      displayMedium: serif.copyWith(fontSize: 28, fontWeight: FontWeight.w600, height: 1.18, letterSpacing: -0.4),
      headlineLarge: serif.copyWith(fontSize: 24, fontWeight: FontWeight.w600, height: 1.2, letterSpacing: -0.4),
      headlineMedium: serif.copyWith(fontSize: 20, fontWeight: FontWeight.w600, height: 1.25, letterSpacing: -0.4),
      titleLarge: base.copyWith(fontSize: 18, fontWeight: FontWeight.w600, height: 1.35),
      titleMedium: base.copyWith(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
      bodyLarge: base.copyWith(fontSize: 16, fontWeight: FontWeight.w400, height: 1.45),
      bodyMedium: base.copyWith(fontSize: 15, fontWeight: FontWeight.w400, height: 1.45),
      bodySmall: base.copyWith(fontSize: 13, fontWeight: FontWeight.w400, height: 1.4),
      labelLarge: base.copyWith(fontSize: 15, fontWeight: FontWeight.w600, height: 1.2),
      labelMedium: base.copyWith(fontSize: 13, fontWeight: FontWeight.w500, height: 1.2),
      labelSmall: base.copyWith(fontSize: 12, fontWeight: FontWeight.w500, height: 1.2),
    );
  }
}
