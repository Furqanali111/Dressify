import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/profile.dart';
import '../../core/models/style_profile.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/style_profile_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/units_provider.dart';
import '../../core/api/api_client.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_toast.dart';
import 'measurements_sheet.dart';
import 'style_dna_sheet.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showLegalSheet(BuildContext context, {required bool isPrivacy}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LegalSheet(isPrivacy: isPrivacy),
    );
  }

  void _showThemeSheet(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(themeModeProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final c = ctx.colors;
        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.sheetTop)),
          ),
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxxxl),
          child: Consumer(builder: (ctx, ref, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: AppSpacing.lg),
              Text('App Theme', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.md),
              for (final entry in [
                (ThemeMode.system, 'System default', Icons.brightness_auto_outlined),
                (ThemeMode.light, 'Light', Icons.light_mode_outlined),
                (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
              ])
                ListTile(
                  leading: Icon(entry.$3, color: c.primary),
                  title: Text(entry.$2),
                  trailing: ref.watch(themeModeProvider) == entry.$1
                      ? Icon(Icons.check_rounded, color: c.primary)
                      : null,
                  onTap: () { notifier.setMode(entry.$1); Navigator.of(ctx).pop(); },
                ),
            ],
          )),
        );
      },
    );
  }

  void _showUnitsSheet(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(unitsProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final c = ctx.colors;
        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.sheetTop)),
          ),
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxxxl),
          child: Consumer(builder: (ctx, ref, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: AppSpacing.lg),
              Text('Measurement Units', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.md),
              for (final entry in [
                (MeasurementUnit.metric,   'Metric (cm, kg)',   Icons.straighten),
                (MeasurementUnit.imperial, 'Imperial (ft, lbs)', Icons.square_foot),
              ])
                ListTile(
                  leading: Icon(entry.$3, color: c.primary),
                  title: Text(entry.$2),
                  trailing: ref.watch(unitsProvider) == entry.$1
                      ? Icon(Icons.check_rounded, color: c.primary)
                      : null,
                  onTap: () { notifier.setUnit(entry.$1); Navigator.of(ctx).pop(); },
                ),
            ],
          )),
        );
      },
    );
  }

  void _showNotificationsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final c = ctx.colors;
        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.sheetTop)),
          ),
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: AppSpacing.lg),
              Text('Notifications', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.sm),
              Text('Push notifications are coming in a future update.',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: c.textSecondary)),
            ],
          ),
        );
      },
    );
  }

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

  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: const Text('Delete account?'),
        content: const Text(
          'This will permanently delete your account, all outfits, wardrobe items, and images. '
          'This action cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: ctx.colors.error),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      HapticFeedback.heavyImpact();
      try {
        final dio = ref.read(apiClientProvider);
        await dio.delete<void>('/users/me');
        if (!context.mounted) return;
        await ref.read(authStateProvider.notifier).signOut();
        if (!context.mounted) return;
        AppToast.info(context, 'Account deleted');
        context.goNamed(AppRoute.signIn.name);
      } catch (_) {
        if (!context.mounted) return;
        AppToast.error(context, 'Could not delete account. Please try again.');
      }
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
          const SizedBox(height: AppSpacing.md),
          const _MeasurementsCard(),
          const SizedBox(height: AppSpacing.md),
          const _StyleDnaCard(),
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
                trailing: ref.watch(unitsProvider.notifier).label,
                onTap: () => _showUnitsSheet(context, ref),
              ),
              _SettingsRow(
                icon: Icons.notifications_none,
                label: 'Notifications',
                trailing: 'On',
                onTap: () => _showNotificationsSheet(context),
              ),
              _SettingsRow(
                icon: Icons.dark_mode_outlined,
                label: 'Theme',
                trailing: ref.watch(themeModeProvider.notifier).label,
                onTap: () => _showThemeSheet(context, ref),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _SettingsCard(
            children: <Widget>[
              _SettingsRow(
                icon: Icons.lock_outline,
                label: 'Privacy Policy',
                onTap: () => _showLegalSheet(context, isPrivacy: true),
              ),
              _SettingsRow(
                icon: Icons.description_outlined,
                label: 'Terms of Service',
                onTap: () => _showLegalSheet(context, isPrivacy: false),
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
          const SizedBox(height: AppSpacing.lg),
          // ── Danger Zone ────────────────────────────────────────────────
          Text(
            'Danger Zone',
            style: text.labelMedium?.copyWith(
              color: c.error,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _SettingsCard(
            children: <Widget>[
              _SettingsRow(
                icon: Icons.delete_forever_outlined,
                label: 'Delete Account',
                destructive: true,
                onTap: () => _confirmDeleteAccount(context, ref),
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
        GestureDetector(
          onTap: () => context.pushNamed(AppRoute.avatarSelection.name),
          child: Stack(
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
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: c.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.background, width: 2),
                  ),
                  child: const Icon(Icons.edit, size: 12, color: Colors.white),
                ),
              ),
            ],
          ),
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
    final MeasurementUnit units = ref.watch(unitsProvider);

    final String heightLabel = units.formatHeight(profile?.heightCm);
    final String weightLabel = units.formatWeight(profile?.weightKg);
    final String bodyLabel = profile?.bodyType?.isNotEmpty == true
        ? _capitalize(profile!.bodyType!)
        : '—';

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
// Body measurements card
// ---------------------------------------------------------------------------

class _MeasurementsCard extends ConsumerWidget {
  const _MeasurementsCard();

  void _openSheet(BuildContext context, Profile? profile) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: context.colors.background,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheetTop),
          ),
        ),
        child: MeasurementsSheet(profile: profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final Profile? profile = ref.watch(profileProvider).value;

    String fmtCm(double? v) => v == null ? '—' : '${v.toStringAsFixed(0)} cm';

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
              Text('Body Measurements', style: text.titleMedium),
              const Spacer(),
              TextButton(
                onPressed: () => _openSheet(context, profile),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(48, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  profile?.hasMeasurements == true ? 'Edit' : 'Add',
                  style: text.labelLarge?.copyWith(color: c.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Scales garments to your proportions in the try-on canvas.',
            style: text.bodySmall?.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(child: _StatPill(label: 'Chest',    value: fmtCm(profile?.chestCm))),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _StatPill(label: 'Waist',    value: fmtCm(profile?.waistCm))),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _StatPill(label: 'Hip',      value: fmtCm(profile?.hipCm))),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _StatPill(label: 'Shoulder', value: fmtCm(profile?.shoulderCm))),
            ],
          ),
          if (profile?.isFitPersonalized == true) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Icon(Icons.check_circle_outline, size: 14, color: c.primary),
                const SizedBox(width: 4),
                Text(
                  'Fit personalised',
                  style: TextStyle(fontSize: 12, color: c.primary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Style DNA card
// ---------------------------------------------------------------------------

class _StyleDnaCard extends ConsumerWidget {
  const _StyleDnaCard();

  void _openSheet(BuildContext context, StyleProfile? profile) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StyleDnaSheet(profile: profile),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final StyleProfile? profile = ref.watch(styleProfileProvider).valueOrNull;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('My Style DNA', style: text.titleMedium),
              const Spacer(),
              TextButton(
                onPressed: () => _openSheet(context, profile),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(48, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  profile?.hasPreferences == true ? 'Edit' : 'Set Up',
                  style: text.labelLarge?.copyWith(color: c.primary),
                ),
              ),
            ],
          ),
          if (profile == null || !profile.hasPreferences)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Add your style preferences to get personalised outfit suggestions.',
                style: text.bodySmall?.copyWith(color: c.textSecondary),
              ),
            )
          else ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            if (profile.likedColors.isNotEmpty)
              _DnaRow(label: 'Colors', items: profile.likedColors, color: c.primary),
            if (profile.likedStyles.isNotEmpty)
              _DnaRow(label: 'Styles', items: profile.likedStyles, color: c.primary),
            if (profile.likedPatterns.isNotEmpty)
              _DnaRow(label: 'Patterns', items: profile.likedPatterns, color: c.primary),
            if (profile.dislikedStyles.isNotEmpty)
              _DnaRow(label: 'Avoid', items: profile.dislikedStyles, color: c.error),
          ],
        ],
      ),
    );
  }
}

