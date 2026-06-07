import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/user.dart';
import '../../../providers/selected_child_provider.dart';
import '../../../widgets/design/accent_blobs.dart';
import '../../../widgets/design/primary_button.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/home_provider.dart';
import 'widgets/native_ad_card.dart';
import 'widgets/room_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollController = ScrollController();

  // 칩 영역(아이 선택 + 필터) 접기/펴기 상태.
  bool _filtersExpanded = true;

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
      body: AccentBlobsBackground(
        child: SafeArea(
          child: Column(
            children: [
              // 모임 탭 상단 — 방 만들기(+) 버튼만 유지.
              // 로고/제목/검색/알림과 공지 배너는 홈 대시보드로 이전됨.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  children: [
                    const Spacer(),
                    GlassIconButton(
                      key: const Key('btn-home-create-room'),
                      icon: Icons.add_rounded,
                      onTap: () => context.push('/rooms/create'),
                    ),
                  ],
                ),
              ),

              // 필터 영역 토글 버튼.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(
                          () => _filtersExpanded = !_filtersExpanded),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '필터',
                            style: AppTextStyles.chip.copyWith(
                              color: AppColors.primary700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            _filtersExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),

              // 아이 선택 칩 + 필터 칩 — 함께 접고 펼친다.
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: _filtersExpanded
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 8),
                          // 아이 선택 칩 — 아이가 2명 이상일 때만.
                          if (children.length >= 2) ...[
                            SizedBox(
                              height: 36,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20),
                                children: [
                                  _childChip(
                                    '전체',
                                    null,
                                    selectedChild == null,
                                    () => ref
                                        .read(selectedChildProvider.notifier)
                                        .clear(),
                                  ),
                                  ...children.map((child) {
                                    final ageMonths =
                                        AppDateUtils.calculateAgeMonths(
                                            child.birthYear,
                                            child.birthMonth);
                                    return _childChip(
                                      child.nickname,
                                      AppDateUtils.formatAgeMonths(ageMonths),
                                      selectedChild?.id == child.id,
                                      () => ref
                                          .read(
                                              selectedChildProvider.notifier)
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20),
                              children: [
                                _paddedChip(_filterChip(
                                  label: '전체',
                                  color: AppColors.primary,
                                  selected:
                                      homeState.dateFilter == DateFilter.all,
                                  onTap: () => ref
                                      .read(homeProvider.notifier)
                                      .setDateFilter(DateFilter.all),
                                )),
                                _paddedChip(_filterChip(
                                  label: '오늘',
                                  color: AppColors.accentCoral,
                                  selected: homeState.dateFilter ==
                                      DateFilter.today,
                                  onTap: () => ref
                                      .read(homeProvider.notifier)
                                      .setDateFilter(DateFilter.today),
                                )),
                                _paddedChip(_filterChip(
                                  label: '내일',
                                  color: AppColors.primary,
                                  selected: homeState.dateFilter ==
                                      DateFilter.tomorrow,
                                  onTap: () => ref
                                      .read(homeProvider.notifier)
                                      .setDateFilter(DateFilter.tomorrow),
                                )),
                                _paddedChip(_filterChip(
                                  label: '이번 주',
                                  color: AppColors.accentLavender,
                                  selected: homeState.dateFilter ==
                                      DateFilter.thisWeek,
                                  onTap: () => ref
                                      .read(homeProvider.notifier)
                                      .setDateFilter(DateFilter.thisWeek),
                                )),
                                Container(
                                  width: 1,
                                  height: 18,
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 9, horizontal: 6),
                                  color: AppColors.dividerStrong,
                                ),
                                _paddedChip(_filterChip(
                                  label: '장소 전체',
                                  color: AppColors.placeAll,
                                  selected: homeState.placeTypeFilter == null,
                                  onTap: () => ref
                                      .read(homeProvider.notifier)
                                      .setPlaceTypeFilter(null),
                                )),
                                ...AppConstants.placeTypes.entries.map(
                                  (e) => _paddedChip(_filterChip(
                                    label: e.value,
                                    color: AppColors.placeColorFor(e.key),
                                    selected:
                                        homeState.placeTypeFilter == e.key,
                                    onTap: () => ref
                                        .read(homeProvider.notifier)
                                        .setPlaceTypeFilter(e.key),
                                  )),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
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

  // 색이 칩마다 다른 필터 칩.
  Widget _filterChip({
    required String label,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : color.withValues(alpha: 0.4),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.chip.copyWith(
            color: selected ? Colors.white : color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

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
            gradient: selected ? AppColors.primaryGradient : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? Colors.transparent : AppColors.primary200,
              width: 0.8,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.28),
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
                color: selected ? Colors.white : AppColors.primary,
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
    // 초기 로딩(시머)은 풀투리프레시가 의미 없어 그대로 둔다.
    if (homeState.isLoading && homeState.rooms.isEmpty) {
      return const ShimmerList();
    }

    Future<void> onRefresh() =>
        ref.read(homeProvider.notifier).loadRooms(refresh: true);

    // 에러/빈 상태도 RefreshIndicator + 항상 스크롤 가능한 ListView 로 감싸
    // 사용자가 아래로 당겨 다시 시도할 수 있도록 한다. 콘텐츠가 짧을 때도
    // AlwaysScrollableScrollPhysics 가 있어야 풀투리프레시 제스처가 잡힌다.
    if (homeState.error != null && homeState.rooms.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: ErrorState(
                message: homeState.error!,
                onRetry: onRefresh,
              ),
            ),
          ],
        ),
      );
    }
    if (homeState.rooms.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: EmptyState(
                icon: Icons.child_care_rounded,
                title: '아직 모임이 없어요',
                subtitle: '첫 번째 모임을 만들어 보세요!',
                buttonText: '모임 만들기',
                onButtonTap: () => context.push('/rooms/create'),
              ),
            ),
          ],
        ),
      );
    }

    final rooms = homeState.rooms;
    final homeRows = _buildHomeRows(rooms.length);
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: ListView.builder(
        controller: _scrollController,
        // 행이 화면보다 적어도 풀투리프레시·스크롤 제스처가 동작하게.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 110),
        itemCount: homeRows.length + (homeState.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          // 더보기 로딩 인디케이터 (맨 끝)
          if (homeState.isLoadingMore && index == homeRows.length) {
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
          final row = homeRows[index];
          if (row.isAd) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: NativeAdCard(key: ValueKey('native-ad-${row.adSlot}')),
            );
          }
          // 카드 페어 — 한 행에 2개씩.
          final left = rooms[row.leftRoomIndex!];
          final right = row.rightRoomIndex != null
              ? rooms[row.rightRoomIndex!]
              : null;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: RoomCardCompact(
                    room: left,
                    onTap: () => context.push('/rooms/${left.id}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: right != null
                      ? RoomCardCompact(
                          room: right,
                          onTap: () => context.push('/rooms/${right.id}'),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 홈 리스트 행 구조를 미리 계산.
  /// - 카드 페어 행: 방 2개를 한 행으로 묶음 (홀수면 오른쪽 비움)
  /// - 광고 행: 페어 3개째 뒤에 첫 광고, 그 뒤 페어 4개마다 광고 1행
  List<_HomeRow> _buildHomeRows(int roomCount) {
    final rows = <_HomeRow>[];
    int pairsAdded = 0;
    int adSlot = 0;
    int i = 0;
    while (i < roomCount) {
      final left = i;
      final right = i + 1 < roomCount ? i + 1 : null;
      rows.add(_HomeRow.pair(left, right));
      pairsAdded++;
      i += 2;
      if (pairsAdded == 3 ||
          (pairsAdded > 3 && (pairsAdded - 3) % 4 == 0)) {
        rows.add(_HomeRow.ad(adSlot++));
      }
    }
    return rows;
  }
}

/// 홈 리스트의 한 행 — 카드 페어이거나 광고.
class _HomeRow {
  final bool isAd;
  final int? leftRoomIndex;
  final int? rightRoomIndex;
  final int? adSlot;

  const _HomeRow.pair(int left, int? right)
      : isAd = false,
        leftRoomIndex = left,
        rightRoomIndex = right,
        adSlot = null;

  const _HomeRow.ad(int slot)
      : isAd = true,
        leftRoomIndex = null,
        rightRoomIndex = null,
        adSlot = slot;
}
