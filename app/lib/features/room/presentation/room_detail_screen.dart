import '../../auth/phone_verification_gate.dart';
import '../../../widgets/top_toast.dart';
import 'package:flutter/cupertino.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
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
import '../../../core/network/api_error.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/room.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/design/avatar.dart';
import '../../../widgets/design/design_chip.dart';
import '../../../widgets/design/notebook.dart';
import '../../../widgets/design/primary_button.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/providers/chat_provider.dart';
import '../../mypage/providers/block_provider.dart';
import '../../review/presentation/review_write_screen.dart' show ReviewMember;
import '../../home/providers/dashboard_provider.dart';
import '../providers/room_detail_provider.dart';
import 'widgets/category_badge.dart';
// TODO: KakaoShareService 통합 (App-Features-B 담당)
// import '../../../core/share/kakao_share_service.dart';

const List<String> _kWeekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

/// 'YYYY-MM-DD' → "9/13" 처럼 짧은 날짜. 파싱 실패하면 원문 그대로.
String _shortDate(String raw) {
  final d = DateTime.tryParse(raw);
  if (d == null) return raw;
  return '${d.month}/${d.day}';
}

String _weekdayLabel(String raw) {
  final d = DateTime.tryParse(raw);
  if (d == null) return '';
  return '${_kWeekdayLabels[d.weekday - 1]}요일';
}