class _DnaRow extends StatelessWidget {
  const _DnaRow({required this.label, required this.items, required this.color});
  final String label;
  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 60,
            child: Text(label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.colors.textSecondary)),
          ),
          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: items.map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(s, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
              )).toList(),
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

    final Widget content = Padding(
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
    );

    if (onTap == null) return content;

    return InkWell(
      onTap: onTap,
      child: content,
    );
  }
}

// ---------------------------------------------------------------------------
// Legal sheet (Privacy Policy / Terms of Service)
// ---------------------------------------------------------------------------

class _LegalSheet extends StatelessWidget {
  const _LegalSheet({required this.isPrivacy});
  final bool isPrivacy;

  static const List<(String, String)> _privacy = <(String, String)>[
    (
      'Information We Collect',
      'We collect the clothing photos you upload, measurements and body stats you provide, style preferences, and anonymised usage data to improve the service.',
    ),
    (
      'How We Use Your Data',
      'Your data is used exclusively to power AI outfit recommendations, display your wardrobe, and improve Dressify. We do not use your photos to train external AI models without your explicit consent.',
    ),
    (
      'Data Storage & Security',
      'Your data is stored on encrypted, access-controlled servers. Clothing images are processed and stored securely. We apply industry-standard security measures at every layer.',
    ),
    (
      'Data Sharing',
      'We do not sell your personal data to third parties. We may share anonymised, aggregated statistics (e.g. popular clothing categories) for product research.',
    ),
    (
      'Your Rights',
      'You may request access to, correction of, or deletion of your data at any time by contacting us. Deleting your account removes all associated data within 30 days.',
    ),
    (
      'Contact',
      'Questions about privacy? Email us at support@dressify.app.',
    ),
  ];

  static const List<(String, String)> _terms = <(String, String)>[
    (
      'Acceptance of Terms',
      'By using Dressify you agree to these Terms of Service. If you do not agree, please do not use the app.',
    ),
    (
      'Your Account',
      'You are responsible for maintaining the confidentiality of your credentials and for all activity that occurs under your account.',
    ),
    (
      'Your Content',
      'You retain ownership of all photos and content you upload. By uploading, you grant Dressify a limited licence to process and display your content within the app solely to provide the service.',
    ),
    (
      'Prohibited Uses',
      'You may not upload illegal, offensive, or infringing content. You may not attempt to reverse-engineer, scrape, or abuse the service.',
    ),
    (
      'Limitation of Liability',
      'Dressify is provided "as is" without warranties of any kind. We are not liable for indirect or consequential damages arising from your use of the app.',
    ),
    (
      'Contact',
      'Questions about these terms? Email us at support@dressify.app.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final String title = isPrivacy ? 'Privacy Policy' : 'Terms of Service';
    final List<(String, String)> sections = isPrivacy ? _privacy : _terms;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheetTop),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.md, AppSpacing.md, 0,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.md,
            ),
            child: Text(title, style: text.titleLarge),
          ),
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xxxxl,
              ),
              itemCount: sections.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.lg),
              itemBuilder: (_, int i) {
                final (String heading, String body) = sections[i];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      heading,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      body,
                      style: text.bodyMedium?.copyWith(
                        color: c.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
