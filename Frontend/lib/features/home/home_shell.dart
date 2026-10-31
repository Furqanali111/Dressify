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
        child: Container(
          height: 68,
          margin: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(34),
            border: Border.all(color: c.border),
            boxShadow: c.softShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(34),
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
    final Color color = active ? c.textPrimary : c.textSecondary;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(active ? tab.activeIcon : tab.icon, color: color, size: 24),
          const SizedBox(height: AppSpacing.xs),
          Text(
            tab.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: active ? 4 : 0,
            height: 4,
            decoration: BoxDecoration(
              color: c.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