/// 오늘/내일/모레/N일 후 — 일주일 밖이면 null (날짜만으로 충분).
String? _relativeDayLabel(String raw) {
  final d = DateTime.tryParse(raw);
  if (d == null) return null;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;
  if (diff == 0) return '오늘';
  if (diff == 1) return '내일';
  if (diff == 2) return '모레';
  if (diff > 2 && diff < 7) return '$diff일 후';
  return null;
}

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
      // 방에 들어오면 홈의 참여 모임 목록을 다시 받아오도록 트리거.
      ref.invalidate(joinedRoomsProvider);
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
          backgroundColor: AppColors.paper,
          appBar: CustomAppBar(showBack: widget.showBack),
          body: SafeArea(
            child: ErrorState(
              message: state.error!,
              onRetry: () =>
                  ref.read(roomDetailProvider(widget.roomId).notifier).loadRoom(),
            ),
          ),
        );
      }
      return const Scaffold(
        backgroundColor: AppColors.paper,
        body: AppLoadingIndicator(),
      );
    }

    final room = state.room!;
    final isHost = room.host.id == currentUserId;
    final isAccepted = room.myStatus == 'ACCEPTED';
    // 이 방 채팅의 안 읽은 개수 — 하단 채팅 버튼에 배지로 표시.
    final chatRooms = ref.watch(chatRoomsProvider).valueOrNull;
    final unreadCount = room.chatRoomId == null
        ? 0
        : (chatRooms
                ?.where((c) => c.id == room.chatRoomId)
                .fold<int>(0, (sum, c) => sum + c.unreadCount) ??
            0);
    final isPending = room.myStatus == 'PENDING';
    final isParticipant = isHost || isAccepted;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: CustomAppBar(
        showBack: widget.showBack,
        actions: [
          // 공유 기능(카카오)은 아직 미구현이라 버튼을 숨긴다. 완성 시 복구.
          PullDownButton(
            itemBuilder: (context) => [
              if (isHost &&
                  room.status != 'COMPLETED' &&
                  room.status != 'CANCELLED')
                PullDownMenuItem(
                  title: '모임 수정',
                  icon: Icons.edit_outlined,
                  onTap: () => context.push(
                    '/rooms/${widget.roomId}/edit',
                    extra: room,
                  ),
                ),
              if (isHost && room.status != 'COMPLETED')
                PullDownMenuItem(
                  title: '모임 종료',
                  icon: Icons.event_available_rounded,
                  onTap: () => _completeRoom(room),
                ),
              if (isHost && room.status == 'COMPLETED')
                PullDownMenuItem(
                  // 이미 저장한 적 있으면 '수정'으로 — 재저장이 중복 부과가 아니라 정정임을 알린다.
                  title: (room.members ?? []).any((m) => m.attended != null)
                      ? '출석 수정'
                      : '출석 체크',
                  icon: Icons.how_to_reg_outlined,
                  onTap: () =>
                      context.push('/rooms/${widget.roomId}/attendance'),
                ),
              if (isHost)
                PullDownMenuItem(
                  title: '모임 취소',
                  icon: Icons.cancel_outlined,
                  isDestructive: true,
                  onTap: () => _cancelRoom(room),
                ),
              // 참여자(방장 제외) — 모임 나가기. 끝나거나 취소된 모임에선 숨긴다.
              if (isAccepted &&
                  !isHost &&
                  room.status != 'COMPLETED' &&
                  room.status != 'CANCELLED')
                PullDownMenuItem(
                  title: '모임 나가기',
                  icon: Icons.logout_rounded,
                  isDestructive: true,
                  onTap: () => _leaveRoom(room),
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
              icon: const Icon(Icons.more_vert_rounded, color: AppColors.ink),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          _RoomHeadline(room: room),
          const DashedDivider(margin: EdgeInsets.only(top: 18)),
          _InfoList(room: room, isParticipant: isParticipant),

          // 지도 미리보기 — 참여자에게만.
          if (isParticipant &&
              room.latitude != null &&
              room.longitude != null) ...[
            const SizedBox(height: 18),
            _MapSection(room: room),
          ],

          _MembersSection(
            room: room,
            onPhotos: isParticipant
                ? () => context.push('/rooms/${widget.roomId}/photos')
                : null,
          ),

          if (room.description != null &&
              room.description!.trim().isNotEmpty) ...[
            const SectionHeader(title: '모임 소개'),
            Text(room.description!, style: AppTextStyles.paragraph),
          ],

          const SectionHeader(title: '약속'),
          const _PromiseBox(),

          if (room.tags.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: room.tags
                  .map((tag) => Pill(label: '#$tag', tone: PillTone.muted))
                  .toList(),
            ),
          ],
        ],
      ),
      bottomNavigationBar: _BottomBar(
        room: room,
        isHost: isHost,
        isAccepted: isAccepted,
        isPending: isPending,
        isJoining: state.isJoining,
        unreadCount: unreadCount,
        // 첫 참여에서만 본인 인증을 받는다 — 이미 인증했으면 안내를 숨긴다.
        showVerifyNote: authState.user?.isPhoneVerified != true,
        onJoin: () => _joinRoom(),
        onCancelJoin: () => _leaveRoom(room, isPending: true),
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
            showTopToast(context, '후기를 작성할 대상 멤버가 없어요');
            return;
          }
          context.push('/reviews/write?roomId=${widget.roomId}',
              extra: targets);
        },
      ),
    );
  }

  Future<void> _joinRoom() async {
    // 본인인증은 가입이 아니라 이 시점에 받는다 — 인증을 마치면 그대로 이어간다.
    if (!await ensurePhoneVerified(context, ref, action: '모임에 참여하려면')) {
      return;
    }
    if (!mounted) return;
    try {
      final result = await ref
          .read(roomDetailProvider(widget.roomId).notifier)
          .joinRoom();
      if (mounted) {
        final status = result?['status'];
        final msg = status == 'ACCEPTED'
            ? '참여가 완료되었습니다!'
            : '참여 신청이 완료되었습니다. 방장의 수락을 기다려 주세요.';
        showTopToast(context, msg, backgroundColor: AppColors.success);
      }
      // 참여 후 홈의 참여 모임 목록 갱신.
      ref.invalidate(joinedRoomsProvider);
    } catch (e) {
      if (mounted) {
        showTopToast(context,
            apiErrorMessage(e, fallback: '참여 신청에 실패했습니다'),
            backgroundColor: AppColors.error);
      }
    }
  }

  /// 나가기 확인 시트 본문 — 노쇼 규칙과 잃게 되는 것을 함께 알린다.
  /// [untilStart] 가 null 이면(시작 시각을 못 읽음) 단정하지 않고 규칙만 말한다.
  static String _leaveMessage({
    required bool isPending,
    required Duration? untilStart,
  }) {
    const penalty = '노쇼 0.5회가 기록돼요(누적 3회부터 참여 제한).';
    const loss = '채팅방과 정확한 장소 정보는 볼 수 없게 돼요.';
    // 승인 상태는 화면에 캐시된 값이라 오래됐을 수 있다 — 단정하지 않는다.
    if (isPending) {
      return '참여 신청을 취소할까요?\n승인 전이면 노쇼는 기록되지 않아요.\n'
          '이미 수락된 뒤라면 시작 24시간 이내 취소에 $penalty';
    }
    if (untilStart == null) {
      return '이 모임에서 나갈까요?\n시작 24시간 이내에 나가면 $penalty\n$loss';
    }
    if (untilStart.isNegative) {
      return '이 모임에서 나갈까요?\n이미 시작한 모임이라 $penalty\n$loss';
    }
    if (untilStart.inHours < 24) {
      return '이 모임에서 나갈까요?\n시작 24시간 이내라 $penalty\n$loss';
    }
    return '이 모임에서 나갈까요?\n지금은 시작까지 24시간 이상 남아 노쇼가 기록되지 않아요.\n$loss';
  }

  /// 모임 나가기 / 참여 신청 취소 — 서버는 DELETE /rooms/:id/join 하나로 처리한다.
  /// [isPending] 이면 아직 승인 전이라 노쇼 패널티가 없다.
  Future<void> _leaveRoom(Room room, {bool isPending = false}) async {
    // 시작 24시간 이내(이미 시작한 경우 포함)에 나가면 서버가 노쇼 0.5회를 기록한다.
    final startAt = DateTime.tryParse('${room.date}T${room.startTime}');
    final untilStart = startAt?.difference(DateTime.now());

    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(isPending ? '참여 신청 취소' : '모임 나가기'),
        message: Text(
          _leaveMessage(isPending: isPending, untilStart: untilStart),
        ),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isPending ? '신청 취소하기' : '나가기'),
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
      final refreshed =
          await ref.read(roomDetailProvider(widget.roomId).notifier).leaveRoom();
      // 화면을 벗어난 뒤 ref 를 쓰면 StateError 가 난다.
      if (!mounted) return;
      // 화면은 그대로 두고 비참여자 뷰로 갱신된다(재참여 가능).
      ref.invalidate(joinedRoomsProvider);
      ref.invalidate(hasPastRoomsProvider);
      // 나간 방의 안 읽음 배지가 남지 않도록 채팅 목록도 갱신.
      ref.invalidate(chatRoomsProvider);
      ref.read(dashboardProvider.notifier).load(silent: true);
      showTopToast(
        context,
        isPending ? '참여 신청을 취소했어요' : '모임에서 나갔어요',
        backgroundColor: AppColors.success,
      );
      // 재조회가 실패하면 화면이 참여자 상태 그대로 남는다 — 목록으로 돌려보낸다.
      // 그 사이 다른 화면이 열렸으면 그 화면을 닫아버리므로 최상단일 때만.
      if (!refreshed && (ModalRoute.of(context)?.isCurrent ?? false)) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showTopToast(
          context,
          apiErrorMessage(e,
              fallback: isPending ? '신청 취소에 실패했습니다' : '모임 나가기에 실패했습니다'),
          backgroundColor: AppColors.error,
        );
      }
    }
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
          showTopToast(context, '모임 취소에 실패했습니다', backgroundColor: AppColors.error);
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
        showTopToast(context, '모임이 종료되었습니다', backgroundColor: AppColors.success);
        // 출석 체크는 종료 후 24시간 이내만 가능 — 종료 직후 유도.
        _promptAttendance();
      }
    } catch (e) {
      if (mounted) {
        showTopToast(context, '모임 종료에 실패했습니다', backgroundColor: AppColors.error);
      }
    }
  }

  /// 모임 종료 직후 출석 체크로 유도.
  Future<void> _promptAttendance() async {
    final go = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('출석 체크'),
        message: const Text(
            '지금 출석 체크를 할까요?\n노쇼 멤버는 쑥쑥 등급에 반영돼요. (종료 후 24시간 이내 가능)'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('출석 체크하기'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('나중에'),
        ),
      ),
    );
    if (go == true && mounted) {
      context.push('/rooms/${widget.roomId}/attendance');
    }
  }
}

