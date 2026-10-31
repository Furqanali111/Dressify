import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Fraunces (editorial serif) for display voice, Manrope for everything read.
class AppTypography {
  const AppTypography._();

  static TextTheme textTheme(Color textColor) {
    final TextStyle body = GoogleFonts.manrope(color: textColor);
    TextStyle serif(double size, FontWeight w, double h) => GoogleFonts.fraunces(
          color: textColor,
          fontSize: size,
          fontWeight: w,
          height: h,
          letterSpacing: -size * 0.02,
        );

    return TextTheme(
      displayLarge: serif(36, FontWeight.w600, 1.1),
      displayMedium: serif(30, FontWeight.w600, 1.15),
      headlineLarge: serif(25, FontWeight.w600, 1.2),
      headlineMedium: serif(21, FontWeight.w600, 1.25),
      titleLarge: body.copyWith(fontSize: 18, fontWeight: FontWeight.w700, height: 1.35),
      titleMedium: body.copyWith(fontSize: 16, fontWeight: FontWeight.w700, height: 1.4),
      bodyLarge: body.copyWith(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
      bodyMedium: body.copyWith(fontSize: 14.5, fontWeight: FontWeight.w400, height: 1.5),
      bodySmall: body.copyWith(fontSize: 12.5, fontWeight: FontWeight.w500, height: 1.4),
      labelLarge: body.copyWith(fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.2),
      labelMedium: body.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.2),
      labelSmall: body.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.2),
    );
  }
}
