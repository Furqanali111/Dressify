import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/outfit.dart';
import '../../core/providers/outfits_provider.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/primary_button.dart';
import '../wardrobe/style_me_sheet.dart';
import 'notifications_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    HapticFeedback.lightImpact();
    await ref.read(outfitsProvider.notifier).fetch();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xxxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _TopBar(),
              const SizedBox(height: AppSpacing.xl),
              _QuickActions(),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: <Widget>[
                  Text('Recent Outfits', style: text.titleLarge),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.pushNamed(AppRoute.wardrobe.name),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(48, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'See All',
                      style: text.labelLarge?.copyWith(color: c.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _RecentOutfits(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return Row(
      children: <Widget>[
        GestureDetector(
          onTap: () => context.pushNamed(AppRoute.wardrobe.name),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.checkroom, color: c.primary, size: 20),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Hello, there 👋',
                style: text.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Ready to try something new?',
                style: text.bodySmall?.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.notifications_none_rounded,
            color: c.textPrimary,
            size: 26,
          ),
          onPressed: () {
            showModalBottomSheet<void>(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => const NotificationsSheet(),
            );
          },
        ),
        const SizedBox(width: AppSpacing.xs),
        GestureDetector(
          onTap: () => context.goNamed(AppRoute.profile.name),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.primary.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person, color: c.primary, size: 22),
          ),
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final List<_QuickAction> actions = <_QuickAction>[
      _QuickAction(
        icon: Icons.add_a_photo_outlined,
        label: 'New Outfit',
        onTap: () => context.pushNamed(AppRoute.upload.name),
      ),
      _QuickAction(
        icon: Icons.checkroom,
        label: 'My Wardrobe',
        onTap: () => context.pushNamed(AppRoute.wardrobe.name),
      ),
      _QuickAction(
        icon: Icons.bookmark_outline,
        label: 'Saved Looks',
        onTap: () => context.pushNamed(AppRoute.wardrobe.name),
      ),
      _QuickAction(
        icon: Icons.auto_awesome_outlined,
        label: 'Style Tips',
        onTap: () {
          showModalBottomSheet<void>(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => const StyleMeSheet(),
          );
        },
      ),
    ];

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: _QuickActionTile(action: actions[0])),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _QuickActionTile(action: actions[1])),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Expanded(child: _QuickActionTile(action: actions[2])),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _QuickActionTile(action: actions[3])),
          ],
        ),
      ],
    );
  }
}

class _QuickAction {
  _QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final BorderRadius radius = BorderRadius.circular(AppRadius.card);

    return Material(
      color: c.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: radius,
        child: AspectRatio(
          aspectRatio: 2.1,
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
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(action.icon, color: c.primary, size: 28),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    action.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recent Outfits
// ---------------------------------------------------------------------------

class _RecentOutfits extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Outfit>> state = ref.watch(outfitsProvider);

    return state.when(
      loading: () => const _OutfitsLoading(),
      error: (_, _) => const _OutfitsEmpty(isError: true),
      data: (List<Outfit> outfits) {
        if (outfits.isEmpty) return const _OutfitsEmpty(isError: false);
        final List<Outfit> recent = outfits.length > 3 ? outfits.sublist(0, 3) : outfits;
        return SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recent.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (_, int i) => _OutfitCard(outfit: recent[i]),
          ),
        );
      },
    );
  }
}

class _OutfitCard extends StatelessWidget {
  const _OutfitCard({required this.outfit});

  final Outfit outfit;

  Color _accentColor(BuildContext context) {
    final AppColors c = context.colors;
    switch (outfit.avatarKind) {
      case 'femaleSlim':
      case 'maleSlim':
        return const Color(0xFF7C3AED);
      case 'femaleAthletic':
      case 'maleAthletic':
        return const Color(0xFF2563EB);
      case 'femaleAverage':
      case 'maleAverage':
        return const Color(0xFF059669);
      case 'femaleCurvy':
      case 'maleCurvy':
        return const Color(0xFFD97706);
      case 'femalePlus':
      case 'malePlus':
        return const Color(0xFFDB2777);
      default:
        return c.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final Color accent = _accentColor(context);

    return GestureDetector(
      onTap: () => context.pushNamed(AppRoute.tryOn.name, extra: outfit),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border(left: BorderSide(color: accent, width: 3)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Icon(Icons.checkroom, color: accent, size: 28),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  outfit.name,
                  style: text.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${outfit.items.length} item${outfit.items.length == 1 ? '' : 's'}',
                  style: text.bodySmall?.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OutfitsLoading extends StatelessWidget {
  const _OutfitsLoading();

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (_, _) => Container(
          width: 160,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
        ),
      ),
    );
  }
}

class _OutfitsEmpty extends StatelessWidget {
  const _OutfitsEmpty({required this.isError});

  final bool isError;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            isError ? Icons.cloud_off_outlined : Icons.checkroom_outlined,
            size: 40,
            color: c.textSecondary,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            isError
                ? 'Could not load outfits. Pull down to retry.'
                : 'No outfits yet. Upload your first clothing item!',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: c.textSecondary),
          ),
          if (!isError) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: 200,
              child: PrimaryButton(
                label: 'Get Started',
                onPressed: () => context.pushNamed(AppRoute.upload.name),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