/// 종이 위 머리말 — 상태 pill 줄 + 제목 + 방장 행.
class _RoomHeadline extends StatelessWidget {
  final Room room;
  const _RoomHeadline({required this.room});

  /// 상태 pill. 모집중만 형광펜, 나머지는 조용한 회색.
  Widget? _statusPill() {
    return switch (room.status) {
      'RECRUITING' => const Pill(label: '모집중', tone: PillTone.hi),
      'CLOSED' => const Pill(label: '마감'),
      'IN_PROGRESS' => const Pill(label: '진행 중'),
      'COMPLETED' => const Pill(label: '종료됨'),
      'CANCELLED' => const Pill(label: '취소된 모임'),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusPill();
    final hasCategory = room.genderFilter != 'ALL' || room.singleParentOnly;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // pill 줄 — 상태 · 승인 필요 · 개월수. 최대 3개.
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (status != null) status,
            if (room.isApprovalRequired) const Pill(label: '승인 필요'),
            Pill(
              label: '${room.ageMonthMin}~${room.ageMonthMax}개월',
              tone: PillTone.sky,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(room.title, style: AppTextStyles.display),
        // 카테고리(엄마만·아빠만·한부모)는 pill 줄과 의미가 달라 아래 별도 줄로.
        if (hasCategory) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: CategoryBadge(
              genderFilter: room.genderFilter,
              singleParentOnly: room.singleParentOnly,
            ),
          ),
        ],
        const SizedBox(height: 14),
        _HostRow(host: room.host),
      ],
    );
  }
}

