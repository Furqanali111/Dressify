import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

enum WardrobeAction { logWear, seeOnMe, tryOn, edit, rename, delete }

class WardrobeActionSheet extends StatelessWidget {
  const WardrobeActionSheet({
    super.key,
    required this.title,
    required this.actions,
  });

  final String title;
  final List<WardrobeAction> actions;

  Widget _row(BuildContext context, WardrobeAction action) {
    switch (action) {
      case WardrobeAction.logWear:
        return _ActionRow(
          icon: Icons.checkroom_outlined,
          label: 'Log Wear',
          onTap: () => Navigator.of(context).pop(action),
        );
      case WardrobeAction.seeOnMe:
        return _ActionRow(
          icon: Icons.camera_alt_outlined,
          label: 'See on Me',
          onTap: () => Navigator.of(context).pop(action),
        );
      case WardrobeAction.tryOn:
        return _ActionRow(
          icon: Icons.checkroom,
          label: 'Try On',
          onTap: () => Navigator.of(context).pop(action),
        );
      case WardrobeAction.edit:
        return _ActionRow(
          icon: Icons.edit_outlined,
          label: 'Edit Details',
          onTap: () => Navigator.of(context).pop(action),
        );
      case WardrobeAction.rename:
        return _ActionRow(
          icon: Icons.drive_file_rename_outline,
          label: 'Rename',
          onTap: () => Navigator.of(context).pop(action),
        );
      case WardrobeAction.delete:
        return _ActionRow(
          icon: Icons.delete_outline,
          label: 'Delete',
          destructive: true,
          onTap: () => Navigator.of(context).pop(action),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheetTop),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.lg,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: AppSpacing.md),
            ...actions.map((a) => _row(context, a)),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final Color color = destructive ? c.error : c.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.lg,
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: color, size: 22),
            const SizedBox(width: AppSpacing.md),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
