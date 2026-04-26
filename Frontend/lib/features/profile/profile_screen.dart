import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/profile.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_toast.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: const Text('Sign out of Dressify?'),
        content: const Text('Your saved outfits will remain.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: ctx.colors.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      HapticFeedback.mediumImpact();
      await ref.read(authStateProvider.notifier).signOut();
      if (!context.mounted) return;
      AppToast.info(context, 'Signed out');
      context.goNamed(AppRoute.signIn.name);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xxxxl,
        ),
        children: <Widget>[
          _ProfileHeader(onSignOut: () => _confirmSignOut(context, ref)),
          const SizedBox(height: AppSpacing.xl),
          const _BodyStatsCard(),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Settings',
            style: text.labelMedium?.copyWith(
              color: c.textSecondary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _SettingsCard(
            children: <Widget>[
              _SettingsRow(
                icon: Icons.straighten,
                label: 'Units',
                trailing: 'Metric',
                onTap: () {},
              ),
              _SettingsRow(
                icon: Icons.notifications_none,
                label: 'Notifications',
                trailing: 'On',
                onTap: () {},
              ),
              _SettingsRow(
                icon: Icons.dark_mode_outlined,
                label: 'Theme',
                trailing: 'System',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _SettingsCard(
            children: <Widget>[
              _SettingsRow(
                icon: Icons.lock_outline,
                label: 'Privacy Policy',
                onTap: () {},
              ),
              _SettingsRow(
                icon: Icons.description_outlined,
                label: 'Terms of Service',
                onTap: () {},
              ),
              const _SettingsRow(
                icon: Icons.info_outline,
                label: 'App Version',
                trailing: '0.1.0',
                onTap: null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _SettingsCard(
            children: <Widget>[
              _SettingsRow(
                icon: Icons.logout,
                label: 'Sign Out',
                destructive: true,
                onTap: () => _confirmSignOut(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile header — shows real user name from authStateProvider
// ---------------------------------------------------------------------------

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final user = ref.watch(authStateProvider);

    final String displayName = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : user?.email ?? 'Your Account';

    return Row(
      children: <Widget>[
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: c.primary.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.person, color: c.primary, size: 40),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                displayName,
                style: text.headlineMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: () => context.pushNamed(AppRoute.profileSetup.name),
                child: Text(
                  'Edit Profile',
                  style: text.labelLarge?.copyWith(color: c.primary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Body stats — shows real data from profileProvider
// ---------------------------------------------------------------------------

class _BodyStatsCard extends ConsumerWidget {
  const _BodyStatsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final AsyncValue<Profile?> profileState = ref.watch(profileProvider);

    final Profile? profile = profileState.valueOrNull;

    String heightLabel = '—';
    String weightLabel = '—';
    String bodyLabel = '—';

    if (profile != null) {
      if (profile.heightCm != null) {
        heightLabel = '${profile.heightCm!.toStringAsFixed(0)} cm';
      }
      if (profile.weightKg != null) {
        weightLabel = '${profile.weightKg!.toStringAsFixed(0)} kg';
      }
      if (profile.bodyType != null && profile.bodyType!.isNotEmpty) {
        bodyLabel = _capitalize(profile.bodyType!);
      }
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('Body Stats', style: text.titleMedium),
              const Spacer(),
              TextButton(
                onPressed: () => context.pushNamed(AppRoute.profileSetup.name),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(48, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  profile == null ? 'Set Up' : 'Edit',
                  style: text.labelLarge?.copyWith(color: c.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          profileState.isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Row(
                  children: <Widget>[
                    Expanded(child: _StatPill(label: 'Height', value: heightLabel)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: _StatPill(label: 'Weight', value: weightLabel)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: _StatPill(label: 'Body', value: bodyLabel)),
                  ],
                ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: c.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: c.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings components (unchanged)
// ---------------------------------------------------------------------------

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;

    final List<Widget> withDividers = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      withDividers.add(children[i]);
      if (i != children.length - 1) {
        withDividers.add(Divider(height: 1, thickness: 1, color: c.border));
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: DecoratedBox(
        decoration: BoxDecoration(color: c.surface),
        child: Column(children: withDividers),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String? trailing;
  final bool destructive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final Color textColor = destructive ? c.error : c.textPrimary;
    final Color iconColor = destructive ? c.error : c.textSecondary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: TextStyle(color: c.textSecondary, fontSize: 14),
              ),
            if (onTap != null && !destructive) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right, color: c.textSecondary, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}