/// 방장 행 — 아바타 + 닉네임 + 지역. 탭하면 방장 프로필.
class _HostRow extends StatelessWidget {
  final RoomHost host;
  const _HostRow({required this.host});

  @override
  Widget build(BuildContext context) {
    final region = (host.regionSigungu ?? '').trim();
    return GestureDetector(
      onTap: () => context.push('/users/${host.id}'),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          InitialAvatar(
            label: host.nickname,
            size: 40,
            tone: InitialAvatar.toneFor(host.id),
            imageUrl: host.profileImageUrl,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        host.nickname,
                        style: AppTextStyles.body1Bold,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(' · 방장', style: AppTextStyles.caption),
                  ],
                ),
                if (region.isNotEmpty)
                  Text(region, style: AppTextStyles.caption),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              size: 20, color: AppColors.line2),
        ],
      ),
    );
  }
}

/// 정보 목록 — 일시 · 장소 · 인원 · 비용 · 준비물. 항목 사이 점선 괘선.
class _InfoList extends ConsumerWidget {
  final Room room;
  final bool isParticipant;

  const _InfoList({required this.room, required this.isParticipant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = <Widget>[
      _InfoRow(
        icon: Icons.event_rounded,
        label: '일시',
        value: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: _shortDate(room.date),
                style: AppTextStyles.handLg,
              ),
              TextSpan(
                text: ' ${_weekdayLabel(room.date)} · ${_timeText()}',
                style: AppTextStyles.body1,
              ),
            ],
          ),
        ),
        caption: _relativeDayLabel(room.date),
      ),
      _placeRow(ref),
      _InfoRow(
        icon: Icons.people_alt_rounded,
        label: '인원',
        value: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${room.currentMembers}',
                style: AppTextStyles.handLg,
              ),
              TextSpan(
                text: ' / ${room.maxMembers}명 · '
                    '${room.isApprovalRequired ? '방장 승인 후 참여' : '바로 참여'}',
                style: AppTextStyles.body1,
              ),
            ],
          ),
        ),
      ),
      _InfoRow(
        icon: Icons.payments_outlined,
        label: '비용',
        value: Text(_costText(), style: AppTextStyles.body1),
      ),
      if (room.requiredItems.isNotEmpty)
        _InfoRow(
          icon: Icons.checklist_rounded,
          label: '준비물',
          value: Text(room.requiredItems.join(', '), style: AppTextStyles.body1),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const DashedDivider(),
          rows[i],
        ],
      ],
    );
  }

  String _timeText() =>
      AppDateUtils.formatTime(room.startTime) +
      (room.endTime != null
          ? ' ~ ${AppDateUtils.formatTime(room.endTime!)}'
          : '');

  String _costText() {
    if (room.isFree) return '없음';
    final desc = room.costDescription;
    final amount = AppDateUtils.formatCostDisplay(room.cost);
    return desc != null && desc.isNotEmpty ? '$amount · $desc' : amount;
  }

  /// 장소 — 참여자에겐 이름·주소·지도 링크, 비참여자에겐 잠금 문구와 지역만.
  Widget _placeRow(WidgetRef ref) {
    final region = [
      if ((room.regionSigungu ?? '').trim().isNotEmpty) room.regionSigungu!,
      if (room.regionDong.trim().isNotEmpty) room.regionDong,
    ].join(' ');
    final placeTypeLabel = AppConstants.placeTypes[room.placeType] ?? '기타';

    if (!isParticipant) {
      // 거리 — 좌표와 내 위치가 있을 때만 (비참여자 화면).
      String? distanceText;
      if (room.latitude != null && room.longitude != null) {
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
      return _InfoRow(
        icon: Icons.lock_outline_rounded,
        label: '장소',
        value: Text(
          '참여 확정 후 정확한 장소가 공개됩니다',
          style: AppTextStyles.body1.copyWith(color: AppColors.ink2),
        ),
        caption: [
          if (region.isNotEmpty) region,
          placeTypeLabel,
          if (distanceText != null) distanceText,
        ].join(' · '),
      );
    }

    final placeName = room.placeName ?? room.placeAddress ?? room.regionDong;
    final address = room.placeAddress;
    final hasAddress =
        address != null && address.isNotEmpty && address != placeName;

    return _InfoRow(
      icon: Icons.place_outlined,
      label: '장소',
      value: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(child: Text(placeName, style: AppTextStyles.body1)),
          if (room.latitude != null && room.longitude != null) ...[
            const SizedBox(width: 8),
            _MapLink(room: room),
          ],
        ],
      ),
      caption: [
        if (hasAddress) address,
        if (!hasAddress && region.isNotEmpty) region,
        placeTypeLabel,
      ].join(' · '),
    );
  }
}

