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

  // "Atelier" palette: warm bone paper, ink black, one vermilion accent.
  static const AppColors light = AppColors(
    primary: Color(0xFFD6401F),
    primaryDark: Color(0xFFA82E12),
    surface: Color(0xFFFFFDF9),
    background: Color(0xFFF5F0E8),
    textPrimary: Color(0xFF17140F),
    textSecondary: Color(0xFF675F54),
    success: Color(0xFF2E7D52),
    error: Color(0xFFC62828),
    overlay: Color(0x8C17140F),
    border: Color(0xFFE3DBCF),
  );

  static const AppColors dark = AppColors(
    primary: Color(0xFFE8553A),
    primaryDark: Color(0xFFC63F26),
    surface: Color(0xFF211E1A),
    background: Color(0xFF151310),
    textPrimary: Color(0xFFF5F0E8),
    textSecondary: Color(0xFFB0A89B),
    success: Color(0xFF4CAF7A),
    error: Color(0xFFFF7A70),
    overlay: Color(0x8C000000),
    border: Color(0xFF332F29),
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
