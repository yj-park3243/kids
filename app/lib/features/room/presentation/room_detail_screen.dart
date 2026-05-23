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

  const RoomDetailScreen({super.key, required this.roomId});

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
          appBar: const CustomAppBar(title: ''),
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
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: room.title,
        backgroundColor: AppColors.background,
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
        padding: const EdgeInsets.only(top: 12, bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Flash meeting strip
            if (room.isFlashMeeting)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFC0AC), AppColors.accentCoral],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '⚡ 번개 모임 · 24시간 이내',
                      style: AppTextStyles.body2Bold
                          .copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges row: place type + category
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          AppConstants.placeTypes[room.placeType] ?? '기타',
                          style: AppTextStyles.captionBold
                              .copyWith(color: AppColors.secondary),
                        ),
                      ),
                      CategoryBadge(
                        genderFilter: room.genderFilter,
                        singleParentOnly: room.singleParentOnly,
                      ),
                    ],
                  ),
                  if (room.description != null && room.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        room.description!,
                        style: AppTextStyles.body2.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Info section
            _InfoSection(room: room, isParticipant: isParticipant),

            const SizedBox(height: 16),

            // Map preview — 참여자에게만 노출.
            if (isParticipant && room.latitude != null && room.longitude != null)
              _MapSection(room: room),

            // 비참여자 안내 박스
            if (!isParticipant)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: _LocationLockedBox(),
              ),

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

class _InfoSection extends ConsumerWidget {
  final Room room;
  final bool isParticipant;

  const _InfoSection({required this.room, required this.isParticipant});

  /// 비참여자: 동 단위까지만. 참여자: placeName/address 우선.
  String get _locationValue {
    if (isParticipant) {
      return room.placeName ?? room.placeAddress ?? room.regionDong;
    }
    return room.regionDong;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 거리 — 참여 중이 아닌 방만, 내 위치가 있을 때.
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
        children: [
          _InfoRow(
            icon: Icons.calendar_today_rounded,
            label: '날짜',
            value: AppDateUtils.formatDate(room.date),
          ),
          const Divider(height: 20, color: AppColors.divider),
          _InfoRow(
            icon: Icons.access_time_rounded,
            label: '시간',
            value:
                '${AppDateUtils.formatTime(room.startTime)}${room.endTime != null ? ' ~ ${AppDateUtils.formatTime(room.endTime!)}' : ''}',
          ),
          const Divider(height: 20, color: AppColors.divider),
          _InfoRow(
            icon: Icons.location_on_rounded,
            label: '장소',
            value: _locationValue,
            trailing: isParticipant &&
                    room.latitude != null &&
                    room.longitude != null
                ? _NavigateButton(room: room)
                : null,
          ),
          const Divider(height: 20, color: AppColors.divider),
          if (distanceText != null) ...[
            _InfoRow(
              icon: Icons.near_me_rounded,
              label: '거리',
              value: '내 위치에서 약 $distanceText',
            ),
            const Divider(height: 20, color: AppColors.divider),
          ],
          _InfoRow(
            icon: Icons.child_care_rounded,
            label: '대상',
            value: '${room.ageMonthMin}~${room.ageMonthMax}개월',
          ),
          const Divider(height: 20, color: AppColors.divider),
          _InfoRow(
            icon: Icons.people_rounded,
            label: '인원',
            value: '${room.currentMembers}/${room.maxMembers}명',
          ),
          const Divider(height: 20, color: AppColors.divider),
          _InfoRow(
            icon: Icons.payment_rounded,
            label: '비용',
            value: room.isFree
                ? '무료'
                : '${AppDateUtils.formatCostDisplay(room.cost)}${room.costDescription != null ? ' (${room.costDescription})' : ''}',
          ),
          const Divider(height: 20, color: AppColors.divider),
          _InfoRow(
            icon: Icons.how_to_reg_rounded,
            label: '입장',
            value: room.isApprovalRequired ? '승인 필요' : '자유 입장',
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          child: Text(label, style: AppTextStyles.caption),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value, style: AppTextStyles.body2Bold),
        ),
        if (trailing != null) trailing!,
      ],
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
