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
    this.onPrimary = const Color(0xFFFFFFFF),
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
  final Color onPrimary;

  static const AppColors light = AppColors(
    primary: Color(0xFFB8472A),
    primaryDark: Color(0xFF8F3219),
    surface: Color(0xFFFCFAF6),
    background: Color(0xFFF4F1EB),
    textPrimary: Color(0xFF1A1612),
    textSecondary: Color(0xFF6E665C),
    success: Color(0xFF3F7D5A),
    error: Color(0xFFC0392B),
    overlay: Color(0x8C000000),
    border: Color(0xFFE6E0D6),
  );

  static const AppColors dark = AppColors(
    primary: Color(0xFFE0825F),
    primaryDark: Color(0xFFC4623F),
    surface: Color(0xFF1D1A17),
    background: Color(0xFF12100E),
    textPrimary: Color(0xFFF3EEE6),
    textSecondary: Color(0xFFA39A8E),
    success: Color(0xFF6FB38C),
    error: Color(0xFFE87A6B),
    overlay: Color(0x8C000000),
    border: Color(0xFF302B26),
    onPrimary: Color(0xFF1A0F0A),
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
    Color? onPrimary,
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
      onPrimary: onPrimary ?? this.onPrimary,
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
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
    );
  }
}

extension AppShadow on AppColors {
  /// Warm-tinted soft shadow (single top-left light source).
  List<BoxShadow> get softShadow => <BoxShadow>[
    BoxShadow(
      color: const Color(
        0xFF3A2A1A,
      ).withValues(alpha: surface.computeLuminance() > 0.5 ? 0.10 : 0.35),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