/// 정보 목록 한 줄 — 아이콘 | 라벨 + 값 (+ 보조 캡션).
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget value;
  final String? caption;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final sub = caption;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppColors.ink3),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption),
                const SizedBox(height: 2),
                value,
                if (sub != null && sub.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(sub, style: AppTextStyles.caption),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "지도 보기" — 네이버 지도로 길찾기.
class _MapLink extends StatelessWidget {
  final Room room;

  const _MapLink({required this.room});

  Future<void> _openNaverMaps() async {
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
    return GestureDetector(
      onTap: _openNaverMaps,
      behavior: HitTestBehavior.opaque,
      child: Text(
        '지도 보기',
        style: AppTextStyles.body2Bold.copyWith(color: AppColors.link),
      ),
    );
  }
}

/// 약속 — 취소 규정과 후기 기한. 점선 상자 안 두 줄.
class _PromiseBox extends StatelessWidget {
  const _PromiseBox();

  @override
  Widget build(BuildContext context) {
    return const DashedBox(
      child: Column(
        children: [
          _PromiseLine('시작 24시간 전까지 취소 무료', '이후엔 노쇼 0.5회'),
          SizedBox(height: 8),
          _PromiseLine('모임 후 7일 안에 후기', '쑥쑥 등급에 반영'),
        ],
      ),
    );
  }
}

class _PromiseLine extends StatelessWidget {
  final String text;
  final String note;

  const _PromiseLine(this.text, this.note);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(text, style: AppTextStyles.body2)),
        const SizedBox(width: 10),
        Text(note, style: AppTextStyles.caption),
      ],
    );
  }
}

class _MapSection extends StatelessWidget {
  final Room room;

  const _MapSection({required this.room});

  NLatLng get _target => NLatLng(room.latitude!, room.longitude!);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFullscreen(context),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.line2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.fullscreen_rounded,
                            color: AppColors.ink2, size: 16),
                        const SizedBox(width: 4),
                        Text('크게 보기', style: AppTextStyles.caption),
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

