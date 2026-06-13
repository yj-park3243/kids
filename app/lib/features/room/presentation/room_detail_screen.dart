import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pull_down_button/pull_down_button.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../support/presentation/report_sheet.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/location/location_service.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/room.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/common_button.dart';
import '../../../widgets/design/accent_blobs.dart';
import '../../../widgets/design/glass_card.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading.dart';
import '../../auth/providers/auth_provider.dart';
import '../../mypage/providers/block_provider.dart';
import '../../review/presentation/review_write_screen.dart' show ReviewMember;
import '../providers/room_detail_provider.dart';
import 'widgets/category_badge.dart';
// TODO: KakaoShareService 통합 (App-Features-B 담당)
// import '../../../core/share/kakao_share_service.dart';

class RoomDetailScreen extends ConsumerStatefulWidget {
  final String roomId;
  // 기본은 표시. 지도 단일 핀 → 상세 흐름만 false 를 넘긴다.
  final bool showBack;

  const RoomDetailScreen({
    super.key,
    required this.roomId,
    this.showBack = true,
  });

  @override
  ConsumerState<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends ConsumerState<RoomDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(roomDetailProvider(widget.roomId).notifier).loadRoom();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roomDetailProvider(widget.roomId));
    final authState = ref.watch(authProvider);
    final currentUserId = authState.user?.id;

    // room 이 아직 없으면 본문을 그리지 않는다. isLoading 플래그와 무관하게
    // room == null 이면 항상 early return — 로드 전 초기 프레임
    // (isLoading=false, error=null, room=null)에서 state.room! 가 크래시하던
    // 것을 방지한다.
    if (state.room == null) {
      if (state.error != null) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: CustomAppBar(title: '', showBack: widget.showBack),
          extendBodyBehindAppBar: true,
          body: AccentBlobsBackground(
            child: SafeArea(
              child: ErrorState(
                message: state.error!,
                onRetry: () => ref
                    .read(roomDetailProvider(widget.roomId).notifier)
                    .loadRoom(),
              ),
            ),
          ),
        );
      }
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: AccentBlobsBackground(child: AppLoadingIndicator()),
      );
    }

    final room = state.room!;
    final isHost = room.host.id == currentUserId;
    final isAccepted = room.myStatus == 'ACCEPTED';
    final isPending = room.myStatus == 'PENDING';
    final isParticipant = isHost || isAccepted;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(
        title: room.title,
        showBack: widget.showBack,
        actions: [
          IconButton(
            icon:
                const Icon(Icons.share_rounded, color: AppColors.textPrimary),
            tooltip: '공유',
            onPressed: () => _shareRoom(room),
          ),
          IconButton(
            icon: const Icon(Icons.photo_library_outlined,
                color: AppColors.textPrimary),
            tooltip: '사진첩',
            onPressed: () => context.push('/rooms/${widget.roomId}/photos'),
          ),
          PullDownButton(
            itemBuilder: (context) => [
              if (isHost && room.isApprovalRequired)
                PullDownMenuItem(
                  title: '참여 관리',
                  icon: Icons.group_rounded,
                  onTap: () =>
                      context.push('/rooms/${widget.roomId}/requests'),
                ),
              if (isHost && room.status != 'COMPLETED')
                PullDownMenuItem(
                  title: '모임 종료',
                  icon: Icons.event_available_rounded,
                  onTap: () => _completeRoom(room),
                ),
              if (isHost)
                PullDownMenuItem(
                  title: '모임 취소',
                  icon: Icons.cancel_outlined,
                  isDestructive: true,
                  onTap: () => _cancelRoom(room),
                ),
              // 방장·참여자 모두 — 방 안의 특정 유저를 골라 신고/차단.
              PullDownMenuItem(
                title: '신고 / 차단',
                icon: Icons.flag_outlined,
                isDestructive: true,
                onTap: () {
                  final targets = <ReportTarget>[
                    ReportTarget(label: '방 자체', roomId: widget.roomId),
                    ...?room.members
                        ?.where((m) => m.id != currentUserId)
                        .map((m) => ReportTarget(
                              label: m.nickname,
                              userId: m.id,
                              isHost: m.isHost,
                            )),
                  ];
                  showReportSheet(
                    context,
                    targetRoomId: widget.roomId,
                    targets: targets,
                  );
                },
              ),
            ],
            buttonBuilder: (context, showMenu) => IconButton(
              onPressed: showMenu,
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
      body: AccentBlobsBackground(
        child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 풀폭 그라데이션 히어로 — 칩 + 큰 제목 + 일시·동을 한눈에.
            _RoomHero(room: room),

            // 카테고리 배지(엄마만/아빠만/한부모) — 히어로 칩과 색상 의미가
            // 다르니 본문 위쪽에 별도로 노출.
            if (room.genderFilter != 'ALL' || room.singleParentOnly)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: CategoryBadge(
                  genderFilter: room.genderFilter,
                  singleParentOnly: room.singleParentOnly,
                ),
              ),

            // 설명 — 별도 카드.
            if (room.description != null &&
                room.description!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: GlassCard(
                  radius: 16,
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    room.description!,
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // 1) 장소 — 참여자에겐 정확한 주소, 비참여자에겐 잠금 안내.
            if (isParticipant)
              _LocationCard(room: room)
            else
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: _LocationLockedBox(),
              ),

            const SizedBox(height: 12),

            // 3) 메타 칩들 — 연령/인원/비용/입장/거리. 텍스트 줄 8개 → 칩 5개.
            _MetaChipsRow(room: room, isParticipant: isParticipant),

            const SizedBox(height: 16),

            // 4) 지도 미리보기 — 참여자에게만.
            if (isParticipant && room.latitude != null && room.longitude != null)
              _MapSection(room: room),

            const SizedBox(height: 16),

            // Required items
            if (room.requiredItems.isNotEmpty) ...[
              _RequiredItemsCard(items: room.requiredItems),
              const SizedBox(height: 16),
            ],

            // Members
            _MembersSection(room: room),

            // Tags
            if (room.tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: room.tags
                      .map((tag) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('#$tag', style: AppTextStyles.tag),
                          ))
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
      ),
      bottomNavigationBar: _BottomBar(
        room: room,
        isHost: isHost,
        isAccepted: isAccepted,
        isPending: isPending,
        isJoining: state.isJoining,
        onJoin: () => _joinRoom(),
        onChat: () {
          if (room.chatRoomId != null) {
            context.push('/chat/${room.chatRoomId}');
          }
        },
        onReview: () {
          // 본인을 제외한 멤버 → ReviewMember 변환.
          final me = ref.read(authProvider).user?.id;
          final targets = (room.members ?? [])
              .where((m) => m.id != me)
              .map((m) => ReviewMember(
                    id: m.id,
                    nickname: m.nickname,
                    profileImageUrl: m.profileImageUrl,
                  ))
              .toList();
          if (targets.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('후기를 작성할 대상 멤버가 없어요')),
            );
            return;
          }
          context.push('/reviews/write?roomId=${widget.roomId}',
              extra: targets);
        },
      ),
    );
  }

  Future<void> _joinRoom() async {
    try {
      final result = await ref
          .read(roomDetailProvider(widget.roomId).notifier)
          .joinRoom();
      if (mounted) {
        final status = result?['status'];
        final msg = status == 'ACCEPTED'
            ? '참여가 완료되었습니다!'
            : '참여 신청이 완료되었습니다. 방장의 수락을 기다려 주세요.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('참여 신청에 실패했습니다'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _shareRoom(Room room) {
    // TODO: KakaoShareService().shareRoom(room); — App-Features-B 통합
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('공유 기능 준비 중'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _cancelRoom(Room room) async {
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('모임 취소'),
        message: const Text('정말로 이 모임을 취소하시겠습니까?\n참여자 전원에게 알림이 발송됩니다.'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('모임 취소하기'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('닫기'),
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(roomRepositoryProvider).cancelRoom(widget.roomId);
        if (mounted) {
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('모임 취소에 실패했습니다'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }

  /// 모임 종료 — 방장 전용. 확인 후 상태를 COMPLETED 로 전환.
  Future<void> _completeRoom(Room room) async {
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('모임 종료'),
        message: const Text(
            '이 모임을 종료할까요?\n종료하면 출석 체크와 후기 작성이 가능해집니다.'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('모임 종료하기'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('닫기'),
        ),
      ),
    );

    if (confirmed != true) return;
    try {
      await ref.read(roomRepositoryProvider).completeRoom(widget.roomId);
      if (mounted) {
        ref.read(roomDetailProvider(widget.roomId).notifier).loadRoom();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('모임이 종료되었습니다'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('모임 종료에 실패했습니다'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }
}

/// 상단 풀폭 히어로 — 그라데이션 배경에 칩 묶음 + 큰 제목 + 일시/지역.
/// 일시 정보가 여기 들어가서 별도 일시 카드는 제거됐다.
class _RoomHero extends StatelessWidget {
  final Room room;
  const _RoomHero({required this.room});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight;
    final timeText = AppDateUtils.formatTime(room.startTime) +
        (room.endTime != null
            ? ' ~ ${AppDateUtils.formatTime(room.endTime!)}'
            : '');
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, topPad + 4, 24, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _heroColors(room.ageMonthMin),
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 칩 묶음 — 번개 / 장소 / 연령 / 모집중.
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (room.isFlashMeeting) _heroChip('⚡ 번개', highlighted: true),
              _heroChip(AppConstants.placeTypes[room.placeType] ?? '기타'),
              _heroChip('${room.ageMonthMin}~${room.ageMonthMax}개월'),
              if (room.status == 'RECRUITING') _heroChip('모집중'),
            ],
          ),
          const SizedBox(height: 14),
          // 큰 제목 — 첫 화면 시선 잡이.
          Text(
            room.title,
            style: AppTextStyles.heading1.copyWith(
              color: Colors.white,
              fontSize: 24,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 14),
          // 일시 — 날짜 + 시간 한 줄.
          _heroInfoRow(
            Icons.event_rounded,
            '${AppDateUtils.formatDate(room.date)} · $timeText',
          ),
          if (room.regionDong.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            _heroInfoRow(
              Icons.location_on_rounded,
              [
                if ((room.regionSigungu ?? '').trim().isNotEmpty)
                  room.regionSigungu!,
                room.regionDong,
              ].join(' · '),
            ),
          ],
        ],
      ),
    );
  }

  Widget _heroInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.95)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _heroChip(String label, {bool highlighted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:
            highlighted ? Colors.white : Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: highlighted
            ? null
            : Border.all(color: Colors.white.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: highlighted ? AppColors.primaryDark : Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // 카드와 같은 나이 → 색 매핑. 톤은 카드보다 약간 진하게.
  List<Color> _heroColors(int age) {
    if (age < 6) return const [Color(0xFFF26E96), Color(0xFFD14B73)];
    if (age < 12) return const [Color(0xFFD14B73), Color(0xFFA63A5C)];
    if (age < 24) return const [Color(0xFFB89BE8), Color(0xFF9176CC)];
    if (age < 36) return const [Color(0xFF9176CC), Color(0xFF7E3FA0)];
    return const [Color(0xFFFF9476), Color(0xFFE07560)];
  }
}

/// 1) 장소 카드 — 참여자 전용. 이름/주소 강조 + 길찾기 버튼.
class _LocationCard extends StatelessWidget {
  final Room room;
  const _LocationCard({required this.room});

  @override
  Widget build(BuildContext context) {
    final placeName =
        room.placeName ?? room.placeAddress ?? room.regionDong;
    final hasAddress = room.placeAddress != null &&
        room.placeName != null &&
        room.placeAddress != room.placeName;
    final canNavigate = room.latitude != null && room.longitude != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.place_rounded,
                color: AppColors.secondary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(placeName, style: AppTextStyles.body1Bold),
                if (hasAddress) ...[
                  const SizedBox(height: 2),
                  Text(
                    room.placeAddress!,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          if (canNavigate) ...[
            const SizedBox(width: 8),
            _NavigateButton(room: room),
          ],
        ],
      ),
    );
  }
}

/// 3) 메타 칩 — 연령/인원/비용/입장/거리. Wrap 으로 자연스럽게 흐름.
class _MetaChipsRow extends ConsumerWidget {
  final Room room;
  final bool isParticipant;
  const _MetaChipsRow({required this.room, required this.isParticipant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 거리 — 비참여자, 좌표 있고 내 위치 있을 때만.
    String? distanceText;
    if (!isParticipant &&
        room.latitude != null &&
        room.longitude != null) {
      final myPos = ref.watch(currentPositionProvider).valueOrNull;
      if (myPos != null) {
        distanceText = formatDistance(distanceKm(
          myPos.latitude,
          myPos.longitude,
          room.latitude!,
          room.longitude!,
        ));
      }
    }

    // 인원 상태색 — 마감 회색, 임박(80%↑) 코랄, 아니면 primary.
    final ratio = room.maxMembers == 0
        ? 0.0
        : room.currentMembers / room.maxMembers;
    final memberColor = room.isFull
        ? const Color(0xFF9AA0A6)
        : (ratio >= 0.8 ? AppColors.accentCoral : AppColors.primary);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _MetaChip(
            icon: Icons.child_care_rounded,
            label: '${room.ageMonthMin}~${room.ageMonthMax}개월',
            color: AppColors.secondary,
          ),
          _MetaChip(
            icon: Icons.people_rounded,
            label: '${room.currentMembers}/${room.maxMembers}명',
            color: memberColor,
            filled: true,
          ),
          _MetaChip(
            icon: room.isFree
                ? Icons.volunteer_activism_rounded
                : Icons.payments_rounded,
            label: room.isFree
                ? '무료'
                : (room.costDescription != null &&
                        room.costDescription!.isNotEmpty
                    ? '${AppDateUtils.formatCostDisplay(room.cost)} · ${room.costDescription}'
                    : AppDateUtils.formatCostDisplay(room.cost)),
            color: room.isFree
                ? AppColors.success
                : AppColors.textPrimary,
          ),
          _MetaChip(
            icon: room.isApprovalRequired
                ? Icons.lock_rounded
                : Icons.lock_open_rounded,
            label: room.isApprovalRequired ? '승인 필요' : '자유 입장',
            color: AppColors.textSecondary,
          ),
          if (distanceText != null)
            _MetaChip(
              icon: Icons.near_me_rounded,
              label: distanceText,
              color: AppColors.primary,
            ),
        ],
      ),
    );
  }
}

/// 메타 칩 — 아이콘 + 라벨. filled=true 면 색 배경 강조.
class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = filled ? color.withValues(alpha: 0.12) : AppColors.surface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: filled
              ? color.withValues(alpha: 0.25)
              : AppColors.divider,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigateButton extends StatelessWidget {
  final Room room;

  const _NavigateButton({required this.room});

  Future<void> _openNaverMaps(BuildContext context) async {
    final lat = room.latitude!;
    final lng = room.longitude!;
    final name = Uri.encodeComponent(
        room.placeName ?? room.placeAddress ?? room.title);
    // 네이버 지도 길찾기 (목적지 좌표)
    final appUri = Uri.parse(
        'nmap://route/public?dlat=$lat&dlng=$lng&dname=$name&appname=com.growtogether.kids');
    final webUri = Uri.parse(
        'https://map.naver.com/v5/directions/-/-/$lng,$lat,$name/-/transit?c=15,0,0,0,dh');

    try {
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => _openNaverMaps(context),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: const Icon(Icons.directions_rounded,
          size: 16, color: AppColors.primary),
      label: Text(
        '길찾기',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LocationLockedBox extends StatelessWidget {
  const _LocationLockedBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded,
              size: 18, color: AppColors.textHint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '참여 확정 후 정확한 장소가 공개됩니다',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequiredItemsCard extends StatelessWidget {
  final List<String> items;

  const _RequiredItemsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('준비물', style: AppTextStyles.body1Bold),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_box_outline_blank_rounded,
                      size: 18, color: AppColors.textHint),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(item, style: AppTextStyles.body2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapSection extends StatelessWidget {
  final Room room;

  const _MapSection({required this.room});

  NLatLng get _target => NLatLng(room.latitude!, room.longitude!);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => _openFullscreen(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 180,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AbsorbPointer(
                  child: NaverMap(
                    options: NaverMapViewOptions(
                      initialCameraPosition:
                          NCameraPosition(target: _target, zoom: 15),
                      scrollGesturesEnable: false,
                      zoomGesturesEnable: false,
                      tiltGesturesEnable: false,
                      rotationGesturesEnable: false,
                      logoClickEnable: false,
                    ),
                    onMapReady: (controller) {
                      controller.addOverlay(
                        NMarker(id: 'room_${room.id}', position: _target),
                      );
                    },
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.fullscreen_rounded,
                            color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          '크게 보기',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openFullscreen(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenMap(target: _target, title: room.placeAddress ?? room.title),
      ),
    );
  }
}

class _FullscreenMap extends StatelessWidget {
  const _FullscreenMap({required this.target, required this.title});

  final NLatLng target;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: NaverMap(
        options: NaverMapViewOptions(
          initialCameraPosition: NCameraPosition(target: target, zoom: 16),
          locationButtonEnable: true,
        ),
        onMapReady: (controller) async {
          controller.addOverlay(NMarker(id: 'fs_marker', position: target));
          // 내 위치 오버레이 표시.
          final pos = await LocationService.instance.getCurrentPosition();
          if (pos != null) {
            final overlay = controller.getLocationOverlay();
            overlay.setPosition(NLatLng(pos.latitude, pos.longitude));
            overlay.setIsVisible(true);
          }
        },
      ),
    );
  }
}

class _MembersSection extends ConsumerWidget {
  final Room room;

  const _MembersSection({required this.room});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = room.members ?? [];
    final myId = ref.watch(authProvider).user?.id;
    final blockedIds = ref
            .watch(blockedUsersProvider)
            .valueOrNull
            ?.map((b) => b.targetUserId)
            .toSet() ??
        <String>{};

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '참여자 (${room.currentMembers}/${room.maxMembers})',
            style: AppTextStyles.body1Bold,
          ),
          const SizedBox(height: 12),
          ...members.map((member) {
            final isMe = member.id == myId;
            final isBlocked = blockedIds.contains(member.id);
            return GestureDetector(
              onTap: isMe ? null : () => context.push('/users/${member.id}'),
              onLongPress: isMe
                  ? null
                  : () => showReportSheet(context, targetUserId: member.id),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.surfaceVariant,
                      backgroundImage: member.profileImageUrl != null
                          ? NetworkImage(member.profileImageUrl!)
                          : null,
                      child: member.profileImageUrl == null
                          ? const Icon(Icons.person_rounded,
                              color: AppColors.textHint, size: 20)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(member.nickname,
                                  style: AppTextStyles.body2Bold),
                              if (isBlocked) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.error
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    '차단함',
                                    style: AppTextStyles.caption.copyWith(
                                      fontSize: 9,
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                              if (member.isHost) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.accent.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    '방장',
                                    style: AppTextStyles.caption.copyWith(
                                      fontSize: 9,
                                      color: AppColors.accentDark,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                              // 한부모 배지는 singleParentOnly 방에서만, 그리고
                              // 멤버의 isSingleParent 응답이 true일 때만 표시.
                              if (room.singleParentOnly &&
                                  member.isSingleParent == true) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.lilac.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    '🤍 한부모',
                                    style: AppTextStyles.caption.copyWith(
                                      fontSize: 9,
                                      color: AppColors.secondaryDark,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          // 부모 성별 + 출생연도 (예: 아빠 (92년생))
                          if (member.parentGender != null)
                            Text(
                              '${member.parentGender == 'DAD' ? '아빠' : '엄마'}'
                              '${member.birthYear != null ? ' (${(member.birthYear! % 100).toString().padLeft(2, '0')}년생)' : ''}',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          if (member.children != null &&
                              member.children!.isNotEmpty)
                            Text(
                              member.children!
                                  .map((c) =>
                                      '${c.nickname}(${AppDateUtils.formatAgeMonths(c.ageMonths ?? 0)})')
                                  .join(', '),
                              style: AppTextStyles.caption,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final Room room;
  final bool isHost;
  final bool isAccepted;
  final bool isPending;
  final bool isJoining;
  final VoidCallback onJoin;
  final VoidCallback onChat;
  final VoidCallback onReview;

  const _BottomBar({
    required this.room,
    required this.isHost,
    required this.isAccepted,
    required this.isPending,
    required this.isJoining,
    required this.onJoin,
    required this.onChat,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: _buildButton(),
    );
  }

  Widget _buildButton() {
    if (isHost || isAccepted) {
      // 모임 종료 후 — 채팅 + 후기 작성 두 버튼 노출.
      if (room.status == 'COMPLETED') {
        return Row(
          children: [
            Expanded(
              child: SecondaryButton(
                key: const Key('btn-room-detail-chat'),
                text: '채팅방',
                icon: Icons.chat_bubble_outline_rounded,
                onPressed: onChat,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PrimaryButton(
                key: const Key('btn-room-detail-review'),
                text: '후기 작성',
                icon: Icons.rate_review_rounded,
                onPressed: onReview,
              ),
            ),
          ],
        );
      }
      return PrimaryButton(
        key: const Key('btn-room-detail-chat'),
        text: '채팅방 입장',
        icon: Icons.chat_bubble_rounded,
        onPressed: onChat,
      );
    }

    if (isPending) {
      return SecondaryButton(
        text: '승인 대기 중',
        icon: Icons.hourglass_empty_rounded,
      );
    }

    if (!room.isRecruiting) {
      return PrimaryButton(
        text: '모집이 마감되었습니다',
        isEnabled: false,
        onPressed: null,
      );
    }

    if (room.isFull) {
      return PrimaryButton(
        text: '인원이 꽉 찼습니다',
        isEnabled: false,
        onPressed: null,
      );
    }

    if (room.canJoin == false) {
      return PrimaryButton(
        text: room.canJoinReason ?? '참여할 수 없습니다',
        isEnabled: false,
        onPressed: null,
      );
    }

    return PrimaryButton(
      key: const Key('btn-room-detail-join'),
      text: room.isApprovalRequired ? '참여 신청' : '참여하기',
      isLoading: isJoining,
      onPressed: onJoin,
    );
  }
}
