import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/phone_verification_gate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/room.dart';
import '../../../models/user.dart';
import '../../../providers/selected_child_provider.dart';
import '../../../widgets/design/avatar.dart';
import '../../../widgets/design/glass_card.dart';
import '../../../widgets/design/notebook.dart';
import '../../../widgets/design/primary_button.dart';
import '../../../widgets/loading.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/providers/chat_provider.dart';
import '../../notice/presentation/widgets/pinned_notice_banner.dart';
import '../data/dashboard_summary.dart';
import '../providers/dashboard_provider.dart';
import '../providers/home_provider.dart';

/// 5탭 홈 — 참여 모임 유무에 따라 빈 상태/대시보드로 분기.
///
/// 데이터 원천:
/// - 참여 모임: `roomRepositoryProvider.getMyRooms(UPCOMING)` 한 번 호출
/// - 주변 모임/오늘 카드/근처 모임 수: 기존 `homeProvider.rooms`
/// - 아이 정보: `selectedChildProvider` (없으면 첫째 아이)
class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() =>
      _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null) {
        ref.read(selectedChildProvider.notifier).initFromUser(user);
      }
      // 빈 상태 분기에 쓰는 unread 카운트 + 풀 상태에 쓰는 활동 일지.
      ref.read(homeProvider.notifier).loadUnreadCount();
      ref.read(dashboardProvider.notifier).load();
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(joinedRoomsProvider);
    // 빈 상태 문구 분기용 — 한 번 실패한 값이 keepAlive 로 굳지 않게 같이 갱신.
    ref.invalidate(hasPastRoomsProvider);
    await Future.wait([
      ref.read(dashboardProvider.notifier).load(silent: true),
      ref.read(joinedRoomsProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final homeState = ref.watch(homeProvider);
    final selectedChild = ref.watch(selectedChildProvider);
    final children = authState.user?.children ?? [];
    // 아이 칩이 선택돼 있지 않으면 첫째를 인사말 기준으로 쓴다.
    final child =
        selectedChild ?? (children.isNotEmpty ? children.first : null);

    // 방 상세에 들어가면 invalidate 되어 자동 재조회된다(새로고침 불필요).
    final joinedAsync = ref.watch(joinedRoomsProvider);
    final joined = joinedAsync.valueOrNull;
    // 예정 모임이 없으면 지난 이력까지 봐야 빈 화면/기록 화면을 결정할 수
    // 있다 — 이력 확인이 끝나기 전엔 시머를 유지해 문구 깜빡임을 막는다.
    final hasPastAsync = (joined != null && joined.isEmpty)
        ? ref.watch(hasPastRoomsProvider)
        : null;
    // 첫 로딩 중 — 풀스크린 시머. 로드 실패 시엔 재시도 UI —
    // 시머를 계속 두면 탈출 수단 없는 빈 화면에 갇힌다.
    if (joined == null || (hasPastAsync?.isLoading ?? false)) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(homeState),
              const PinnedNoticeBanner(),
              Expanded(
                child: joinedAsync.hasError
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.wifi_off_rounded,
                              size: 44,
                              color: AppColors.ink3,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '모임 정보를 불러오지 못했어요',
                              style: AppTextStyles.body1.copyWith(
                                color: AppColors.ink2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () =>
                                  ref.invalidate(joinedRoomsProvider),
                              child: Text(
                                '다시 시도',
                                style: AppTextStyles.buttonSmall.copyWith(
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const ShimmerList(),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(homeState),
            const PinnedNoticeBanner(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: AppColors.ink,
                // 지난 모임 이력이 있으면 예정 모임이 없어도 기록
                // 대시보드를 보여준다 — 신규 가입자 취급 금지.
                child: joined.isEmpty && !(hasPastAsync?.valueOrNull ?? false)
                    ? _EmptyDashboard(child: child)
                    : _FullDashboard(
                        child: child,
                        joinedRooms: joined,
                        summary: ref.watch(dashboardProvider).summary,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(HomeState homeState) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 6),
      child: Row(
        children: [
          Text('같이크자', style: AppTextStyles.wordmark),
          const Spacer(),
          GlassIconButton(
            // 아이콘 종류는 통합 테스트(ui_smoke_test)가 이걸로 알림 진입을 찾는다.
            icon: Icons.notifications_outlined,
            showDot: homeState.unreadCount > 0,
            onTap: () => context.push('/notifications'),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// 풀 대시보드 — 참여 모임이 1+ 일 때.
// 다음 모임 한 장에 집중 (docs/09_UI_수첩안.md §4 홈).
// ───────────────────────────────────────────────────────────────

class _FullDashboard extends ConsumerWidget {
  final Child? child;
  final List<Room> joinedRooms;
  final DashboardSummary summary;

  const _FullDashboard({
    required this.child,
    required this.joinedRooms,
    required this.summary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 다음 약속 — 오늘 이후의 미래 모임 중 가장 가까운 것.
    final upcoming = _findNextRoom(joinedRooms);
    final week = _thisWeek();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
      children: [
        _Greeting(child: child, next: upcoming),
        const SizedBox(height: 24),
        if (upcoming != null)
          _NextAppointmentCard(room: upcoming)
        else
          const _NoUpcomingBox(),
        const SizedBox(height: 20),
        _QuickEntries(nextRoomId: upcoming?.id),
        SectionHeader(title: '이번 주', action: _weekRangeLabel(week)),
        AppCard(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          child: _WeekStrip(week: week, activeDates: summary.activeDates),
        ),
        if (summary.frequentFriends.isNotEmpty) ...[
          SectionHeader(
            title: '자주 만난 친구',
            action: '단골 부모 ›',
            onAction: () => context.push('/follow/following'),
          ),
          _FriendsRow(friends: summary.frequentFriends),
        ],
        const SectionHeader(title: '함께한 기록'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: _RecordsRow(stats: summary.stats),
        ),
      ],
    );
  }

  static Room? _findNextRoom(List<Room> rooms) {
    final today = _todayKey();
    final futures = rooms.where((r) => r.date.compareTo(today) >= 0).toList()
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) return byDate;
        return a.startTime.compareTo(b.startTime);
      });
    return futures.isEmpty ? null : futures.first;
  }

  static String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  /// 이번 주 월요일 0시.
  static DateTime _thisWeek() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: today.weekday - 1));
  }

  static String _weekRangeLabel(DateTime monday) {
    final sunday = monday.add(const Duration(days: 6));
    if (monday.month == sunday.month) {
      return '${monday.month}월 ${monday.day}일 – ${sunday.day}일';
    }
    return '${monday.month}월 ${monday.day}일 – ${sunday.month}월 ${sunday.day}일';
  }
}

// ── 인사말 — 작은 호격 + 손글씨 한 줄, 핵심 단어 하나만 형광펜 ──
class _Greeting extends StatelessWidget {
  final Child? child;
  final Room? next;

  const _Greeting({required this.child, required this.next});

  /// (앞줄, 형광펜 단어). 앞줄이 비면 형광펜 줄만 그린다.
  (String, String) get _lines {
    final room = next;
    if (room == null) return ('이번 주', '놀러 갈까요?');
    final place = (room.placeName?.isNotEmpty ?? false)
        ? room.placeName!
        : room.regionDong;
    final days = _daysUntil(room.date);
    final when = switch (days) {
      null => '',
      0 => '오늘',
      1 => '내일',
      _ => '$days일 뒤',
    };
    if (place.isEmpty) return (when, '만나요');
    return (when.isEmpty ? '$place에서' : '$when $place에서', '만나요');
  }

  @override
  Widget build(BuildContext context) {
    final name = child?.nickname;
    final (lead, accent) = _lines;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (name != null && name.isNotEmpty) ...[
          Text('$name 부모님,', style: AppTextStyles.body2),
          const SizedBox(height: 6),
        ],
        if (lead.isNotEmpty)
          Text(
            lead,
            style: AppTextStyles.greeting,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        Highlight(child: Text(accent, style: AppTextStyles.greeting)),
      ],
    );
  }
}

// ── 다음 모임 — 화면에서 유일하게 떠 있는 카드 + 마스킹테이프 ──
class _NextAppointmentCard extends ConsumerWidget {
  final Room room;

  const _NextAppointmentCard({required this.room});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final place = (room.placeName?.isNotEmpty ?? false)
        ? room.placeName!
        : (room.regionDong.isNotEmpty ? room.regionDong : '장소 미정');
    // 이 방의 안 읽은 메시지 — 하단 탭 배지와 같은 원천(채팅방 목록).
    final unread =
        ref
            .watch(chatRoomsProvider)
            .valueOrNull
            ?.where((c) => c.id == room.chatRoomId)
            .fold<int>(0, (sum, c) => sum + c.unreadCount) ??
        0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AppCard(
          hero: true,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          onTap: () => context.push('/rooms/${room.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Stamp(text: _dDayStamp(room.date)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _weekdayDateLabel(room.date),
                      style: AppTextStyles.body2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                room.title,
                style: AppTextStyles.sectionHead.copyWith(fontSize: 18),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              _MetaLine(
                icon: Icons.access_time_rounded,
                text: _formatTime(room.startTime),
              ),
              const SizedBox(height: 3),
              _MetaLine(icon: Icons.place_outlined, text: place),
              const DashedDivider(margin: EdgeInsets.symmetric(vertical: 14)),
              Row(
                children: [
                  _MemberStack(room: room),
                  const SizedBox(width: 10),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${room.currentMembers}',
                          style: AppTextStyles.hand.copyWith(fontSize: 17),
                        ),
                        TextSpan(
                          text: '/${room.maxMembers}명',
                          style: AppTextStyles.body2,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _ChatButton(chatRoomId: room.chatRoomId, unread: unread),
                ],
              ),
            ],
          ),
        ),
        const Positioned(
          top: -9,
          left: 0,
          right: 0,
          child: Center(child: MaskingTape()),
        ),
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.ink3),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.body2,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// 참여 인원 겹침 표시. 목록 API 는 방장만 내려주므로 나머지는 빈 자리로 그린다.
class _MemberStack extends StatelessWidget {
  final Room room;

  const _MemberStack({required this.room});

  static const double _size = 26;
  static const double _step = 18; // 겹침 후 한 칸 폭

  @override
  Widget build(BuildContext context) {
    final others = (room.currentMembers - 1).clamp(0, 3);
    final count = 1 + others;
    return SizedBox(
      width: _size + (count - 1) * _step,
      height: _size,
      child: Stack(
        children: [
          // 뒤에서부터 쌓아 방장이 맨 앞(왼쪽·위)에 오게 한다.
          for (var i = count - 1; i >= 0; i--)
            Positioned(
              left: i * _step,
              child: i == 0
                  ? InitialAvatar(
                      label: room.host.nickname,
                      size: _size,
                      tone: InitialAvatar.toneFor(room.host.id),
                      imageUrl: room.host.profileImageUrl,
                      ring: true,
                    )
                  : Container(
                      width: _size,
                      height: _size,
                      decoration: BoxDecoration(
                        color: AppColors.fill,
                        borderRadius: BorderRadius.circular(_size * 0.38),
                        border: Border.all(color: AppColors.surface, width: 2),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

class _ChatButton extends StatelessWidget {
  final String? chatRoomId;
  final int unread;

  const _ChatButton({required this.chatRoomId, required this.unread});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: 100,
          height: 38,
          child: GlassButton(
            text: '채팅',
            icon: Icons.chat_bubble_outline_rounded,
            height: 38,
            radius: 12,
            textColor: AppColors.ink,
            onPressed: chatRoomId == null
                ? null
                : () => context.push('/chat/$chatRoomId'),
          ),
        ),
        if (unread > 0)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              constraints: const BoxConstraints(minWidth: 18),
              decoration: BoxDecoration(
                color: AppColors.berry,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                unread > 99 ? '99+' : '$unread',
                style: AppTextStyles.badge,
              ),
            ),
          ),
      ],
    );
  }
}

// ── 예정 모임 없음 — 지난 이력만 있는 유저에게 다음 모임 유도 ──
class _NoUpcomingBox extends StatelessWidget {
  const _NoUpcomingBox();

  @override
  Widget build(BuildContext context) {
    return DashedBox(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      onTap: () => context.go('/rooms'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('예정된 모임이 없어요', style: AppTextStyles.body1Bold),
                const SizedBox(height: 2),
                Text('다음 모임을 찾아볼까요?', style: AppTextStyles.caption),
              ],
            ),
          ),
          Text(
            '모임 찾기 ›',
            style: AppTextStyles.body2.copyWith(color: AppColors.link),
          ),
        ],
      ),
    );
  }
}

// ── 빠른 진입 3칸 ──
class _QuickEntries extends ConsumerWidget {
  final String? nextRoomId;

  const _QuickEntries({required this.nextRoomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _QuickTile(
            icon: Icons.add_rounded,
            label: '모임 만들기',
            onTap: () => openRoomCreate(context, ref),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickTile(
            icon: Icons.place_outlined,
            label: '주변 모임',
            onTap: () => context.go('/map'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickTile(
            icon: Icons.photo_library_outlined,
            label: '사진첩',
            // 다음 모임이 있으면 그 방 사진첩, 없으면 내 모임에서 고르게.
            onTap: () => nextRoomId != null
                ? context.push('/rooms/$nextRoomId/photos')
                : context.go('/my-rooms'),
          ),
        ),
      ],
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: AppColors.ink),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.body2Bold.copyWith(fontSize: 13.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 이번 주 7칸 — 모임 있는 날엔 점, 오늘은 형광펜 자국 ──
class _WeekStrip extends StatelessWidget {
  final DateTime week; // 이번 주 월요일
  final List<String> activeDates;

  const _WeekStrip({required this.week, required this.activeDates});

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final active = activeDates.toSet();
    final now = DateTime.now();
    final todayKey = _key(DateTime(now.year, now.month, now.day));
    final days = [for (var i = 0; i < 7; i++) week.add(Duration(days: i))];

    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: _WeekCell(
              weekday: _weekdays[i],
              date: days[i],
              isToday: _key(days[i]) == todayKey,
              hasRoom: active.contains(_key(days[i])),
            ),
          ),
      ],
    );
  }
}

class _WeekCell extends StatelessWidget {
  final String weekday;
  final DateTime date;
  final bool isToday;
  final bool hasRoom;

  const _WeekCell({
    required this.weekday,
    required this.date,
    required this.isToday,
    required this.hasRoom,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (date.weekday) {
      DateTime.saturday => AppColors.skyInk,
      DateTime.sunday => AppColors.bad,
      _ => AppColors.ink,
    };
    Widget number = Text(
      '${date.day}',
      style: AppTextStyles.handXl.copyWith(fontSize: 22, color: color),
    );
    if (isToday) {
      number = HighlightMark(width: 28, height: 12, child: number);
    }
    return Column(
      children: [
        Text(weekday, style: AppTextStyles.caption),
        const SizedBox(height: 6),
        number,
        const SizedBox(height: 6),
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasRoom ? AppColors.ink : Colors.transparent,
          ),
        ),
      ],
    );
  }
}