/// 방장 전용 — 방 상세 참여자 섹션 위에 대기 중인 참여 신청을 인라인으로 보여주고
/// 바로 수락/거절한다. 신청이 없으면 아무것도 그리지 않는다.
class _JoinRequestsInline extends ConsumerWidget {
  final String roomId;
  const _JoinRequestsInline({required this.roomId});

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    String requestId,
    String action,
  ) async {
    try {
      await ref
          .read(roomRepositoryProvider)
          .handleJoinRequest(roomId, requestId, action);
      ref.invalidate(joinRequestsProvider(roomId));
      ref.read(roomDetailProvider(roomId).notifier).loadRoom();
      if (context.mounted) {
        showTopToast(
          context,
          action == 'ACCEPT' ? '수락되었습니다' : '거절되었습니다',
          backgroundColor: action == 'ACCEPT'
              ? AppColors.success
              : AppColors.textSecondary,
        );
      }
    } catch (_) {
      if (context.mounted) {
        showTopToast(context, '처리에 실패했습니다', backgroundColor: AppColors.error);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests =
        ref.watch(joinRequestsProvider(roomId)).valueOrNull ?? const [];
    if (requests.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: '참여 신청 (${requests.length})'),
        for (var i = 0; i < requests.length; i++) ...[
          if (i > 0) const DashedDivider(),
          _requestRow(context, ref, requests[i]),
        ],
      ],
    );
  }

  Widget _requestRow(BuildContext context, WidgetRef ref, JoinRequest r) {
    final user = r.user;
    final childLine = (user.children != null && user.children!.isNotEmpty)
        ? user.children!
            .map((c) =>
                '${c.nickname} (${AppDateUtils.formatAgeMonths(c.ageMonths ?? 0)})')
            .join(', ')
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          InitialAvatar(
            label: user.nickname,
            size: 38,
            tone: InitialAvatar.toneFor(user.id),
            imageUrl: user.profileImageUrl,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.nickname, style: AppTextStyles.body1Bold),
                if (childLine != null)
                  Text(childLine,
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _handle(context, ref, r.id, 'REJECT'),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text('거절', style: AppTextStyles.body2),
            ),
          ),
          GestureDetector(
            onTap: () => _handle(context, ref, r.id, 'ACCEPT'),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                '수락',
                style: AppTextStyles.body2Bold.copyWith(color: AppColors.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MembersSection extends ConsumerWidget {
  final Room room;
  /// 참여자만 사진첩을 열 수 있다. null 이면 섹션 액션을 숨긴다.
  final VoidCallback? onPhotos;

  const _MembersSection({required this.room, this.onPhotos});

  Future<void> _confirmKick(
      BuildContext context, WidgetRef ref, RoomMember member) async {
    var ok = false;
    await AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.scale,
      title: '참여자 내보내기',
      desc: '${member.nickname}님을 모임에서 내보낼까요?\n'
          '내보낸 사람은 이 모임에 다시 참여할 수 없어요.',
      btnCancelText: '취소',
      btnOkText: '내보내기',
      btnOkColor: AppColors.error,
      btnCancelOnPress: () {},
      btnOkOnPress: () => ok = true,
    ).show();
    if (!ok || !context.mounted) return;
    try {
      await ref.read(roomDetailProvider(room.id).notifier).kickMember(member.id);
      if (!context.mounted) return;
      showTopToast(context, '${member.nickname}님을 내보냈어요',
          backgroundColor: AppColors.success);
    } catch (e) {
      if (!context.mounted) return;
      showTopToast(context, apiErrorMessage(e, fallback: '내보내기에 실패했어요'),
          backgroundColor: AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = room.members ?? [];
    final myId = ref.watch(authProvider).user?.id;
    // 방장은 진행 전/중인 모임에서 참여자를 내보낼 수 있다.
    final canKick = room.host.id == myId &&
        room.status != 'COMPLETED' &&
        room.status != 'CANCELLED';
    final blockedIds = ref
            .watch(blockedUsersProvider)
            .valueOrNull
            ?.map((b) => b.targetUserId)
            .toSet() ??
        <String>{};
    final remaining = room.maxMembers - room.currentMembers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 방장 + 승인 필요 방이면 참여 신청 목록을 참여자 위에 인라인으로 노출.
        if (room.host.id == myId && room.isApprovalRequired)
          _JoinRequestsInline(roomId: room.id),
        SectionHeader(
          title: '참여자 (${room.currentMembers}/${room.maxMembers})',
          action: onPhotos != null ? '사진첩 ›' : null,
          onAction: onPhotos,
        ),
        // 큰 글씨 설정에서도 이름·부제가 잘리지 않을 만큼의 고정 높이.
        SizedBox(
          height: 104,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            children: [
              ...members.map((member) => _memberCell(
                    context,
                    ref,
                    member,
                    isMe: member.id == myId,
                    isBlocked: blockedIds.contains(member.id),
                    canKick: canKick && !member.isHost,
                  )),
              if (remaining > 0) _emptySlot(remaining),
            ],
          ),
        ),
      ],
    );
  }

  Widget _memberCell(
    BuildContext context,
    WidgetRef ref,
    RoomMember member, {
    required bool isMe,
    required bool isBlocked,
    required bool canKick,
  }) {
    final child = (member.children != null && member.children!.isNotEmpty)
        ? member.children!.first
        : null;
    final childLine = child != null
        ? '${child.nickname} ${AppDateUtils.formatAgeMonths(child.ageMonths ?? 0)}'
        : null;

    return GestureDetector(
      onTap: isMe ? null : () => context.push('/users/${member.id}'),
      onLongPress:
          isMe ? null : () => showReportSheet(context, targetUserId: member.id),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 76,
        margin: const EdgeInsets.only(right: 6),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                InitialAvatar(
                  label: member.nickname,
                  size: 44,
                  tone: InitialAvatar.toneFor(member.id),
                  imageUrl: member.profileImageUrl,
                ),
                if (canKick)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: GestureDetector(
                      onTap: () => _confirmKick(context, ref, member),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.fill,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surface, width: 2),
                        ),
                        child: const Icon(Icons.close_rounded,
                            size: 12, color: AppColors.ink2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              member.nickname,
              style: AppTextStyles.caption.copyWith(color: AppColors.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            if (member.isHost)
              const Pill(label: '방장', tone: PillTone.hi, height: 18)
            else if (isBlocked)
              Text(
                '차단함',
                style: AppTextStyles.caption.copyWith(color: AppColors.bad),
              )
            else if (childLine != null)
              Text(
                childLine,
                style: AppTextStyles.caption.copyWith(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  Widget _emptySlot(int remaining) {
    return SizedBox(
      width: 76,
      child: Column(
        children: [
          const DashedBox(
            padding: EdgeInsets.zero,
            radius: 22,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.add_rounded, size: 20, color: AppColors.ink3),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$remaining자리 남음',
            style: AppTextStyles.caption.copyWith(fontSize: 11),
          ),
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
  final int unreadCount;
  final bool showVerifyNote;
  final VoidCallback onJoin;
  final VoidCallback onCancelJoin;
  final VoidCallback onChat;
  final VoidCallback onReview;

  const _BottomBar({
    required this.room,
    required this.isHost,
    required this.isAccepted,
    required this.isPending,
    required this.isJoining,
    required this.unreadCount,
    required this.showVerifyNote,
    required this.onJoin,
    required this.onCancelJoin,
    required this.onChat,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: _buildButton(context),
    );
  }

  /// 안 읽은 메시지 배지 — 채팅 버튼 오른쪽 위 berry 점.
  Widget _withUnreadBadge(Widget child) {
    if (unreadCount <= 0) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            constraints: const BoxConstraints(minWidth: 20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.berry,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.surface, width: 1.5),
            ),
            child: Text(
              unreadCount > 99 ? '99+' : '$unreadCount',
              style: AppTextStyles.badge,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButton(BuildContext context) {
    if (isHost || isAccepted) {
      // 모임 종료 후 — 채팅 + 후기.
      if (room.status == 'COMPLETED') {
        return Row(
          children: [
            Expanded(
              child: _withUnreadBadge(
                GlassButton(
                  key: const Key('btn-room-detail-chat'),
                  text: '채팅방',
                  icon: Icons.chat_bubble_outline_rounded,
                  onPressed: onChat,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PrimaryButton(
                key: const Key('btn-room-detail-review'),
                text: '후기',
                icon: Icons.rate_review_outlined,
                onPressed: onReview,
              ),
            ),
          ],
        );
      }
      // 진행 중 — 채팅방 입장이 유일한 행동이라 잉크 CTA.
      return _withUnreadBadge(
        PrimaryButton(
          key: const Key('btn-room-detail-chat'),
          text: '채팅방 입장',
          icon: Icons.chat_bubble_outline_rounded,
          onPressed: onChat,
        ),
      );
    }

    if (isPending) {
      // 승인 전 — 탭하면 신청을 취소한다(노쇼 패널티 없음).
      return GlassButton(
        text: '승인 대기 중 · 신청 취소하기',
        icon: Icons.hourglass_empty_rounded,
        onPressed: onCancelJoin,
      );
    }

    if (!room.isRecruiting) {
      return const PrimaryButton(
        text: '모집이 마감되었습니다',
        isEnabled: false,
        onPressed: null,
      );
    }

    if (room.isFull) {
      return const PrimaryButton(
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PrimaryButton(
          key: const Key('btn-room-detail-join'),
          text: room.isApprovalRequired ? '참여 신청' : '참여하기',
          isLoading: isJoining,
          onPressed: onJoin,
        ),
        if (showVerifyNote) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline_rounded,
                  size: 13, color: AppColors.ink3),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '처음 참여할 땐 휴대폰 본인 인증을 한 번 해요',
                  style: AppTextStyles.caption,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
