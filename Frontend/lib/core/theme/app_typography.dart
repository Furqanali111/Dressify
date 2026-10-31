import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  const AppTypography._();

  static TextTheme textTheme(Color textColor) {
    final TextStyle base = GoogleFonts.dmSans(color: textColor);

    TextStyle serif(double size, FontWeight w, double h) => GoogleFonts.fraunces(
        color: textColor, fontSize: size, fontWeight: w, height: h, letterSpacing: -0.5);

    return TextTheme(
      displayLarge: serif(34, FontWeight.w600, 1.1),
      displayMedium: serif(30, FontWeight.w600, 1.15),
      headlineLarge: serif(26, FontWeight.w600, 1.2),
      headlineMedium: serif(22, FontWeight.w600, 1.25),
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
