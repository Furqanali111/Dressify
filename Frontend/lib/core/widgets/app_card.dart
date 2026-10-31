import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final BorderRadius radius = BorderRadius.circular(AppRadius.card);

    // Double-bezel: hairline outer tray + inner core with concentric radii.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.border.withValues(alpha: 0.35),
        borderRadius: radius,
        boxShadow: c.softShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Material(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.card - 5),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
