import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/primary_button.dart';

const String onboardingSeenKey = 'onboarding_seen_v1';

class _Slide {
  const _Slide({
    required this.icon,
    required this.title,
    required this.body,
    required this.tint,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color tint;
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  static const List<_Slide> _slides = <_Slide>[
    _Slide(
      icon: Icons.add_a_photo_outlined,
      title: 'Upload any clothing',
      body: 'Snap a photo or pick from your gallery. We handle the rest.',
      tint: Color(0xFF8E85FF),
    ),
    _Slide(
      icon: Icons.person_outline,
      title: 'See it on you instantly',
      body: 'Our AI fits the clothing onto your avatar in seconds.',
      tint: Color(0xFF63B4FF),
    ),
    _Slide(
      icon: Icons.auto_awesome_outlined,
      title: 'Get AI styling advice',
      body: 'Personal tips on color, balance, and occasion fit.',
      tint: Color(0xFFFF8FA3),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _markSeen() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(onboardingSeenKey, true);
  }

  Future<void> _next() async {
    HapticFeedback.lightImpact();
    if (_index == _slides.length - 1) {
      await _finish();
      return;
    }
    await _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish() async {
    await _markSeen();
    if (!mounted) return;
    context.goNamed(AppRoute.signIn.name);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final bool isLast = _index == _slides.length - 1;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.xl,
                0,
              ),
              child: Row(
                children: <Widget>[
                  const Spacer(),
                  if (!isLast)
                    TextButton(
                      onPressed: _finish,
                      child: Text(
                        'Skip',
                        style: text.labelLarge?.copyWith(color: c.textSecondary),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (int i) => setState(() => _index = i),
                itemCount: _slides.length,
                itemBuilder: (_, int i) => _SlideView(slide: _slides[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  for (int i = 0; i < _slides.length; i++) ...<Widget>[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: i == _index ? 22 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i == _index ? c.primary : c.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              child: PrimaryButton(
                label: isLast ? 'Get Started' : 'Next',
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  slide.tint.withValues(alpha: 0.30),
                  slide.tint.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Icon(slide.icon, size: 96, color: slide.tint),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(slide.title, style: text.displayMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          Text(
            slide.body,
            style: text.bodyLarge?.copyWith(color: c.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
