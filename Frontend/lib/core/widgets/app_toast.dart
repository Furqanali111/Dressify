import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum ToastVariant { success, error, info }

/// Threshold above which the error toast adds a "Details" action button
/// that opens an AlertDialog showing the full message.
const int _kDetailThreshold = 80;

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
      ToastVariant.error   => (Icons.error_outline, c.error),
      ToastVariant.info    => (Icons.info_outline, c.primary),
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

  static void info(BuildContext context, String message) =>
      show(context, message, variant: ToastVariant.info);

  /// Shows an error toast.
  ///
  /// If [message] exceeds [_kDetailThreshold] characters, a "Details" action
  /// is automatically added. Tapping it dismisses the snack bar and opens an
  /// AlertDialog with the full, untruncated message.
  static void error(BuildContext context, String message) {
    final bool isLong = message.length > _kDetailThreshold;
    final String displayed = isLong
        ? '${message.substring(0, _kDetailThreshold).trimRight()}…'
        : message;

    SnackBarAction? action;
    if (isLong) {
      action = SnackBarAction(
        label: 'Details',
        textColor: Colors.white70,
        onPressed: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          showDialog<void>(
            context: context,
            builder: (BuildContext ctx) => AlertDialog(
              title: const Text('Error Details'),
              content: SingleChildScrollView(child: Text(message)),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
      );
    }

    show(
      context,
      displayed,
      variant: ToastVariant.error,
      duration: isLong
          ? const Duration(seconds: 6) // extra time to read & tap Details
          : const Duration(seconds: 3),
      action: action,
    );
  }
}
