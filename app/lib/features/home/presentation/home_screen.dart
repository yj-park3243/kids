import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/user.dart';
import '../../../providers/selected_child_provider.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/home_provider.dart';
import 'widgets/room_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 유저의 아이 정보로 선택된 아이 초기화
      final user = ref.read(authProvider).user;
      if (user != null) {
        ref.read(selectedChildProvider.notifier).initFromUser(user);
      }
      ref.read(homeProvider.notifier).loadRooms(refresh: true);
      ref.read(homeProvider.notifier).loadUnreadCount();
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(homeProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeProvider);
    final authState = ref.watch(authProvider);
    final selectedChild = ref.watch(selectedChildProvider);
    final children = authState.user?.children ?? [];
    final regionDong = authState.user?.regionDong ?? '동네';

    // 선택된 아이가 바뀌면 방 목록 새로고침
    ref.listen<Child?>(selectedChildProvider, (prev, next) {
      if (prev?.id != next?.id) {
        ref.read(homeProvider.notifier).loadRooms(
              refresh: true,
              ageMonth: next != null
                  ? AppDateUtils.calculateAgeMonths(next.birthYear, next.birthMonth)
                  : null,
            );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.location_on_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 4),
                  Text(regionDong, style: AppTextStyles.heading3),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary),
                  const Spacer(),
                  _NotificationButton(
                    unreadCount: homeState.unreadCount,
                    onTap: () => context.push('/notifications'),
                  ),
                ],
              ),
            ),

            // 아이 선택 칩
            if (children.isNotEmpty) ...[
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _ChildChip(
                      label: '전체',
                      ageLabel: null,
                      isSelected: selectedChild == null,
                      onTap: () {
                        ref.read(selectedChildProvider.notifier).clear();
                      },
                    ),
                    ...children.map((child) {
                      final ageMonths = AppDateUtils.calculateAgeMonths(
                          child.birthYear, child.birthMonth);
                      return _ChildChip(
                        label: child.nickname,
                        ageLabel: AppDateUtils.formatAgeMonths(ageMonths),
                        isSelected: selectedChild?.id == child.id,
                        onTap: () {
                          ref.read(selectedChildProvider.notifier).select(child);
                        },
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: () {
                  // TODO: Navigate to search
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded,
                          color: AppColors.textHint, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        selectedChild != null
                            ? '${selectedChild.nickname} 또래 모임 찾기'
                            : '어떤 모임을 찾고 계세요?',
                        style: AppTextStyles.body2
                            .copyWith(color: AppColors.textHint),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Filter chips
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Date filters
                  _FilterChip(
                    label: '전체',
                    isSelected: homeState.dateFilter == DateFilter.all,
                    onTap: () => ref
                        .read(homeProvider.notifier)
                        .setDateFilter(DateFilter.all),
                  ),
                  _FilterChip(
                    label: '오늘',
                    isSelected: homeState.dateFilter == DateFilter.today,
                    onTap: () => ref
                        .read(homeProvider.notifier)
                        .setDateFilter(DateFilter.today),
                  ),
                  _FilterChip(
                    label: '내일',
                    isSelected: homeState.dateFilter == DateFilter.tomorrow,
                    onTap: () => ref
                        .read(homeProvider.notifier)
                        .setDateFilter(DateFilter.tomorrow),
                  ),
                  _FilterChip(
                    label: '이번 주',
                    isSelected: homeState.dateFilter == DateFilter.thisWeek,
                    onTap: () => ref
                        .read(homeProvider.notifier)
                        .setDateFilter(DateFilter.thisWeek),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 1,
                    height: 20,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    color: AppColors.divider,
                  ),
                  const SizedBox(width: 8),
                  // Place type filters
                  _FilterChip(
                    label: '전체',
                    isSelected: homeState.placeTypeFilter == null,
                    onTap: () => ref
                        .read(homeProvider.notifier)
                        .setPlaceTypeFilter(null),
                  ),
                  ...AppConstants.placeTypes.entries.map(
                    (e) => _FilterChip(
                      label: e.value,
                      isSelected: homeState.placeTypeFilter == e.key,
                      onTap: () => ref
                          .read(homeProvider.notifier)
                          .setPlaceTypeFilter(e.key),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Room list
            Expanded(
              child: _buildRoomList(homeState),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomList(HomeState homeState) {
    if (homeState.isLoading && homeState.rooms.isEmpty) {
      return const ShimmerList();
    }

    if (homeState.error != null && homeState.rooms.isEmpty) {
      return ErrorState(
        message: homeState.error!,
        onRetry: () => ref.read(homeProvider.notifier).loadRooms(refresh: true),
      );
    }

    if (homeState.rooms.isEmpty) {
      return EmptyState(
        icon: Icons.child_care_rounded,
        title: '아직 모임이 없어요',
        subtitle: '첫 번째 모임을 만들어 보세요!',
        buttonText: '모임 만들기',
        onButtonTap: () => context.push('/rooms/create'),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(homeProvider.notifier).loadRooms(refresh: true);
      },
      color: AppColors.primary,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(top: 4, bottom: 100),
        itemCount: homeState.rooms.length + (homeState.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == homeState.rooms.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                ),
              ),
            );
          }

          final room = homeState.rooms[index];
          return RoomCard(
            room: room,
            onTap: () => context.push('/rooms/${room.id}'),
          );
        },
      ),
    );
  }
}

class _ChildChip extends StatelessWidget {
  final String label;
  final String? ageLabel;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChildChip({
    required this.label,
    required this.ageLabel,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.secondary
                : AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected ? AppColors.secondary : AppColors.divider,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.secondary.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.child_care_rounded,
                size: 16,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (ageLabel != null) ...[
                const SizedBox(width: 4),
                Text(
                  ageLabel!,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.8)
                        : AppColors.textHint,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.divider,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: isSelected ? Colors.white : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;

  const _NotificationButton({
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.divider),
            ),
            child: const Icon(Icons.notifications_none_rounded,
                color: AppColors.textPrimary, size: 22),
          ),
          if (unreadCount > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.unreadBadge,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Center(
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: AppTextStyles.badge,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