// ── 자주 만난 친구 ──
class _FriendsRow extends StatelessWidget {
  final List<FrequentFriend> friends;

  const _FriendsRow({required this.friends});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 102,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: friends.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final f = friends[i];
          return GestureDetector(
            onTap: () => context.push('/users/${f.userId}'),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 62,
              child: Column(
                children: [
                  InitialAvatar(
                    label: f.nickname,
                    size: 48,
                    tone: InitialAvatar.toneFor(f.userId),
                    imageUrl: f.childPhotoUrl ?? f.profileImageUrl,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    f.nickname,
                    style: AppTextStyles.body2Bold,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    '같이 ${f.jointCount}번',
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── 함께한 기록 3칸 — 손글씨 숫자, 칸 사이 점선 세로선 ──
class _RecordsRow extends StatelessWidget {
  final DashboardStats stats;

  const _RecordsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _RecordTile(value: stats.totalRooms, label: '함께한 모임'),
        ),
        const _VerticalDash(),
        Expanded(
          child: _RecordTile(value: stats.uniqueFriends, label: '만난 친구'),
        ),
        const _VerticalDash(),
        Expanded(
          child: _RecordTile(value: stats.uniquePlaces, label: '다녀온 곳'),
        ),
      ],
    );
  }
}

class _RecordTile extends StatelessWidget {
  final int value;
  final String label;

