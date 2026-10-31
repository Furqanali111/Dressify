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
    primary: Color(0xFFC8432B),
    primaryDark: Color(0xFFA33320),
    surface: Color(0xFFFFFDF9),
    background: Color(0xFFF4EFE7),
    textPrimary: Color(0xFF1B1814),
    textSecondary: Color(0xFF756D62),
    success: Color(0xFF3E8E63),
    error: Color(0xFFB3261E),
    overlay: Color(0x8C000000),
    border: Color(0xFFE6DED1),
  );

  static const AppColors dark = AppColors(
    primary: Color(0xFFE2573D),
    primaryDark: Color(0xFFC8432B),
    surface: Color(0xFF1C1915),
    background: Color(0xFF0F0D0B),
    textPrimary: Color(0xFFF3EDE3),
    textSecondary: Color(0xFFA29889),
    success: Color(0xFF5BB584),
    error: Color(0xFFFF8A80),
    overlay: Color(0x8C000000),
    border: Color(0xFF2B2722),
  );

  bool get isDark => background.computeLuminance() < 0.2;

  /// Highly diffused ambient shadow (no harsh drop shadows).
  List<BoxShadow> get softShadow => <BoxShadow>[
        BoxShadow(
          color: (isDark ? Colors.black : const Color(0xFF3A2E1E))
              .withValues(alpha: isDark ? 0.45 : 0.07),
          blurRadius: 32,
          spreadRadius: -6,
          offset: const Offset(0, 14),
        ),
      ];

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
