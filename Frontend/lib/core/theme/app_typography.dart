import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Editorial pairing: Fraunces (serif display) + Manrope (body/UI).
class AppTypography {
  const AppTypography._();

  static TextTheme textTheme(Color textColor) {
    final TextStyle body = GoogleFonts.manrope(color: textColor);
    TextStyle display(double size, FontWeight w, double h) =>
        GoogleFonts.fraunces(
          color: textColor,
          fontSize: size,
          fontWeight: w,
          height: h,
          letterSpacing: -size * 0.02,
        );

    return TextTheme(
      displayLarge: display(34, FontWeight.w600, 1.1),
      displayMedium: display(28, FontWeight.w600, 1.15),
      headlineLarge: display(24, FontWeight.w600, 1.2),
      headlineMedium: display(20, FontWeight.w600, 1.25),
      titleLarge: body.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.2,
      ),
      titleMedium: body.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.35,
        letterSpacing: -0.1,
      ),
      bodyLarge: body.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      bodyMedium: body.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      bodySmall: body.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
      labelLarge: body.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: 0.1,
      ),
      labelMedium: body.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.2,
      ),
      labelSmall: body.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.4,
      ),
    );
  }
}
