import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/enums/app_enums.dart' show AvatarKindX;
import '../../core/models/outfit.dart';
import '../../core/providers/outfits_provider.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_toast.dart';
import 'wardrobe_action_sheet.dart';

String _formatDate(DateTime d) {
  const List<String> months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

class OutfitCard extends ConsumerWidget {
  const OutfitCard({super.key, required this.outfit});

  final Outfit outfit;

  Future<void> _showContextMenu(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    final WardrobeAction? action = await showModalBottomSheet<WardrobeAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => WardrobeActionSheet(
        title: outfit.name,
        actions: const <WardrobeAction>[
          WardrobeAction.tryOn,
          WardrobeAction.rename,
          WardrobeAction.delete,
        ],
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case WardrobeAction.seeOnMe:
        break;
      case WardrobeAction.tryOn:
        context.pushNamed(AppRoute.tryOn.name, extra: outfit);
      case WardrobeAction.rename:
        final TextEditingController ctrl = TextEditingController(text: outfit.name);
        final String? newName = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Rename Outfit'),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              maxLength: 100,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Outfit name'),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final String n = ctrl.text.trim();
                  if (n.isNotEmpty) Navigator.of(ctx).pop(n);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
        if (newName == null || !context.mounted) return;
        try {
          await ref.read(outfitsProvider.notifier).rename(outfit.id, newName);
          if (!context.mounted) return;
          AppToast.success(context, 'Renamed to "$newName"');
        } catch (_) {
          if (!context.mounted) return;
          AppToast.error(context, 'Failed to rename outfit');
        }
      case WardrobeAction.edit:
        break;
      case WardrobeAction.delete:
        final bool? confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Delete ${outfit.name}?'),
            content: const Text('This action cannot be undone.'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: context.colors.error),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirm != true || !context.mounted) return;
        HapticFeedback.heavyImpact();
        try {
          await ref.read(outfitsProvider.notifier).delete(outfit.id);
          if (!context.mounted) return;
          AppToast.success(context, '${outfit.name} deleted');
        } catch (_) {
          if (!context.mounted) return;
          AppToast.error(context, 'Failed to delete ${outfit.name}');
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final BorderRadius radius = BorderRadius.circular(AppRadius.card);
    final Color accent = AvatarKindX.accentForKind(outfit.avatarKind, fallback: c.primary);

    return Material(
      color: c.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: () => context.pushNamed(AppRoute.tryOn.name, extra: outfit),
        onLongPress: () => _showContextMenu(context, ref),
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              accent.withValues(alpha: 0.22),
                              accent.withValues(alpha: 0.06),
                            ],
                          ),
                        ),
                        child: Center(child: Icon(Icons.person, size: 80, color: accent)),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ref.read(outfitsProvider.notifier).toggleStar(outfit.id);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.25),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              outfit.isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                              size: 18,
                              color: outfit.isStarred ? Colors.amber : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        outfit.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(outfit.createdAt),
                        style: text.bodySmall?.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
