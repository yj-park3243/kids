import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/room.dart';
import '../../../models/user.dart';
import '../../../providers/selected_child_provider.dart';
import '../../../widgets/design/accent_blobs.dart';
import '../../../widgets/design/avatar.dart';
import '../../../widgets/design/glass_card.dart';
import '../../../widgets/design/primary_button.dart';
import '../../../widgets/loading.dart';
import '../../auth/providers/auth_provider.dart';
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
        backgroundColor: Colors.transparent,
        body: AccentBlobsBackground(
          child: SafeArea(
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
                                size: 48,
                                color: AppColors.ink500,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '모임 정보를 불러오지 못했어요',
                                style: AppTextStyles.body1.copyWith(
                                  color: AppColors.ink500,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () =>
                                    ref.invalidate(joinedRoomsProvider),
                                child: Text(
                                  '다시 시도',
                                  style: AppTextStyles.buttonSmall.copyWith(
                                    color: AppColors.primary,
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
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AccentBlobsBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(homeState),
              const PinnedNoticeBanner(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  color: AppColors.primary,
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
      ),
    );
  }

  Widget _buildTopBar(HomeState homeState) {
    return Padding(
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
            icon: Icons.add_rounded,
            onTap: () => context.push('/rooms/create'),
          ),
          const SizedBox(width: 8),
          GlassIconButton(
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
// 풀 대시보드 — 참여 모임이 1+ 일 때. "우리 아이 활동 일지" 컨셉.
// 모임 탭(공간/탐색)과 차별화 — 시간/기록/추억 중심.
// ───────────────────────────────────────────────────────────────

class _FullDashboard extends StatelessWidget {
  final Child? child;
  final List<Room> joinedRooms;
  final DashboardSummary summary;

  const _FullDashboard({
    required this.child,
    required this.joinedRooms,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    // 다음 약속 — 오늘 이후의 미래 모임 중 가장 가까운 것.
    final upcoming = _findNextRoom(joinedRooms);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
      children: [
        _GreetingHeader(child: child, stats: summary.stats),
        const SizedBox(height: 16),
        if (upcoming != null) ...[
          _NextAppointmentCard(room: upcoming),
          const SizedBox(height: 18),
        ] else ...[
          // 지난 이력만 있고 예정 모임이 없는 경우 — 다음 모임 유도.
          _NoUpcomingCard(),
          const SizedBox(height: 18),
        ],
        _StatsRow(stats: summary.stats),
        const SizedBox(height: 22),
        if (summary.recentPhotos.isNotEmpty) ...[
          _SectionTitle(title: '최근 추억'),
          const SizedBox(height: 10),
          _RecentPhotosRow(photos: summary.recentPhotos),
          const SizedBox(height: 22),
        ],
        if (summary.frequentFriends.isNotEmpty) ...[
          _SectionTitle(title: '자주 만난 친구'),
          const SizedBox(height: 10),
          _FriendsRow(friends: summary.frequentFriends),
          const SizedBox(height: 22),
        ],
        _SectionTitle(title: '이번 달 활동'),
        const SizedBox(height: 10),
        _MonthlyCalendar(activeDates: summary.monthlyDates),
        const SizedBox(height: 22),
        _MilestoneStrip(stats: summary.stats),
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
}

// ── 인사 헤더 — 누적 참여 카운트로 "기록" 분위기 ──
class _GreetingHeader extends StatelessWidget {
  final Child? child;
  final DashboardStats stats;

  const _GreetingHeader({required this.child, required this.stats});

  // 한글 음절의 마지막 글자에 종성(받침)이 있는지. 한글이 아니면 false.
  static bool _hasJongseong(String s) {
    if (s.isEmpty) return false;
    final code = s.runes.last - 0xAC00;
    if (code < 0 || code > 11171) return false;
    return code % 28 != 0;
  }

  @override
  Widget build(BuildContext context) {
    final name = child?.nickname ?? '우리 아이';
    final n = stats.totalRooms;
    // 받침 있는 이름엔 '이'를 붙여 호격을 자연스럽게: '민준이의' / '하율의'.
    final possessive = _hasJongseong(name) ? '$name이의' : '$name의';
    final greeting = n == 0 ? '첫 모임이 곧 시작돼요' : '$possessive $n번째 모임이에요';
    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(
        children: [
          Text(
            child?.gender == 'MALE' ? '👦' : '👧',
            style: const TextStyle(fontSize: 28),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              greeting,
              style: AppTextStyles.cardTitle.copyWith(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 예정 모임 없음 카드 — 지난 이력만 있는 유저에게 다음 모임 유도 ──
class _NoUpcomingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(
        children: [
          const Text('📅', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('예정된 모임이 없어요', style: AppTextStyles.cardTitle),
                const SizedBox(height: 2),
                Text('다음 모임을 찾아볼까요?', style: AppTextStyles.caption),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.go('/rooms'),
            child: Text(
              '둘러보기',
              style: AppTextStyles.buttonSmall.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 다음 약속 카드 — D-day + 장소 + 시간 ──
class _NextAppointmentCard extends StatelessWidget {
  final Room room;

  const _NextAppointmentCard({required this.room});

  @override
  Widget build(BuildContext context) {
    final dDay = _dDayLabel(room.date);
    final place = (room.placeName?.isNotEmpty ?? false)
        ? room.placeName!
        : '장소 미정';
    return GestureDetector(
      onTap: () => context.push('/rooms/${room.id}'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.accentLavender],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    dDay,
                    style: AppTextStyles.captionBold.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '다음 약속',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              room.title,
              style: AppTextStyles.heading2.copyWith(
                color: Colors.white,
                fontSize: 18,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  '${_formatDate(room.date)} · ${_formatTime(room.startTime)}',
                  style: AppTextStyles.body2.copyWith(
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.place_rounded, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    place,
                    style: AppTextStyles.body2.copyWith(
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _dDayLabel(String date) {
    final parts = date.split('-');
    if (parts.length != 3) return '';
    final d = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = d.difference(today).inDays;
    if (diff == 0) return '오늘';
    if (diff == 1) return '내일';
    if (diff < 0) return 'D+${diff.abs()}';
    return 'D-$diff';
  }

  static String _formatDate(String date) {
    final parts = date.split('-');
    if (parts.length != 3) return date;
    return '${int.parse(parts[1])}월 ${int.parse(parts[2])}일';
  }

  static String _formatTime(String t) {
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
}

// ── 누적 카운터 3개 (모임 / 친구 / 장소) ──
class _StatsRow extends StatelessWidget {
  final DashboardStats stats;

  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            emoji: '🧸',
            value: '${stats.totalRooms}',
            label: '함께한 모임',
            tone: AppColors.primary100,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            emoji: '🤝',
            value: '${stats.uniqueFriends}',
            label: '만난 친구',
            tone: AppColors.accentLavender.withValues(alpha: 0.3),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            emoji: '📍',
            value: '${stats.uniquePlaces}',
            label: '다녀온 곳',
            tone: AppColors.primary100,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final Color tone;

  const _StatTile({
    required this.emoji,
    required this.value,
    required this.label,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone, width: 1),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(value, style: AppTextStyles.heading2.copyWith(fontSize: 18)),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: AppColors.ink500),
          ),
        ],
      ),
    );
  }
}

// ── 최근 사진 가로 스크롤 ──
class _RecentPhotosRow extends StatelessWidget {
  final List<RecentPhoto> photos;

  const _RecentPhotosRow({required this.photos});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final p = photos[i];
          return GestureDetector(
            onTap: () => context.push('/rooms/${p.roomId}'),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                p.url,
                width: 96,
                height: 96,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 96,
                  height: 96,
                  color: AppColors.surfaceVariant,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textHint,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── 자주 만난 친구 갤러리 ──
class _FriendsRow extends StatelessWidget {
  final List<FrequentFriend> friends;

  const _FriendsRow({required this.friends});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: friends.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final f = friends[i];
          return GestureDetector(
            onTap: () => context.push('/users/${f.userId}'),
            child: SizedBox(
              width: 84,
              child: Column(
                children: [
                  InitialAvatar(
                    label: f.nickname.isNotEmpty
                        ? f.nickname.substring(0, 1)
                        : '?',
                    size: 56,
                    tone: AvatarTone.lilac,
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
                  const SizedBox(height: 2),
                  Text(
                    '같이 ${f.jointCount}번',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary700,
                    ),
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

// ── 이번 달 캘린더 — 모임 있는 날에 점 ──
class _MonthlyCalendar extends StatelessWidget {
  final List<String> activeDates;

  const _MonthlyCalendar({required this.activeDates});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final leadingBlanks =
        firstDay.weekday % 7; // 일요일 시작 — DateTime.weekday 는 월=1, 일=7
    final cellCount = leadingBlanks + daysInMonth;
    final rows = (cellCount / 7).ceil();

    final activeSet = activeDates.toSet();
    String key(int d) =>
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';

    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${now.year}년 ${now.month}월', style: AppTextStyles.body2Bold),
          const SizedBox(height: 10),
          Row(
            children: const ['일', '월', '화', '수', '목', '금', '토']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.ink500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 6),
          ...List.generate(rows, (row) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: List.generate(7, (col) {
                  final idx = row * 7 + col;
                  final dayNum = idx - leadingBlanks + 1;
                  if (idx < leadingBlanks || dayNum > daysInMonth) {
                    return const Expanded(child: SizedBox(height: 30));
                  }
                  final isActive = activeSet.contains(key(dayNum));
                  final isToday = dayNum == now.day;
                  return Expanded(
                    child: Center(
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive
                              ? AppColors.primary
                              : (isToday
                                    ? AppColors.primary100
                                    : Colors.transparent),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$dayNum',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isActive
                                ? Colors.white
                                : (isToday
                                      ? AppColors.primary700
                                      : AppColors.ink700),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── 마일스톤 배지 (totalRooms / uniqueFriends / uniquePlaces 기반) ──
class _MilestoneStrip extends StatelessWidget {
  final DashboardStats stats;

  const _MilestoneStrip({required this.stats});

  @override
  Widget build(BuildContext context) {
    final badges = _earnedBadges(stats);
    if (badges.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: '받은 도장'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: badges
              .map(
                (b) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary200, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(b.emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(
                        b.label,
                        style: AppTextStyles.body2Bold.copyWith(
                          color: AppColors.primary700,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  static List<_Badge> _earnedBadges(DashboardStats s) {
    final out = <_Badge>[];
    if (s.totalRooms >= 1) out.add(const _Badge('🎉', '첫 모임'));
    if (s.totalRooms >= 5) out.add(const _Badge('🌟', '5번째 모임'));
    if (s.totalRooms >= 10) out.add(const _Badge('✨', '10번째 모임'));
    if (s.totalRooms >= 25) out.add(const _Badge('🏅', '단골 부모'));
    if (s.totalRooms >= 50) out.add(const _Badge('👑', '동네 코어'));
    if (s.uniqueFriends >= 5) out.add(const _Badge('🤝', '친구 5명'));
    if (s.uniqueFriends >= 10) out.add(const _Badge('💞', '친구 10명'));
    if (s.uniquePlaces >= 5) out.add(const _Badge('🗺️', '5곳 탐험'));
    return out;
  }
}

class _Badge {
  final String emoji;
  final String label;
  const _Badge(this.emoji, this.label);
}

// ───────────────────────────────────────────────────────────────
// 빈 상태 — 참여 모임 0개.
// ───────────────────────────────────────────────────────────────

class _EmptyDashboard extends StatelessWidget {
  final Child? child;

  const _EmptyDashboard({required this.child});

  @override
  Widget build(BuildContext context) {
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
              // 큰 일러스트 (이모지) — 시각적 무게중심.
              Center(
                child: Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary100,
                        AppColors.accentLavender.withValues(alpha: 0.35),
                      ],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🧸', style: TextStyle(fontSize: 72)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                name != null ? '$name 부모님,\n첫 모임을 찾아볼까요?' : '첫 모임을 찾아볼까요?',
                textAlign: TextAlign.center,
                style: AppTextStyles.heading2.copyWith(height: 1.35),
              ),
              const SizedBox(height: 8),
              Text(
                '같은 동네, 비슷한 또래의 부모님들과\n공동육아를 시작해보세요',
                textAlign: TextAlign.center,
                style: AppTextStyles.body2.copyWith(color: AppColors.ink500),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: PrimaryButton(
                  text: '주변 모임 둘러보기',
                  onPressed: () => context.go('/rooms'),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () => context.push('/rooms/create'),
                  child: Text(
                    '직접 모임 만들기',
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.primary700,
                      fontWeight: FontWeight.w700,
                    ),
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
// 공용 위젯
// ───────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppTextStyles.sectionHead.copyWith(fontSize: 16));
  }
}
