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

  static const AppColors light = AppColors(
    primary: Color(0xFF6C63FF),
    primaryDark: Color(0xFF4B44CC),
    surface: Color(0xFFFFFFFF),
    background: Color(0xFFF5F4FF),
    textPrimary: Color(0xFF1A1A2E),
    textSecondary: Color(0xFF6B6B8A),
    success: Color(0xFF22C97A),
    error: Color(0xFFFF5C5C),
    overlay: Color(0x8C000000),
    border: Color(0xFFE8E6F0),
  );

  static const AppColors dark = AppColors(
    primary: Color(0xFFA89CFF),
    primaryDark: Color(0xFF7B70EE),
    surface: Color(0xFF1C1C2E),
    background: Color(0xFF0D0D1A),
    textPrimary: Color(0xFFF0EFFF),
    textSecondary: Color(0xFF9999BB),
    success: Color(0xFF1FA865),
    error: Color(0xFFFF7070),
    overlay: Color(0x8C000000),
    border: Color(0xFF2A2A40),
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