  const _RecordTile({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: AppTextStyles.handXl),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}

/// 기록 칸 사이 점선 세로선.
class _VerticalDash extends StatelessWidget {
  const _VerticalDash();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1,
      height: 44,
      child: CustomPaint(painter: _VerticalDashPainter()),
    );
  }
}

class _VerticalDashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.line2
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    const dash = 4.0, gap = 4.0;
    double y = 0;
    while (y < size.height) {
      final end = (y + dash) > size.height ? size.height : (y + dash);
      canvas.drawLine(Offset(0.5, y), Offset(0.5, end), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _VerticalDashPainter oldDelegate) => false;
}

// ───────────────────────────────────────────────────────────────
// 빈 상태 — 참여 모임 0개.
// ───────────────────────────────────────────────────────────────

class _EmptyDashboard extends ConsumerWidget {
  final Child? child;

  const _EmptyDashboard({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = child?.nickname;

    // 콘텐츠를 (하단 탭 제외 영역의) 세로 중앙에 — RefreshIndicator 가
    // 동작하도록 스크롤러블은 유지한다.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 118),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.fill,
                  borderRadius: BorderRadius.circular(40),
                ),
                alignment: Alignment.center,
                child: const Text('🧸', style: TextStyle(fontSize: 64)),
              ),
              const SizedBox(height: 22),
              if (name != null && name.isNotEmpty) ...[
                Text('$name 부모님,', style: AppTextStyles.body2),
                const SizedBox(height: 6),
              ],
              Text('첫 모임을', style: AppTextStyles.greeting),
              Highlight(child: Text('찾아볼까요?', style: AppTextStyles.greeting)),
              const SizedBox(height: 12),
              Text(
                '같은 동네, 비슷한 또래의 부모님들과\n공동육아를 시작해보세요',
                textAlign: TextAlign.center,
                style: AppTextStyles.body2,
              ),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: PrimaryButton(
                  text: '주변 모임 둘러보기',
                  onPressed: () => context.go('/rooms'),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => openRoomCreate(context, ref),
                child: Text(
                  '직접 모임 만들기',
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// 날짜 · 시간 헬퍼
// ───────────────────────────────────────────────────────────────

/// 'YYYY-MM-DD' → 오늘 기준 남은 일수. 형식이 어긋나면 null.
int? _daysUntil(String date) {
  final d = _parseDate(date);
  if (d == null) return null;
  final now = DateTime.now();
  return d.difference(DateTime(now.year, now.month, now.day)).inDays;
}

DateTime? _parseDate(String date) {
  final parts = date.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

String _dDayStamp(String date) {
  final diff = _daysUntil(date);
  if (diff == null) return 'D-DAY';
  if (diff == 0) return 'D-DAY';
  if (diff < 0) return 'D+${diff.abs()}';
  return 'D-$diff';
}

const _weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];

/// '토 · 9월 13일'
String _weekdayDateLabel(String date) {
  final d = _parseDate(date);
  if (d == null) return date;
  return '${_weekdayNames[d.weekday - 1]} · ${d.month}월 ${d.day}일';
}

String _formatTime(String t) {
  // 서버는 'HH:MM' or 'HH:MM:SS' 로 내려줌.
  final parts = t.split(':');
  if (parts.length < 2) return t;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = parts[1];
  if (h == 0) return '오전 12시 $m분';
  if (h < 12) return '오전 $h시 $m분';
  if (h == 12) return '오후 12시 $m분';
  return '오후 ${h - 12}시 $m분';
}
