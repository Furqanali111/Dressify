import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    this.onPressed,
    this.icon,
    this.fullWidth = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;

    final Widget child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 20, color: c.primary),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: c.primary,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );

    final Widget button = OutlinedButton(
      onPressed: onPressed,
      style: ButtonStyle(
        side: WidgetStatePropertyAll<BorderSide>(BorderSide(color: c.primary, width: 1.5)),
        backgroundColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
          if (states.contains(WidgetState.pressed)) {
            return c.primary.withValues(alpha: 0.08);
          }
          return Colors.transparent;
        }),
        padding: const WidgetStatePropertyAll<EdgeInsets>(
          EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        ),
        minimumSize: const WidgetStatePropertyAll<Size>(Size(0, 52)),
        shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
        ),
      ),
      child: child,
    );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
