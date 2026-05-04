import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/enums/app_enums.dart' show ClothingType, ClothingTypeX;
import '../../core/models/clothing_item.dart';
import '../../core/providers/camera_garments_provider.dart';
import '../../core/providers/outfits_provider.dart';
import '../../core/providers/wardrobe_provider.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_toast.dart';
import 'edit_clothing_sheet.dart';
import 'wardrobe_action_sheet.dart';

ClothingType clothingTypeFromString(String raw) {
  for (final ClothingType t in ClothingType.values) {
    if (t.name == raw) return t;
  }
  return ClothingType.other;
}

class ClothingCard extends ConsumerWidget {
  const ClothingCard({super.key, required this.item});

  final ClothingItem item;

  Future<void> _showContextMenu(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    final bool isFailed = item.processingStatus == 'failed';
    final WardrobeAction? action = await showModalBottomSheet<WardrobeAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => WardrobeActionSheet(
        title: item.name,
        actions: isFailed
            ? const <WardrobeAction>[WardrobeAction.delete]
            : const <WardrobeAction>[
                WardrobeAction.seeOnMe,
                WardrobeAction.tryOn,
                WardrobeAction.edit,
                WardrobeAction.delete,
              ],
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case WardrobeAction.seeOnMe:
        ref.read(cameraGarmentsProvider.notifier).state = <ClothingItem>[item];
        context.goNamed(AppRoute.camera.name);
      case WardrobeAction.tryOn:
        context.pushNamed(AppRoute.tryOn.name);
      case WardrobeAction.edit:
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => EditClothingSheet(item: item),
        );
      case WardrobeAction.rename:
        break;
      case WardrobeAction.logWear:
        // Log wear for a single item is not directly supported by the unified /wear-logs yet 
        // without an outfit, but we can call it with a single item ID.
        try {
          await ref.read(outfitsProvider.notifier).logWear(clothingItemIds: <String>[item.id]);
          if (!context.mounted) return;
          AppToast.success(context, 'Wear logged for ${item.name}');
        } catch (_) {
          if (!context.mounted) return;
          AppToast.error(context, 'Failed to log wear');
        }
      case WardrobeAction.delete:
        final bool? confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Delete ${item.name}?'),
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
          await ref.read(wardrobeProvider.notifier).delete(item.id);
          if (!context.mounted) return;
          AppToast.success(context, '${item.name} deleted');
        } catch (_) {
          if (!context.mounted) return;
          AppToast.error(context, 'Failed to delete ${item.name}');
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final BorderRadius radius = BorderRadius.circular(AppRadius.card);
    final bool isProcessing = item.processingStatus == 'processing';
    final bool isFailed = item.processingStatus == 'failed';
    final ClothingType uiType = clothingTypeFromString(item.type);

    final String subtitle;
    final Color subtitleColor;
    if (isFailed) {
      subtitle = 'Detection failed — hold to delete';
      subtitleColor = c.error;
    } else if (isProcessing) {
      subtitle = 'Analyzing with AI…';
      subtitleColor = c.primary;
    } else {
      subtitle = uiType.label;
      subtitleColor = c.textSecondary;
    }

    final Widget card = Material(
      color: c.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: (isProcessing || isFailed) ? null : () => _showContextMenu(context, ref),
        onLongPress: isProcessing ? null : () => _showContextMenu(context, ref),
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
                  child: ColoredBox(
                    color: c.background,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        isFailed
                            ? _FailedPlaceholder(c: c)
                            : _ClothingImage(item: item, fallbackType: uiType),
                        if (!isFailed && !isProcessing && item.sizeLabel != null && item.sizeLabel != 'Unknown')
                          Positioned(
                            top: AppSpacing.xs,
                            right: AppSpacing.xs,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.sizeLabel!,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        if (!isFailed && !isProcessing)
                          Positioned(
                            right: AppSpacing.xs,
                            bottom: AppSpacing.xs,
                            child: _SeeOnMeButton(
                              onTap: () {
                                ref.read(cameraGarmentsProvider.notifier).state = <ClothingItem>[item];
                                context.goNamed(AppRoute.camera.name);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: text.bodySmall?.copyWith(color: subtitleColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

    if (isProcessing) {
      return Shimmer.fromColors(
        baseColor: c.surface,
        highlightColor: c.background,
        child: card,
      );
    }

    return card;
  }
}

class _SeeOnMeButton extends StatelessWidget {
  const _SeeOnMeButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 16),
      ),
    );
  }
}

class _FailedPlaceholder extends StatelessWidget {
  const _FailedPlaceholder({required this.c});
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.error_outline, size: 36, color: c.error.withValues(alpha: 0.7)),
          const SizedBox(height: 6),
          Text(
            'Processing\nfailed',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c.error.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClothingImage extends StatelessWidget {
  const _ClothingImage({required this.item, required this.fallbackType});

  final ClothingItem item;
  final ClothingType fallbackType;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;

    if (item.processedUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: item.processedUrl,
        memCacheWidth: 200,
        fit: BoxFit.contain,
        placeholder: (_, _) => _swatch(c, fallbackType),
        errorWidget: (_, _, _) => _swatch(c, fallbackType),
      );
    }
    return _swatch(c, fallbackType);
  }

  Widget _swatch(AppColors c, ClothingType type) {
    return Center(
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: c.primary.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppRadius.thumbnail),
        ),
        child: Icon(type.icon, color: c.primary, size: 28),
      ),
    );
  }
}
