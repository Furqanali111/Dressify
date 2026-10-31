import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.primary,
    required this.onPrimary,
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
  final Color onPrimary;
  final Color primaryDark;
  final Color surface;
  final Color background;
  final Color textPrimary;
  final Color textSecondary;
  final Color success;
  final Color error;
  final Color overlay;
  final Color border;

  // Warm monochrome: ink on bone. Colour is reserved for status only.
  static const AppColors light = AppColors(
    primary: Color(0xFF111111),
    onPrimary: Color(0xFFFFFFFF),
    primaryDark: Color(0xFF333333),
    surface: Color(0xFFFFFFFF),
    background: Color(0xFFF7F6F3),
    textPrimary: Color(0xFF111111),
    textSecondary: Color(0xFF787774),
    success: Color(0xFF346538),
    error: Color(0xFF9F2F2D),
    overlay: Color(0x8C000000),
    border: Color(0xFFEAEAEA),
  );

  static const AppColors dark = AppColors(
    primary: Color(0xFFF2F0EB),
    onPrimary: Color(0xFF111111),
    primaryDark: Color(0xFFD9D6CE),
    surface: Color(0xFF181817),
    background: Color(0xFF0F0F0E),
    textPrimary: Color(0xFFF2F0EB),
    textSecondary: Color(0xFF9B9892),
    success: Color(0xFF8FBF93),
    error: Color(0xFFE08A87),
    overlay: Color(0x8C000000),
    border: Color(0xFF2A2A28),
  );

  @override
  AppColors copyWith({
    Color? primary,
    Color? onPrimary,
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
      onPrimary: onPrimary ?? this.onPrimary,
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
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
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
