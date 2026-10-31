import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.primary,
    required this.primaryDark,
    required this.surface,
    required this.background,
    required this.textPrimary,
    required this.textSecondary,
    required this.success,
    required this.error,
    required this.overlay,
    required this.border,
  });

  final Color primary;
  final Color primaryDark;
  final Color surface;
  final Color background;
  final Color textPrimary;
  final Color textSecondary;
  final Color success;
  final Color error;
  final Color overlay;
  final Color border;

  // Atelier palette: warm paper + ink, one vermilion accent.
  static const AppColors light = AppColors(
    primary: Color(0xFFC93A1F),
    primaryDark: Color(0xFFA32D16),
    surface: Color(0xFFFCFAF6),
    background: Color(0xFFF4EFE7),
    textPrimary: Color(0xFF1B1714),
    textSecondary: Color(0xFF675E55),
    success: Color(0xFF2F7D5B),
    error: Color(0xFFB3261E),
    overlay: Color(0x8C1B1714),
    border: Color(0xFFE0D8CB),
  );

  static const AppColors dark = AppColors(
    primary: Color(0xFFD9462A),
    primaryDark: Color(0xFFB8381F),
    surface: Color(0xFF1F1B18),
    background: Color(0xFF141210),
    textPrimary: Color(0xFFF3EDE4),
    textSecondary: Color(0xFFAAA196),
    success: Color(0xFF4FAF86),
    error: Color(0xFFFF8A7A),
    overlay: Color(0x8C000000),
    border: Color(0xFF332E29),
  );

  @override
  AppColors copyWith({
    Color? primary,
    Color? primaryDark,
    Color? surface,
    Color? background,
    Color? textPrimary,
    Color? textSecondary,
    Color? success,
    Color? error,
    Color? overlay,
    Color? border,
  }) {
    return AppColors(
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      surface: surface ?? this.surface,
      background: background ?? this.background,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      success: success ?? this.success,
      error: error ?? this.error,
      overlay: overlay ?? this.overlay,
      border: border ?? this.border,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      background: Color.lerp(background, other.background, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      success: Color.lerp(success, other.success, t)!,
      error: Color.lerp(error, other.error, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
