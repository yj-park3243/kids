import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_shadows.dart';
import '../core/constants/app_text_styles.dart';

class MainScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                    width: 0.5,
                  ),
                  boxShadow: AppShadows.tabBar,
                ),
                child: Row(
                  children: [
                    _NavItem(
                      icon: Icons.home_rounded,
                      label: '홈',
                      isSelected: navigationShell.currentIndex == 0,
                      onTap: () => navigationShell.goBranch(0),
                    ),
                    _NavItem(
                      icon: Icons.map_rounded,
                      label: '지도',
                      isSelected: navigationShell.currentIndex == 1,
                      onTap: () => navigationShell.goBranch(1),
                    ),
                    _NavItem(
                      icon: Icons.grid_view_rounded,
                      label: '방목록',
                      isSelected: navigationShell.currentIndex == 2,
                      onTap: () => navigationShell.goBranch(2),
                    ),
                    _NavItem(
                      icon: Icons.chat_bubble_rounded,
                      label: '내방',
                      isSelected: navigationShell.currentIndex == 3,
                      onTap: () => navigationShell.goBranch(3),
                    ),
                    _NavItem(
                      icon: Icons.person_rounded,
                      label: '마이',
                      isSelected: navigationShell.currentIndex == 4,
                      onTap: () => navigationShell.goBranch(4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: isSelected ? AppColors.pinkGradient : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.pink500.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? Colors.white : AppColors.ink500,
                ),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: AppTextStyles.chip.copyWith(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
