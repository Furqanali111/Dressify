import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_flags.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/router/app_routes.dart';
import '../../core/utils/app_permissions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/motion.dart';
import '../onboarding/onboarding_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1500), _resolveAuthAndRoute);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _resolveAuthAndRoute() async {
    if (!mounted) return;
    if (AppFlags.bypassAuth) {
      context.goNamed(AppRoute.profileSetup.name);
      return;
    }
    
    final bool loggedIn = await ref.read(authStateProvider.notifier).init();
    if (!mounted) return;

    if (loggedIn) {
      // Eagerly fetch profile so it's ready in global state
      await ref.read(profileProvider.notifier).fetchProfile();
      if (!mounted) return;
      // Request permissions before navigating so context is still valid
      await AppPermissions.requestStartupPermissions(context);
      if (!mounted) return;
      context.goNamed(AppRoute.home.name);
      return;
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool seenOnboarding = prefs.getBool(onboardingSeenKey) ?? false;
    if (!mounted) return;
    context.goNamed(
      seenOnboarding ? AppRoute.signIn.name : AppRoute.onboarding.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[c.primary, const Color(0xFFC4B5FD)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: <Widget>[
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Dressify',
                      style: text.displayLarge?.copyWith(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                      ),
                    ).animate().fadeIn(duration: context.motion(400.ms)).scale(
                          begin: const Offset(0.96, 0.96),
                          end: const Offset(1, 1),
                          duration: context.motion(400.ms),
                          curve: Curves.easeOut,
                        ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Your wardrobe. Reimagined.',
                      style: text.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ).animate().fadeIn(delay: context.motion(200.ms), duration: context.motion(400.ms)),
                    const SizedBox(height: AppSpacing.xxxl),
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              if (AppFlags.bypassAuth)
                const Positioned(
                  top: AppSpacing.lg,
                  right: AppSpacing.lg,
                  child: _DevBadge(label: 'AUTH BYPASSED'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DevBadge extends StatelessWidget {
  const _DevBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
