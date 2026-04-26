import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:shimmer/shimmer.dart';

import '../../core/mock/mock_data.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_toast.dart';
import 'style_me_sheet.dart';

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key});

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen>
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
    // TODO(api): re-fetch wardrobe items + outfits.
    await Future<void>.delayed(const Duration(milliseconds: 600));
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
                      child: _ClothingGrid(filter: _filter),
                    ),
                    RefreshIndicator(
                      onRefresh: _refresh,
                      child: _OutfitsGrid(),
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

class _ClothingGrid extends StatelessWidget {
  const _ClothingGrid({required this.filter});

  final ClothingType? filter;

  @override
  Widget build(BuildContext context) {
    // TODO(api): fetch actual items from backend
    final List<MockClothingItem> items = <MockClothingItem>[];

    if (items.isEmpty) {
      return const _Empty(
        imageAsset: 'assets/images/03_empty_wardrobe.png',
        title: 'No clothing items yet',
        subtitle: 'Upload your first item from the + button',
      );
    }

    return GridView.builder(
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
  }
}

class _ClothingCard extends StatelessWidget {
  const _ClothingCard({required this.item});

  final MockClothingItem item;

  Future<void> _showContextMenu(BuildContext context) async {
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
        // TODO(api): DELETE /clothing/:id.
        AppToast.success(context, '${item.name} deleted');
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final BorderRadius radius = BorderRadius.circular(AppRadius.card);

    final bool isProcessing = item.processingStatus == 'processing';

    final Widget card = Material(
      color: c.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: isProcessing ? null : () => context.pushNamed(AppRoute.tryOn.name),
        onLongPress: isProcessing ? null : () => _showContextMenu(context),
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
                    child: Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: item.swatch,
                          borderRadius: BorderRadius.circular(AppRadius.thumbnail),
                        ),
                        child: Icon(
                          item.type.icon,
                          color: Colors.white.withValues(alpha: 0.8),
                          size: 28,
                        ),
                      ),
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
                        isProcessing ? 'Analyzing with AI...' : item.type.label,
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

class _OutfitsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    // TODO(api): fetch actual outfits from backend
    final List<MockOutfit> outfits = <MockOutfit>[];

    if (outfits.isEmpty) {
      return const _Empty(
        imageAsset: 'assets/images/04_no_outfits.png',
        title: 'No saved outfits yet',
        subtitle: 'Try on something and save the look',
      );
    }

    return GridView.builder(
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
      itemBuilder: (_, int i) {
        final MockOutfit o = outfits[i];
        return Material(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: InkWell(
            onTap: () => context.pushNamed(AppRoute.tryOn.name),
            onLongPress: () async {
              HapticFeedback.mediumImpact();
              final _ItemAction? action = await showModalBottomSheet<_ItemAction>(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (_) => _ItemActionSheet(title: o.name),
              );
              if (action == null || !context.mounted) return;
              switch (action) {
                case _ItemAction.tryOn:
                  context.pushNamed(AppRoute.tryOn.name);
                case _ItemAction.delete:
                  // TODO(api): DELETE /outfits/:id.
                  AppToast.success(context, '${o.name} deleted');
              }
            },
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.card),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: Stack(
                        children: <Widget>[
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  o.avatar.accent.withValues(alpha: 0.22),
                                  o.avatar.accent.withValues(alpha: 0.06),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.person,
                                size: 80,
                                color: o.avatar.accent,
                              ),
                            ),
                          ),
                          if (o.aiRating != null)
                            Positioned(
                              top: AppSpacing.sm,
                              right: AppSpacing.sm,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(AppRadius.chip),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    const Icon(Icons.star,
                                        color: Colors.amber, size: 12),
                                    const SizedBox(width: 3),
                                    Text(
                                      o.aiRating!.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
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
                            o.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(o.savedAt),
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
      },
    );
  }

  String _formatDate(DateTime d) {
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
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
            Image.asset(
              imageAsset,
              width: 64,
              height: 64,
              opacity: const AlwaysStoppedAnimation<double>(0.7),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: text.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

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
