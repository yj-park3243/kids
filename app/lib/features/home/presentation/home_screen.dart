import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/user.dart';
import '../../../providers/selected_child_provider.dart';
import '../../../widgets/design/baby_avatar.dart';
import '../../../widgets/design/design_chip.dart';
import '../../../widgets/design/glass_card.dart';
import '../../../widgets/design/pink_blobs.dart';
import '../../../widgets/design/pink_button.dart';
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
    final regionSigungu = authState.user?.regionSigungu ?? '';

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
      backgroundColor: Colors.transparent,
      body: PinkBlobsBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: AppColors.pinkGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '같',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('같이크자', style: AppTextStyles.sectionHead),
                    const Spacer(),
                    GlassIconButton(
                      icon: Icons.search_rounded,
                      onTap: () {},
                    ),
                    const SizedBox(width: 8),
                    GlassIconButton(
                      icon: Icons.notifications_outlined,
                      showDot: homeState.unreadCount > 0,
                      onTap: () => context.push('/notifications'),
                    ),
                  ],
                ),
              ),

              // Child switcher (glass pink)
              if (selectedChild != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: GlassCard(
                    tone: GlassTone.pink,
                    radius: 20,
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        BabyAvatar(
                          size: 58,
                          tone: selectedChild.gender == 'MALE'
                              ? BabyAvatarTone.blue
                              : BabyAvatarTone.pink,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    selectedChild.nickname,
                                    style: AppTextStyles.cardTitle,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    AppDateUtils.formatAgeMonths(
                                      AppDateUtils.calculateAgeMonths(
                                        selectedChild.birthYear,
                                        selectedChild.birthMonth,
                                      ),
                                    ),
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.pink700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$regionSigungu $regionDong · 활동 반경 3km',
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            color: AppColors.ink500),
                      ],
                    ),
                  ),
                ),

              // 아이 선택 칩
              if (children.isNotEmpty) ...[
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _childChip(
                        '전체',
                        null,
                        selectedChild == null,
                        () => ref.read(selectedChildProvider.notifier).clear(),
                      ),
                      ...children.map((child) {
                        final ageMonths = AppDateUtils.calculateAgeMonths(
                            child.birthYear, child.birthMonth);
                        return _childChip(
                          child.nickname,
                          AppDateUtils.formatAgeMonths(ageMonths),
                          selectedChild?.id == child.id,
                          () => ref
                              .read(selectedChildProvider.notifier)
                              .select(child),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Filter chips
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _paddedChip(DesignChip(
                      label: '전체',
                      selected: homeState.dateFilter == DateFilter.all,
                      onTap: () => ref
                          .read(homeProvider.notifier)
                          .setDateFilter(DateFilter.all),
                    )),
                    _paddedChip(DesignChip(
                      label: '오늘',
                      selected: homeState.dateFilter == DateFilter.today,
                      onTap: () => ref
                          .read(homeProvider.notifier)
                          .setDateFilter(DateFilter.today),
                    )),
                    _paddedChip(DesignChip(
                      label: '내일',
                      selected: homeState.dateFilter == DateFilter.tomorrow,
                      onTap: () => ref
                          .read(homeProvider.notifier)
                          .setDateFilter(DateFilter.tomorrow),
                    )),
                    _paddedChip(DesignChip(
                      label: '이번 주',
                      selected: homeState.dateFilter == DateFilter.thisWeek,
                      onTap: () => ref
                          .read(homeProvider.notifier)
                          .setDateFilter(DateFilter.thisWeek),
                    )),
                    Container(
                      width: 1,
                      height: 18,
                      margin: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                      color: AppColors.dividerStrong,
                    ),
                    _paddedChip(DesignChip(
                      label: '장소 전체',
                      selected: homeState.placeTypeFilter == null,
                      onTap: () => ref
                          .read(homeProvider.notifier)
                          .setPlaceTypeFilter(null),
                    )),
                    ...AppConstants.placeTypes.entries.map(
                      (e) => _paddedChip(DesignChip(
                        label: e.value,
                        selected: homeState.placeTypeFilter == e.key,
                        onTap: () => ref
                            .read(homeProvider.notifier)
                            .setPlaceTypeFilter(e.key),
                      )),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              Expanded(child: _buildRoomList(homeState)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paddedChip(Widget chip) =>
      Padding(padding: const EdgeInsets.only(right: 8), child: chip);

  Widget _childChip(
      String label, String? age, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            gradient: selected ? AppColors.pinkGradient : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? Colors.transparent : AppColors.pink200,
              width: 0.8,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.pink500.withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.child_care_rounded,
                size: 14,
                color: selected ? Colors.white : AppColors.pink500,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTextStyles.chip.copyWith(
                  color: selected ? Colors.white : AppColors.ink700,
                ),
              ),
              if (age != null) ...[
                const SizedBox(width: 4),
                Text(
                  age,
                  style: AppTextStyles.chip.copyWith(
                    fontSize: 11,
                    color: selected
                        ? Colors.white.withValues(alpha: 0.9)
                        : AppColors.ink500,
                  ),
                ),
              ],
            ],
          ),
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
      color: AppColors.pink500,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
        itemCount: homeState.rooms.length + (homeState.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == homeState.rooms.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.pink500,
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
