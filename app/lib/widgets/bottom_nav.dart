import 'dart:io' show Platform;
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons, CupertinoTabBar;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_colors.dart';
import '../features/chat/providers/chat_provider.dart';

/// 메인 5탭 (홈/지도/모임/채팅/마이).
/// iOS 26+ Liquid Glass native tab bar, iOS<26 CupertinoTabBar, Android Material3 NavigationBar.
class MainScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({super.key, required this.navigationShell});

  void _onTap(int index) {
    debugPrint('[BottomNav] tap index=$index '
        'before currentIndex=${navigationShell.currentIndex}');
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
    debugPrint('[BottomNav] after goBranch '
        'currentIndex=${navigationShell.currentIndex}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = navigationShell.currentIndex;
    // 모든 방의 안 읽은 메시지 총합 → 채팅 탭 빨간 배지.
    final unread = ref.watch(totalUnreadProvider);

    return AdaptiveScaffold(
      minimizeBehavior: TabBarMinimizeBehavior.never,
      body: navigationShell,
      bottomNavigationBar: AdaptiveBottomNavigationBar(
        useNativeBottomBar: true,
        selectedIndex: selectedIndex,
        onTap: _onTap,
        cupertinoTabBar: Platform.isIOS
            ? CupertinoTabBar(
                currentIndex: selectedIndex,
                onTap: _onTap,
                backgroundColor: AppColors.surface,
                activeColor: AppColors.primary,
                inactiveColor: AppColors.textSecondary,
                iconSize: 22,
                height: 60,
                items: [
                  const BottomNavigationBarItem(icon: Icon(CupertinoIcons.house_fill), label: '홈'),
                  const BottomNavigationBarItem(icon: Icon(CupertinoIcons.map_fill), label: '지도'),
                  const BottomNavigationBarItem(icon: Icon(CupertinoIcons.person_3_fill), label: '모임'),
                  BottomNavigationBarItem(
                    icon: Badge.count(
                      count: unread,
                      isLabelVisible: unread > 0,
                      child: const Icon(CupertinoIcons.chat_bubble_fill),
                    ),
                    label: '채팅',
                  ),
                  const BottomNavigationBarItem(icon: Icon(CupertinoIcons.person_fill), label: '마이'),
                ],
              )
            : null,
        // iOS 26+ 네이티브 탭바 — 패키지가 badgeCount 를 네이티브 배지로 렌더.
        items: [
          const AdaptiveNavigationDestination(icon: 'house.fill', label: '홈'),
          const AdaptiveNavigationDestination(icon: 'map.fill', label: '지도'),
          const AdaptiveNavigationDestination(icon: 'person.3.fill', label: '모임'),
          AdaptiveNavigationDestination(
            icon: 'bubble.left.fill',
            label: '채팅',
            badgeCount: unread > 0 ? unread : null,
          ),
          const AdaptiveNavigationDestination(icon: 'person.fill', label: '마이'),
        ],
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: _onTap,
            backgroundColor: AppColors.surface,
            indicatorColor: AppColors.primary.withValues(alpha: 0.15),
            height: 64,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary),
                label: '홈',
              ),
              NavigationDestination(
                icon: const Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map_rounded, color: AppColors.primary),
                label: '지도',
              ),
              NavigationDestination(
                icon: const Icon(Icons.groups_outlined),
                selectedIcon: Icon(Icons.groups_rounded, color: AppColors.primary),
                label: '모임',
              ),
              NavigationDestination(
                icon: Badge.count(
                  count: unread,
                  isLabelVisible: unread > 0,
                  child: const Icon(Icons.chat_bubble_outline_rounded),
                ),
                selectedIcon: Badge.count(
                  count: unread,
                  isLabelVisible: unread > 0,
                  child: Icon(Icons.chat_bubble_rounded, color: AppColors.primary),
                ),
                label: '채팅',
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded, color: AppColors.primary),
                label: '마이',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
