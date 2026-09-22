import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/phone_verification_gate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/user.dart';
import '../../../providers/selected_child_provider.dart';
import '../../../widgets/design/primary_button.dart';
import '../../../widgets/design/notebook.dart';
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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null) {
        ref.read(selectedChildProvider.notifier).initFromUser(user);
      }
      // ref.listen 은 '변화'만 잡는다 — 홈 대시보드가 먼저 아이를 고른 뒤 이
      // 화면이 처음 만들어지는 기본 경로에서는 한 번도 안 불린다. 그래서 첫
      // 조회는 현재 선택된 아이로 직접 시드한다(setAgeMonth 가 목록도 불러온다).
      final child = ref.read(selectedChildProvider);
      ref.read(homeProvider.notifier).setAgeMonth(
            child != null
                ? AppDateUtils.calculateAgeMonths(
                    child.birthYear, child.birthMonth)
                : null,
          );
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
        ref.read(homeProvider.notifier).setAgeMonth(
              next != null
                  ? AppDateUtils.calculateAgeMonths(
                      next.birthYear, next.birthMonth)
                  : null,
            );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            // 앱바 한 줄 — 화면 제목 + 노란 '만들기' 알약.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
              child: Row(
                children: [
                  Text('모임 찾기', style: AppTextStyles.screenTitle),
                  const Spacer(),
                  // 모서리 이름표 — 누구 기준으로 보는지. 누르면 아이 선택 시트.
                  if (children.isNotEmpty) ...[
                    NameTag(
                      text: selectedChild == null
                          ? '모든 아이'
                          : '${selectedChild.nickname} '
                              '${AppDateUtils.calculateAgeMonths(selectedChild.birthYear, selectedChild.birthMonth)}개월',
                      onTap: () => _pickChild(context, children, selectedChild),
                    ),
                    const SizedBox(width: 12),
                  ],
                  _CreatePill(
                    key: const Key('btn-home-create-room'),
                    onTap: () => openRoomCreate(context, ref),
                  ),
                ],
              ),
            ),

            // 포스트잇 보드 — 자주 쓰는 조건을 붙였다 뗀다. 기간(노랑)과 장소(하늘)는
            // 서로 다른 축이라 하나씩 붙을 수 있고, 같은 축의 다른 포스트잇을 붙이면
            // 먼저 것이 떨어진다. 정밀 조건은 '＋ 더보기' 시트.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Wrap(
                spacing: 10,
                runSpacing: 12,
                // 한 줄 4칸(74×4 + 10×3 = 326 ≤ 335). 5칸이면 두 줄로 내려가 세로를 먹는다.
                // 내일·키즈카페 같은 나머지 조건은 '더보기' 시트에서.
                children: [
                  _datePostIt(0, '오늘', DateFilter.today, homeState,
                      caption: _mdLabel(DateTime.now())),
                  _datePostIt(1, '이번 주', DateFilter.thisWeek, homeState,
                      caption: '일요일까지'),
                  _placePostIt(2, 'PLAYGROUND', homeState, caption: '야외'),
                  PostItSlot(
                    label: '＋ 조건\n더보기',
                    onTap: () => _openMoreFilters(context),
                  ),
                ],
              ),
            ),
            // 붙인 조건 요약 — 보드에 없는 조건(내일·키즈카페 등)도 여기서 보이고 뗄 수 있다.
            if (homeState.dateFilter != DateFilter.all ||
                homeState.placeTypeFilter != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: '붙인 조건: '),
                    TextSpan(
                      text: [
                        switch (homeState.dateFilter) {
                          DateFilter.today => '오늘',
                          DateFilter.tomorrow => '내일',
                          DateFilter.thisWeek => '이번 주',
                          DateFilter.all => null,
                        },
                        if (homeState.placeTypeFilter != null)
                          AppConstants.placeTypes[homeState.placeTypeFilter!],
                      ].whereType<String>().join(' · '),
                      style: AppTextStyles.captionBold.copyWith(color: AppColors.ink),
                    ),
                    const TextSpan(text: ' · '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: GestureDetector(
                        onTap: () {
                          final n = ref.read(homeProvider.notifier);
                          n.setDateFilter(DateFilter.all);
                          n.setPlaceTypeFilter(null);
                        },
                        child: Text('모두 떼기',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.link, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ]),
                  style: AppTextStyles.caption,
                ),
              ),

            // 개월수 필터가 걸린 이유를 한 줄로 — 목록이 짧은 까닭을 먼저 알린다.
            if (children.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _ChildFilterCaption(
                    child: selectedChild,
                    fallback: children.first,
                    onToggle: () {
                      final n = ref.read(selectedChildProvider.notifier);
                      selectedChild == null
                          ? n.select(children.first)
                          : n.clear();
                    },
                  ),
                ),
              ),

            const SizedBox(height: 4),
            Expanded(child: _buildRoomList(homeState)),
          ],
        ),
      ),
    );
  }

  static String _mdLabel(DateTime d) {
    const w = ['월', '화', '수', '목', '금', '토', '일'];
    return '${d.month}/${d.day} ${w[d.weekday - 1]}';
  }

  Widget _datePostIt(int index, String label, DateFilter filter,
      HomeState homeState, {String? caption}) {
    final on = homeState.dateFilter == filter;
    return PostIt(
      label: label,
      caption: caption,
      tone: PostItTone.hi,
      selected: on,
      tiltDegrees: PostIt.tiltFor(index),
      onTap: () => ref
          .read(homeProvider.notifier)
          .setDateFilter(on ? DateFilter.all : filter),
    );
  }

  Widget _placePostIt(int index, String key, HomeState homeState,
      {String? caption}) {
    final on = homeState.placeTypeFilter == key;
    return PostIt(
      label: AppConstants.placeTypes[key] ?? key,
      caption: caption,
      tone: PostItTone.sky,
      selected: on,
      tiltDegrees: PostIt.tiltFor(index),
      onTap: () =>
          ref.read(homeProvider.notifier).setPlaceTypeFilter(on ? null : key),
    );
  }

  /// '＋ 더보기' — 언제 / 어디서 체크리스트. 고르는 즉시 적용된다.
  Future<void> _openMoreFilters(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => Consumer(builder: (ctx, ref, _) {
        final st = ref.watch(homeProvider);
        final n = ref.read(homeProvider.notifier);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.line2,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('언제 놀까요?', style: AppTextStyles.handXl.copyWith(fontSize: 26)),
                const SizedBox(height: 6),
                for (final e in const [
                  (DateFilter.all, '아무 때나', '기간 안 가림'),
                  (DateFilter.today, '오늘', null),
                  (DateFilter.tomorrow, '내일', null),
                  (DateFilter.thisWeek, '이번 주', '일요일까지'),
                ])
                  _CheckRow(
                    label: e.$2,
                    note: e.$3,
                    selected: st.dateFilter == e.$1,
                    onTap: () => n.setDateFilter(e.$1),
                  ),
                const SizedBox(height: 22),
                Text('어디서 놀까요?', style: AppTextStyles.handXl.copyWith(fontSize: 26)),
                const SizedBox(height: 6),
                _CheckRow(
                  label: '어디든',
                  note: '장소 안 가림',
                  selected: st.placeTypeFilter == null,
                  onTap: () => n.setPlaceTypeFilter(null),
                ),
                for (final e in AppConstants.placeTypes.entries)
                  _CheckRow(
                    label: e.value,
                    selected: st.placeTypeFilter == e.key,
                    onTap: () => n.setPlaceTypeFilter(e.key),
                  ),
                const SizedBox(height: 16),
                PrimaryButton(
                  text: '완료',
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  /// 아이 선택 시트 — 아이별 + '모든 아이'.
  Future<void> _pickChild(
      BuildContext context, List<Child> children, Child? current) async {
    final picked = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('누구 기준으로 볼까요?', style: AppTextStyles.sectionHead),
              ),
            ),
            for (final c in children)
              _childOption(
                ctx,
                title: c.nickname,
                subtitle:
                    '${AppDateUtils.calculateAgeMonths(c.birthYear, c.birthMonth)}개월',
                selected: current?.id == c.id,
                onTap: () => Navigator.of(ctx).pop(c),
              ),
            _childOption(
              ctx,
              title: '모든 아이',
              subtitle: '개월수 조건 없이 전부',
              selected: current == null,
              onTap: () => Navigator.of(ctx).pop('all'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final n = ref.read(selectedChildProvider.notifier);
    picked is Child ? n.select(picked) : n.clear();
  }

  Widget _childOption(
    BuildContext ctx, {
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Text(title,
          style: selected ? AppTextStyles.body1Bold : AppTextStyles.body1),
      subtitle: Text(subtitle, style: AppTextStyles.caption),
      trailing: selected
          ? const Icon(Icons.check_rounded, color: AppColors.ink, size: 20)
          : null,
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
        color: AppColors.ink,
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
      // 아이 기준(개월수)은 기본 상태라 사유로 대지 않는다 — 위 캡션에 이미 적혀 있다.
      // 사용자가 직접 건 날짜·장소 필터만 이름을 대준다.
      final causes = [
        if (homeState.dateFilter != DateFilter.all) '날짜',
        if (homeState.placeTypeFilter != null) '장소',
      ];
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: AppColors.ink,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              // 아이 개월수 필터는 기본으로 걸려 있다 — 필터 탓에 0건인데
              // '아직 모임이 없어요'라고 하면 사실과 다르다.
              child: EmptyState(
                icon: Icons.child_care_rounded,
                title:
                    causes.isEmpty ? '아직 모임이 없어요' : '조건에 맞는 모임이 없어요',
                subtitle: causes.isEmpty
                    ? '첫 번째 모임을 만들어 보세요!'
                    : '${causes.join('·')} 필터를 풀면 더 볼 수 있어요',
                buttonText: '모임 만들기',
                onButtonTap: () => openRoomCreate(context, ref),
              ),
            ),
          ],
        ),
      );
    }

    final rooms = homeState.rooms;
    final items = _buildListItems(rooms.map((r) => r.date).toList());
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.ink,
      child: ListView.builder(
        controller: _scrollController,
        // 행이 화면보다 적어도 풀투리프레시·스크롤 제스처가 동작하게.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
        itemCount: items.length + (homeState.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          // 더보기 로딩 인디케이터 (맨 끝)
          if (homeState.isLoadingMore && index == items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.ink,
                  strokeWidth: 2,
                ),
              ),
            );
          }
          final item = items[index];
          if (item.groupLabel != null) return GroupLabel(item.groupLabel!);
          if (item.adSlot != null) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: NativeAdCard(key: ValueKey('native-ad-${item.adSlot}')),
            );
          }
          final room = rooms[item.roomIndex!];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.showDivider) const DashedDivider(),
              RoomCard(
                room: room,
                onTap: () => context.push('/rooms/${room.id}'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 목록 행 구조를 미리 계산한다.
  /// - 날짜가 바뀌면 그룹 라벨을 한 줄 끼운다 (오늘 / 내일 / 이번 주 …).
  /// - 광고는 방 6개 뒤 첫 행, 그 뒤로 8개마다 한 행 (2열 시절과 같은 간격).
  List<_ListItem> _buildListItems(List<String> roomDates) {
    final items = <_ListItem>[];
    String? currentGroup;
    int adSlot = 0;

    for (var i = 0; i < roomDates.length; i++) {
      final date = DateTime.tryParse(roomDates[i]);
      final group = date != null ? roomGroupLabel(date) : null;
      if (group != null && group != currentGroup) {
        items.add(_ListItem.group(group));
        currentGroup = group;
      }
      final prev = items.isNotEmpty ? items.last : null;
      items.add(_ListItem.room(i, showDivider: prev?.roomIndex != null));

      final shown = i + 1;
      if (shown == 6 || (shown > 6 && (shown - 6) % 8 == 0)) {
        items.add(_ListItem.ad(adSlot++));
        currentGroup = null; // 광고 뒤에는 그룹 라벨을 다시 세운다.
      }
    }
    return items;
  }
}

/// 목록의 한 줄 — 그룹 라벨이거나 방 행이거나 광고.
class _ListItem {
  final String? groupLabel;
  final int? roomIndex;
  final int? adSlot;
  final bool showDivider;

  const _ListItem.group(String label)
      : groupLabel = label,
        roomIndex = null,
        adSlot = null,
        showDivider = false;

  const _ListItem.room(int index, {required this.showDivider})
      : groupLabel = null,
        roomIndex = index,
        adSlot = null;

  const _ListItem.ad(int slot)
      : groupLabel = null,
        roomIndex = null,
        adSlot = slot,
        showDivider = false;
}

/// 앱바 오른쪽 노란 알약 — "＋ 만들기".
class _CreatePill extends StatelessWidget {
  final VoidCallback onTap;

  const _CreatePill({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: AppColors.hi,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 16, color: AppColors.ink),
            const SizedBox(width: 3),
            Text(
              '만들기',
              style: AppTextStyles.body2Bold.copyWith(color: AppColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

/// "하율(26개월)이 참여할 수 있는 모임만 보여요" — 숫자만 손글씨.
class _ChildFilterCaption extends StatelessWidget {
  /// 지금 기준이 되는 아이. null 이면 개월수 조건 없이 보는 중.
  final Child? child;
  /// 다시 아이 기준으로 돌아갈 때 쓸 아이(첫째).
  final Child fallback;
  final VoidCallback onToggle;

  const _ChildFilterCaption({
    required this.child,
    required this.fallback,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final c = child;
    final link = AppTextStyles.caption.copyWith(
      color: AppColors.link,
      fontWeight: FontWeight.w600,
    );
    if (c == null) {
      return Text.rich(
        TextSpan(children: [
          const TextSpan(text: '모든 개월수의 모임을 보고 있어요 · '),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: onToggle,
              child: Text('${fallback.nickname} 기준으로', style: link),
            ),
          ),
        ]),
        style: AppTextStyles.caption,
      );
    }
    final months = AppDateUtils.calculateAgeMonths(c.birthYear, c.birthMonth);
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: '${c.nickname}('),
        TextSpan(
          text: '$months',
          style: AppTextStyles.hand.copyWith(fontSize: 14, color: AppColors.skyInk),
        ),
        const TextSpan(text: '개월)이 참여할 수 있는 모임만 보여요 · '),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            onTap: onToggle,
            child: Text('전체 보기', style: link),
          ),
        ),
      ]),
      style: AppTextStyles.caption,
    );
  }
}

/// 시트의 체크 칸 한 줄 — 네모 칸 + 펜 ✓ + 라벨 + 오른쪽 짧은 메모.
class _CheckRow extends StatelessWidget {
  final String label;
  final String? note;
  final bool selected;
  final VoidCallback onTap;

  const _CheckRow({
    required this.label,
    this.note,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.hi : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: selected ? AppColors.ink : AppColors.ink3,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? Text('✓', style: AppTextStyles.stamp.copyWith(fontSize: 19, height: 1))
                  : null,
            ),
            const SizedBox(width: 12),
            Text(label,
                style: selected ? AppTextStyles.body1Bold : AppTextStyles.body1),
            const Spacer(),
            if (note != null) Text(note!, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}
