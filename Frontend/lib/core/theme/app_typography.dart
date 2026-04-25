import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  const AppTypography._();

  static TextTheme textTheme(Color textColor) {
    final TextStyle base = GoogleFonts.dmSans(color: textColor);

    return TextTheme(
      displayLarge: base.copyWith(fontSize: 28, fontWeight: FontWeight.w700, height: 1.2),
      displayMedium: base.copyWith(fontSize: 24, fontWeight: FontWeight.w700, height: 1.25),
      headlineLarge: base.copyWith(fontSize: 22, fontWeight: FontWeight.w700, height: 1.25),
      headlineMedium: base.copyWith(fontSize: 20, fontWeight: FontWeight.w600, height: 1.3),
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
