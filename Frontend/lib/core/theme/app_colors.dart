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

  // Editorial "ink & bone": warm paper neutrals, ink-black primary in light,
  // electric lime primary in dark. Coral/lime accent via [AppColorsX.accent].
  static const AppColors light = AppColors(
    primary: Color(0xFF16120F),
    primaryDark: Color(0xFF3A332C),
    surface: Color(0xFFFFFFFF),
    background: Color(0xFFF6F3EE),
    textPrimary: Color(0xFF16120F),
    textSecondary: Color(0xFF675F55),
    success: Color(0xFF14804A),
    error: Color(0xFFC8321F),
    overlay: Color(0x8C000000),
    border: Color(0xFFE4DED5),
  );

  static const AppColors dark = AppColors(
    primary: Color(0xFFD2FF45),
    primaryDark: Color(0xFFB4E02E),
    surface: Color(0xFF1B1917),
    background: Color(0xFF0F0E0D),
    textPrimary: Color(0xFFF5F1EA),
    textSecondary: Color(0xFFA59D91),
    success: Color(0xFF4ADE80),
    error: Color(0xFFFF7A6B),
    overlay: Color(0x8C000000),
    border: Color(0xFF2E2B27),
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

extension AppColorsDerived on AppColors {
  bool get isDark => background.computeLuminance() < 0.5;

  /// Readable foreground for content drawn on [primary].
  Color get onPrimary => primary.computeLuminance() > 0.5 ? const Color(0xFF16120F) : Colors.white;

  /// Pop colour for small highlights (nav dot, badges): coral on light, lime on dark.
  Color get accent => isDark ? primary : const Color(0xFFFF5A36);

  /// Soft shadow that works on both themes.
  List<BoxShadow> get softShadow => <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.07),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];
}
