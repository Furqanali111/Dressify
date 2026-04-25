import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum ToastVariant { success, error, info }

class AppToast {
  const AppToast._();

  static void show(
    BuildContext context,
    String message, {
    ToastVariant variant = ToastVariant.info,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    final AppColors c = context.colors;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final (IconData icon, Color accent) = switch (variant) {
      ToastVariant.success => (Icons.check_circle_outline, c.success),
      ToastVariant.error => (Icons.error_outline, c.error),
      ToastVariant.info => (Icons.info_outline, c.primary),
    };

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1A1A2E),
          margin: const EdgeInsets.all(AppSpacing.lg),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
          ),
          action: action,
          content: Row(
            children: <Widget>[
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  static void success(BuildContext context, String message) =>
      show(context, message, variant: ToastVariant.success);

  static void error(BuildContext context, String message) =>
      show(context, message, variant: ToastVariant.error);

  static void info(BuildContext context, String message) =>
      show(context, message, variant: ToastVariant.info);
}
