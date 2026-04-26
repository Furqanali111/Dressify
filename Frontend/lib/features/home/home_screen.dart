import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/primary_button.dart';
import '../wardrobe/style_me_sheet.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _refresh() async {
    HapticFeedback.lightImpact();
    // TODO(api): re-fetch user + recent outfits.
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
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
                  onPressed: () => context.goNamed(AppRoute.wardrobe.name),
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
            const _EmptyOutfits(),
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
          onTap: () => context.goNamed(AppRoute.wardrobe.name),
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notifications coming soon!'),
                duration: Duration(seconds: 2),
              ),
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
        onTap: () => context.goNamed(AppRoute.wardrobe.name),
      ),
      _QuickAction(
        icon: Icons.bookmark_outline,
        label: 'Saved Looks',
        onTap: () => context.goNamed(AppRoute.wardrobe.name),
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


class _EmptyOutfits extends StatelessWidget {
  const _EmptyOutfits();

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
          Image.asset(
            'assets/images/04_no_outfits.png',
            width: 64,
            height: 64,
            opacity: const AlwaysStoppedAnimation<double>(0.7),
          ),

          const SizedBox(height: AppSpacing.xs),
          Text(
            'No outfits yet. Upload your first clothing item!',
            style: text.bodyMedium?.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: 200,
            child: PrimaryButton(
              label: 'Get Started',
              onPressed: () => context.pushNamed(AppRoute.upload.name),
            ),
          ),
        ],
      ),
    );
  }
}
