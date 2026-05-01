import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/enums/app_enums.dart' show ClothingType, ClothingTypeX;
import '../../core/models/clothing_item.dart';
import '../../core/models/outfit.dart';
import '../../core/providers/outfits_provider.dart';
import '../../core/providers/wardrobe_provider.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_chip.dart';
import 'clothing_card.dart';
import 'outfit_card.dart';
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
            return ClothingCard(item: items[i]);
          },
        );
      },
    );
  }
}

class _OutfitsTab extends ConsumerStatefulWidget {
  const _OutfitsTab();

  @override
  ConsumerState<_OutfitsTab> createState() => _OutfitsTabState();
}

class _OutfitsTabState extends ConsumerState<_OutfitsTab> {
  bool _starredOnly = false;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
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

        final List<Outfit> filtered =
            _starredOnly ? outfits.where((o) => o.isStarred).toList() : outfits;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.md, AppSpacing.xl, 0),
              child: FilterChip(
                label: const Text('Starred'),
                avatar: Icon(
                  _starredOnly ? Icons.star : Icons.star_border,
                  size: 16,
                  color: _starredOnly ? Colors.white : c.primary,
                ),
                selected: _starredOnly,
                onSelected: (v) => setState(() => _starredOnly = v),
                selectedColor: c.primary,
                labelStyle: TextStyle(
                  color: _starredOnly ? Colors.white : c.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                checkmarkColor: Colors.white,
                showCheckmark: false,
              ),
            ),
            if (_starredOnly && filtered.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.star_border_rounded,
                          size: 48, color: c.textSecondary.withValues(alpha: 0.4)),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'No starred outfits yet',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: c.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Tap the ★ on any outfit to star it',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.md,
                    AppSpacing.xl,
                    AppSpacing.xxxxl + AppSpacing.lg,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (_, int i) => OutfitCard(outfit: filtered[i]),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─── Shared state widgets ────────────────────────────────────────────────────

class _ScrollableState extends StatelessWidget {
  const _ScrollableState({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: child,
        ),
      ],
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Image.asset(imageAsset, width: 160, height: 160),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: text.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: text.bodySmall?.copyWith(color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.wifi_off_rounded, size: 48, color: c.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
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

    return Shimmer.fromColors(
      baseColor: c.surface,
      highlightColor: c.background,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xxxxl,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: aspectRatio,
        ),
        itemCount: 6,
        itemBuilder: (_, _) => DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
        ),
      ),
    );
  }
}
