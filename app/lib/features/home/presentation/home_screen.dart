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
import '../../notice/presentation/widgets/pinned_notice_banner.dart';
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
  final _searchController = TextEditingController();

  // 칩 영역(아이 선택 + 필터) 접기/펴기 상태.
  bool _filtersExpanded = true;

  // 인라인 검색바 표시 여부 및 검색어.
  bool _searchOpen = false;
  String _searchQuery = '';

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
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
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
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
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
                      key: const Key('btn-home-create-room'),
                      icon: Icons.add_rounded,
                      onTap: () => context.push('/rooms/create'),
                    ),
                    const SizedBox(width: 8),
                    GlassIconButton(
                      icon: _searchOpen
                          ? Icons.close_rounded
                          : Icons.search_rounded,
                      onTap: _toggleSearch,
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

              // 공지사항 배너 — 앱바 바로 아래
              const PinnedNoticeBanner(),

              // 인라인 검색바 — 돋보기 아이콘으로 토글.
              if (_searchOpen) _buildSearchBar(),

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
                                  color: AppColors.accentSky,
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
                                  color: AppColors.accentLime,
                                  selected: homeState.placeTypeFilter == null,
                                  onTap: () => ref
                                      .read(homeProvider.notifier)
                                      .setPlaceTypeFilter(null),
                                )),
                                ...AppConstants.placeTypes.entries.map(
                                  (e) => _paddedChip(_filterChip(
                                    label: e.value,
                                    color: AppColors.accentFor(e.key),
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

  // 인라인 검색바 — 방 제목/태그 기준 거름.
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary200, width: 0.8),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: const Key('field-home-search'),
                controller: _searchController,
                autofocus: true,
                style: AppTextStyles.body2,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: '방 제목 · 태그 검색',
                ),
                onChanged: (v) =>
                    setState(() => _searchQuery = v.trim().toLowerCase()),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                child: const Icon(Icons.cancel_rounded,
                    size: 18, color: AppColors.ink500),
              ),
          ],
        ),
      ),
    );
  }

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

    // 검색어가 있으면 방 제목/태그 기준으로 거른다.
    final rooms = _searchQuery.isEmpty
        ? homeState.rooms
        : homeState.rooms.where((r) {
            final q = _searchQuery;
            return r.title.toLowerCase().contains(q) ||
                r.tags.any((t) => t.toLowerCase().contains(q));
          }).toList();

    if (rooms.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: '검색 결과가 없어요',
        subtitle: '다른 키워드로 검색해 보세요',
      );
    }
    final adCount = _adCount(rooms.length);
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(homeProvider.notifier).loadRooms(refresh: true);
      },
      color: AppColors.primary,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
        itemCount: rooms.length + adCount + (homeState.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          // 더보기 로딩 인디케이터 (맨 끝)
          if (homeState.isLoadingMore && index == rooms.length + adCount) {
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
          // 광고 슬롯 — 6번째 카드 뒤(index 6), 이후 8개 간격(index 6+9k)
          if (index >= _firstAdIndex &&
              (index - _firstAdIndex) % _adStride == 0) {
            final adSlot = (index - _firstAdIndex) ~/ _adStride;
            return NativeAdCard(key: ValueKey('native-ad-$adSlot'));
          }
          // 방 카드
          final roomIndex = index -
              (index < _firstAdIndex
                  ? 0
                  : 1 + ((index - _firstAdIndex) ~/ _adStride));
          final room = rooms[roomIndex];
          return RoomCard(
            room: room,
            onTap: () => context.push('/rooms/${room.id}'),
          );
        },
      ),
    );
  }

  // 광고 배치: 방 6개마다 첫 광고, 이후 8개 간격.
  static const int _firstAdIndex = 6; // 첫 광고의 표시 인덱스
  static const int _adStride = 9; // 광고 사이 표시 인덱스 간격(방 8 + 광고 1)

  int _adCount(int roomCount) =>
      roomCount < 6 ? 0 : 1 + ((roomCount - 6) ~/ 8);
}
