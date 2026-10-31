import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Editorial serif (Fraunces) for display, Plus Jakarta Sans for UI.
class AppTypography {
  const AppTypography._();

  static TextTheme textTheme(Color textColor) {
    final TextStyle body = GoogleFonts.plusJakartaSans(color: textColor);
    TextStyle serif(double size, double height) => GoogleFonts.fraunces(
          color: textColor,
          fontSize: size,
          fontWeight: FontWeight.w500,
          height: height,
          letterSpacing: -0.6,
        );

    return TextTheme(
      displayLarge: serif(34, 1.12),
      displayMedium: serif(30, 1.14),
      headlineLarge: serif(26, 1.18),
      headlineMedium: serif(22, 1.22),
      titleLarge: body.copyWith(fontSize: 18, fontWeight: FontWeight.w700, height: 1.3, letterSpacing: -0.2),
      titleMedium: body.copyWith(fontSize: 16, fontWeight: FontWeight.w600, height: 1.35, letterSpacing: -0.1),
      bodyLarge: body.copyWith(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
      bodyMedium: body.copyWith(fontSize: 15, fontWeight: FontWeight.w400, height: 1.5),
      bodySmall: body.copyWith(fontSize: 13, fontWeight: FontWeight.w400, height: 1.4),
      labelLarge: body.copyWith(fontSize: 15, fontWeight: FontWeight.w600, height: 1.2),
      labelMedium: body.copyWith(fontSize: 13, fontWeight: FontWeight.w500, height: 1.2),
      labelSmall: body.copyWith(fontSize: 11, fontWeight: FontWeight.w600, height: 1.2, letterSpacing: 1.2),
    );
  }
}
