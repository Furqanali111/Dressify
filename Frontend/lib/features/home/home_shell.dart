import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const List<_Tab> _tabs = <_Tab>[
    _Tab(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    _Tab(icon: Icons.camera_alt_outlined, activeIcon: Icons.camera_alt, label: 'Try On'),
    _Tab(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
  ];

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;

    return Scaffold(
      backgroundColor: c.background,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.md),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.surface.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: c.border),
              boxShadow: c.softShadow,
            ),
            child: SizedBox(
              height: 64,
              child: Row(
                children: <Widget>[
                  for (int i = 0; i < _tabs.length; i++)
                    Expanded(
                      child: _NavItem(
                        tab: _tabs[i],
                        active: i == navigationShell.currentIndex,
                        onTap: () => _goBranch(i),
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

class _Tab {
  const _Tab({required this.icon, required this.activeIcon, required this.label});

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.active,
    required this.onTap,
  });

  final _Tab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    const Cubic curve = Cubic(0.32, 0.72, 0, 1);
    final Color color = active ? c.background : c.textSecondary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 450),
          curve: curve,
          height: 48,
          padding: EdgeInsets.symmetric(horizontal: active ? 18 : 12),
          decoration: BoxDecoration(
            color: active ? c.textPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(active ? tab.activeIcon : tab.icon, color: color, size: 22),
              AnimatedSize(
                duration: const Duration(milliseconds: 450),
                curve: curve,
                child: active
                    ? Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.sm),
                        child: Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
