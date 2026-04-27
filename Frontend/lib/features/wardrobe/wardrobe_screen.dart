import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/enums/app_enums.dart' show AvatarKindX, ClothingType, ClothingTypeX;
import '../../core/models/clothing_item.dart';
import '../../core/models/outfit.dart';
import '../../core/providers/camera_garments_provider.dart';
import '../../core/providers/outfits_provider.dart';
import '../../core/providers/wardrobe_provider.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/primary_button.dart';
import 'style_me_sheet.dart';

class WardrobeScreen extends ConsumerStatefulWidget {
  const WardrobeScreen({super.key});

  @override
  ConsumerState<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends ConsumerState<WardrobeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  ClothingType? _filter; // null = "All"

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    HapticFeedback.lightImpact();
    await Future.wait<void>(<Future<void>>[
      ref.read(wardrobeProvider.notifier).fetch(),
      ref.read(outfitsProvider.notifier).fetch(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return SafeArea(
      child: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.md,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(child: Text('My Wardrobe', style: text.displayMedium)),
                  ],
                ),
              ),
              TabBar(
                controller: _tabController,
                labelColor: c.primary,
                unselectedLabelColor: c.textSecondary,
                indicatorColor: c.primary,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: text.labelLarge,
                tabs: const <Widget>[
                  Tab(text: 'Clothing Items'),
                  Tab(text: 'Saved Outfits'),
                ],
              ),
              if (_tabController.index == 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.md,
                    AppSpacing.xl,
                    0,
                  ),
                  child: SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: <Widget>[
                        AppChip(
                          label: 'All',
                          selected: _filter == null,
                          onTap: () => setState(() => _filter = null),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        for (final ClothingType t in ClothingType.values) ...<Widget>[
                          AppChip(
                            label: t.label,
                            selected: _filter == t,
                            onTap: () => setState(() => _filter = t),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: <Widget>[
                    RefreshIndicator(
                      onRefresh: _refresh,
                      child: _ClothingTab(filter: _filter),
                    ),
                    RefreshIndicator(
                      onRefresh: _refresh,
                      child: const _OutfitsTab(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                FloatingActionButton.small(
                  heroTag: 'upload',
                  backgroundColor: c.surface,
                  foregroundColor: c.primary,
                  onPressed: () => context.pushNamed(AppRoute.upload.name),
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: AppSpacing.md),
                FloatingActionButton.extended(
                  heroTag: 'style_me',
                  backgroundColor: c.primary,
                  foregroundColor: Colors.white,
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (_) => const StyleMeSheet(),
                    );
                  },
                  icon: Image.asset(
                    'assets/icons/05_icon_magic_wand.png',
                    width: 24,
                    height: 24,
                    color: Colors.white,
                  ),
                  label: const Text('Style Me'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tabs ───────────────────────────────────────────────────────────────────

class _ClothingTab extends ConsumerStatefulWidget {
  const _ClothingTab({required this.filter});

  final ClothingType? filter;

  @override
  ConsumerState<_ClothingTab> createState() => _ClothingTabState();
}

class _ClothingTabState extends ConsumerState<_ClothingTab> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      ref.read(wardrobeProvider.notifier).fetchMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<ClothingItem>> async = ref.watch(wardrobeProvider);

    return async.when(
      loading: () => const _LoadingShimmer(aspectRatio: 0.85),
      error: (Object e, _) => _ScrollableState(
        child: _ErrorState(
          message: 'Could not load your wardrobe',
          onRetry: () => ref.read(wardrobeProvider.notifier).fetch(),
        ),
      ),
      data: (List<ClothingItem> all) {
        final List<ClothingItem> items = widget.filter == null
            ? all
            : all.where((ClothingItem it) => it.type == widget.filter!.name).toList();

        if (items.isEmpty) {
          return const _ScrollableState(
            child: _Empty(
              imageAsset: 'assets/images/03_empty_wardrobe.png',
              title: 'No clothing items yet',
              subtitle: 'Upload your first item from the + button',
            ),
          );
        }

        final bool hasMore = ref.read(wardrobeProvider.notifier).hasMore;

        return GridView.builder(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xxxxl + AppSpacing.lg,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.85,
          ),
          itemCount: items.length + (hasMore ? 1 : 0),
          itemBuilder: (_, int i) {
            if (i == items.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            return _ClothingCard(item: items[i]);
          },
        );
      },
    );
  }
}

class _OutfitsTab extends ConsumerWidget {
  const _OutfitsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Outfit>> async = ref.watch(outfitsProvider);

    return async.when(
      loading: () => const _LoadingShimmer(aspectRatio: 0.7),
      error: (Object e, _) => _ScrollableState(
        child: _ErrorState(
          message: 'Could not load your outfits',
          onRetry: () => ref.read(outfitsProvider.notifier).fetch(),
        ),
      ),
      data: (List<Outfit> outfits) {
        if (outfits.isEmpty) {
          return const _ScrollableState(
            child: _Empty(
              imageAsset: 'assets/images/04_no_outfits.png',
              title: 'No saved outfits yet',
              subtitle: 'Try on something and save the look',
            ),
          );
        }

        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xxxxl + AppSpacing.lg,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.7,
          ),
          itemCount: outfits.length,
          itemBuilder: (_, int i) => _OutfitCard(outfit: outfits[i]),
        );
      },
    );
  }
}

// ─── Cards ──────────────────────────────────────────────────────────────────

class _ClothingCard extends ConsumerWidget {
  const _ClothingCard({required this.item});

  final ClothingItem item;

  Future<void> _showContextMenu(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    final bool isFailed = item.processingStatus == 'failed';
    final _ItemAction? action = await showModalBottomSheet<_ItemAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemActionSheet(
        title: item.name,
        // Failed items can only be deleted; no Try On or Edit until processing succeeds.
        actions: isFailed
            ? const <_ItemAction>[_ItemAction.delete]
            : const <_ItemAction>[
                _ItemAction.seeOnMe,
                _ItemAction.tryOn,
                _ItemAction.edit,
                _ItemAction.delete,
              ],
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _ItemAction.seeOnMe:
        ref.read(cameraGarmentsProvider.notifier).state = <ClothingItem>[item];
        context.goNamed(AppRoute.camera.name);
      case _ItemAction.tryOn:
        context.pushNamed(AppRoute.tryOn.name);
      case _ItemAction.edit:
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _EditClothingSheet(item: item),
        );
      case _ItemAction.rename:
        break;
      case _ItemAction.delete:
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
    final ClothingType uiType = _typeFromString(item.type);

    // Determine subtitle text + colour
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
        onTap: (isProcessing || isFailed)
            ? null
            : () => context.pushNamed(AppRoute.tryOn.name),
        onLongPress: isProcessing
            ? null
            : () => _showContextMenu(context, ref),
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
                        // "See on Me" quick-access button
                        if (!isFailed && !isProcessing)
                          Positioned(
                            right: AppSpacing.xs,
                            bottom: AppSpacing.xs,
                            child: _SeeOnMeButton(
                              onTap: () {
                                ref
                                    .read(cameraGarmentsProvider.notifier)
                                    .state = <ClothingItem>[item];
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
        memCacheWidth: 200, // 2× card width for HiDPI; avoids caching full 1024 px
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
        child: Icon(
          type.icon,
          color: c.primary,
          size: 28,
        ),
      ),
    );
  }
}

class _OutfitCard extends ConsumerWidget {
  const _OutfitCard({required this.outfit});

  final Outfit outfit;

  Future<void> _showContextMenu(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    final _ItemAction? action = await showModalBottomSheet<_ItemAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemActionSheet(
        title: outfit.name,
        actions: const <_ItemAction>[
          _ItemAction.tryOn,
          _ItemAction.rename,
          _ItemAction.delete,
        ],
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _ItemAction.seeOnMe:
        break; // outfits don't support "See on Me" directly
      case _ItemAction.tryOn:
        context.pushNamed(AppRoute.tryOn.name, extra: outfit);
      case _ItemAction.rename:
        final TextEditingController ctrl =
            TextEditingController(text: outfit.name);
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
        // Defer dispose until after the dialog's exit animation completes,
        // so the TextField's controller isn't accessed during dismissal.
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
      case _ItemAction.edit:
        break;
      case _ItemAction.delete:
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
                  child: DecoratedBox(
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
                    child: Center(
                      child: Icon(Icons.person, size: 80, color: accent),
                    ),
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
                        style:
                            text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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

// ─── States: empty / error / loading ────────────────────────────────────────

/// Wraps the empty/error widget in a scrollable so [RefreshIndicator] can
/// pull it down even when there's nothing to scroll past.
class _ScrollableState extends StatelessWidget {
  const _ScrollableState({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints constraints) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: <Widget>[
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(child: child),
            ),
          ],
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.imageAsset,
    required this.title,
    required this.subtitle,
  });

  final String imageAsset;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Image.asset(
            imageAsset,
            width: 120,
            height: 120,
            opacity: const AlwaysStoppedAnimation<double>(0.7),
            errorBuilder: (_, _, _) => Icon(
              Icons.checkroom_outlined,
              size: 80,
              color: c.textSecondary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: text.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Pull down to refresh',
            style: text.bodySmall?.copyWith(
              color: c.textSecondary.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.cloud_off_outlined, size: 56, color: c.textSecondary),
          const SizedBox(height: AppSpacing.md),
          Text(message, style: text.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Check your connection or pull to retry.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer({required this.aspectRatio});

  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxxxl + AppSpacing.lg,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: aspectRatio,
      ),
      itemCount: 4,
      itemBuilder: (_, _) => Shimmer.fromColors(
        baseColor: c.surface,
        highlightColor: c.background,
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

ClothingType _typeFromString(String raw) {
  for (final ClothingType t in ClothingType.values) {
    if (t.name == raw) return t;
  }
  return ClothingType.other;
}


String _formatDate(DateTime d) {
  const List<String> months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

// ─── Action sheet ───────────────────────────────────────────────────────────

enum _ItemAction { seeOnMe, tryOn, edit, rename, delete }

class _ItemActionSheet extends StatelessWidget {
  const _ItemActionSheet({
    required this.title,
    required this.actions,
  });

  final String title;
  final List<_ItemAction> actions;

  Widget _row(BuildContext context, _ItemAction action) {
    switch (action) {
      case _ItemAction.seeOnMe:
        return _ActionRow(
          icon: Icons.camera_alt_outlined,
          label: 'See on Me',
          onTap: () => Navigator.of(context).pop(action),
        );
      case _ItemAction.tryOn:
        return _ActionRow(
          icon: Icons.checkroom,
          label: 'Try On',
          onTap: () => Navigator.of(context).pop(action),
        );
      case _ItemAction.edit:
        return _ActionRow(
          icon: Icons.edit_outlined,
          label: 'Edit Details',
          onTap: () => Navigator.of(context).pop(action),
        );
      case _ItemAction.rename:
        return _ActionRow(
          icon: Icons.drive_file_rename_outline,
          label: 'Rename',
          onTap: () => Navigator.of(context).pop(action),
        );
      case _ItemAction.delete:
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
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.lg,
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
            Text(
              title,
              style: text.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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

// ─── Edit clothing sheet ─────────────────────────────────────────────────────

class _EditClothingSheet extends ConsumerStatefulWidget {
  const _EditClothingSheet({required this.item});
  final ClothingItem item;

  @override
  ConsumerState<_EditClothingSheet> createState() => _EditClothingSheetState();
}

class _EditClothingSheetState extends ConsumerState<_EditClothingSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _colorCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _colorCtrl = TextEditingController(text: widget.item.color ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(wardrobeProvider.notifier).update(
        widget.item.id,
        <String, dynamic>{
          'name': name,
          if (_colorCtrl.text.trim().isNotEmpty) 'color': _colorCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      AppToast.success(context, 'Updated "$name"');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.error(context, 'Failed to update item');
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheetTop),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Edit Item', style: text.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Item name',
                ),
                textCapitalization: TextCapitalization.words,
                maxLength: 100,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _colorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Color',
                  hintText: 'e.g. Navy Blue',
                ),
                textCapitalization: TextCapitalization.words,
                maxLength: 50,
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: 'Save Changes',
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
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
