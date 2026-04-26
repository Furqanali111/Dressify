import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/mock/mock_data.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/primary_button.dart';

class AvatarSelectionScreen extends StatefulWidget {
  const AvatarSelectionScreen({super.key, this.gender});

  final String? gender;

  @override
  State<AvatarSelectionScreen> createState() => _AvatarSelectionScreenState();
}

class _AvatarSelectionScreenState extends State<AvatarSelectionScreen> {
  AvatarKind? _selected;

  void _handleContinue() {
    // TODO(api): persist selected avatar + go to home.
    context.goNamed(AppRoute.home.name);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.xl,
                0,
              ),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text('Choose Your Avatar', style: text.headlineMedium),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Pick the avatar closest to your body shape',
                  style: text.bodyMedium?.copyWith(color: c.textSecondary),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Expanded(
              child: Builder(
                builder: (context) {
                  List<AvatarKind> availableAvatars = AvatarKind.values.toList();
                  
                  if (widget.gender == 'Female') {
                    availableAvatars = availableAvatars
                        .where((a) => a.name.startsWith('female'))
                        .toList();
                  } else if (widget.gender == 'Male') {
                    availableAvatars = availableAvatars
                        .where((a) => a.name.startsWith('male'))
                        .toList();
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                    scrollDirection: Axis.horizontal,
                    itemCount: availableAvatars.length,
                    separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.lg),
                    itemBuilder: (_, int i) {
                      final AvatarKind kind = availableAvatars[i];
                      return _AvatarCard(
                        kind: kind,
                        selected: _selected == kind,
                        onTap: () => setState(() => _selected = kind),
                      );
                    },
                  );
                }
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: PrimaryButton(
                label: 'Use This Avatar',
                onPressed: _selected == null ? null : _handleContinue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarCard extends StatelessWidget {
  const _AvatarCard({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final AvatarKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final BorderRadius radius = BorderRadius.circular(AppRadius.card);

    final Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: 140,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: radius,
        border: Border.all(
          color: selected ? c.primary : Colors.transparent,
          width: 2.5,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: <Widget>[
            Column(
              children: <Widget>[
                Expanded(
                  child: _AvatarIllustration(kind: kind),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  child: Text(
                    kind.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (selected)
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: c.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 16),
                ),
              ),
          ],
        ),
      ),
    );

    final Widget tappable = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: card,
      ),
    );

    return SizedBox(
      width: 140,
      height: 240,
      child: selected
          ? tappable
              .animate(target: 1)
              .scaleXY(begin: 1, end: 1.04, duration: 180.ms, curve: Curves.easeOut)
          : tappable,
    );
  }
}

class _AvatarIllustration extends StatelessWidget {
  const _AvatarIllustration({required this.kind});

  final AvatarKind kind;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            kind.accent.withValues(alpha: 0.18),
            kind.accent.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Center(
        child: Image.asset(
          kind.assetPath,
          height: 160,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
