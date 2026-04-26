import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/mock/mock_data.dart' show ClothingType, ClothingTypeX;
import '../../core/models/clothing_item.dart';
import '../../core/models/outfit.dart';
import '../../core/providers/outfits_provider.dart';
import '../../core/providers/wardrobe_provider.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_toast.dart';
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

class _ClothingTab extends ConsumerWidget {
  const _ClothingTab({required this.filter});

  final ClothingType? filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        final List<ClothingItem> items = filter == null
            ? all
            : all.where((ClothingItem it) => it.type == filter!.name).toList();

        if (items.isEmpty) {
          return const _ScrollableState(
            child: _Empty(
              imageAsset: 'assets/images/03_empty_wardrobe.png',
              title: 'No clothing items yet',
              subtitle: 'Upload your first item from the + button',
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
            childAspectRatio: 0.85,
          ),
          itemCount: items.length,
          itemBuilder: (_, int i) => _ClothingCard(item: items[i]),
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
    final _ItemAction? action = await showModalBottomSheet<_ItemAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemActionSheet(title: item.name),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _ItemAction.tryOn:
        context.pushNamed(AppRoute.tryOn.name);
      case _ItemAction.delete:
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
    final ClothingType uiType = _typeFromString(item.type);

    final Widget card = Material(
      color: c.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: isProcessing ? null : () => context.pushNamed(AppRoute.tryOn.name),
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
                    child: _ClothingImage(item: item, fallbackType: uiType),
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
                        isProcessing ? 'Analyzing with AI…' : uiType.label,
                        style: text.bodySmall?.copyWith(
                          color: isProcessing ? c.primary : c.textSecondary,
                        ),
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
      builder: (_) => _ItemActionSheet(title: outfit.name),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _ItemAction.tryOn:
        context.pushNamed(AppRoute.tryOn.name);
      case _ItemAction.delete:
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
    final Color accent = _accentForAvatar(outfit.avatarKind, c);

    return Material(
      color: c.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: () => context.pushNamed(AppRoute.tryOn.name),
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

Color _accentForAvatar(String avatarKind, AppColors c) {
  // Map common backend strings (e.g. 'femaleSlim') to a tint. Falls back to
  // the brand primary so an unknown value still renders cleanly.
  switch (avatarKind) {
    case 'femaleSlim':
    case 'maleSlim':
      return const Color(0xFF8E85FF);
    case 'femaleAthletic':
    case 'maleAthletic':
      return const Color(0xFF63B4FF);
    case 'femaleAverage':
    case 'maleAverage':
      return const Color(0xFFFF8FA3);
    case 'femaleCurvy':
    case 'maleCurvy':
      return const Color(0xFFFFB266);
    case 'femalePlus':
    case 'malePlus':
      return const Color(0xFF66D9A8);
    default:
      return c.primary;
  }
}

String _formatDate(DateTime d) {
  const List<String> months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

// ─── Action sheet ───────────────────────────────────────────────────────────

enum _ItemAction { tryOn, delete }

class _ItemActionSheet extends StatelessWidget {
  const _ItemActionSheet({required this.title});

  final String title;

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
            _ActionRow(
              icon: Icons.checkroom,
              label: 'Try On',
              onTap: () => Navigator.of(context).pop(_ItemAction.tryOn),
            ),
            _ActionRow(
              icon: Icons.delete_outline,
              label: 'Delete',
              destructive: true,
              onTap: () => Navigator.of(context).pop(_ItemAction.delete),
            ),
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
