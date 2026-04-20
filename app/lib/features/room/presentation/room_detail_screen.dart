import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/room.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/common_button.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/room_detail_provider.dart';

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

    if (state.isLoading && state.room == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: AppLoadingIndicator(),
      );
    }

    if (state.error != null && state.room == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: const CustomAppBar(title: ''),
        body: ErrorState(
          message: state.error!,
          onRetry: () =>
              ref.read(roomDetailProvider(widget.roomId).notifier).loadRoom(),
        ),
      );
    }

    final room = state.room!;
    final isHost = room.host.id == currentUserId;
    final isAccepted = room.myStatus == 'ACCEPTED';
    final isPending = room.myStatus == 'PENDING';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: '',
        actions: [
          if (isHost)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppColors.textPrimary),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                if (value == 'manage') {
                  context.push('/rooms/${widget.roomId}/requests');
                } else if (value == 'cancel') {
                  _cancelRoom(room);
                }
              },
              itemBuilder: (context) => [
                if (room.isApprovalRequired)
                  const PopupMenuItem(
                    value: 'manage',
                    child: Text('참여 관리'),
                  ),
                const PopupMenuItem(
                  value: 'cancel',
                  child: Text('모임 취소', style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Place type badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                  const SizedBox(height: 12),
                  Text(room.title, style: AppTextStyles.heading1),
                  if (room.description != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      room.description!,
                      style: AppTextStyles.body2
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Info section
            _InfoSection(room: room),

            const SizedBox(height: 16),

            // Map placeholder
            if (room.latitude != null && room.longitude != null)
              _MapSection(room: room),

            const SizedBox(height: 16),

            // Host profile
            _HostSection(host: room.host),

            const SizedBox(height: 16),

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

  Future<void> _cancelRoom(Room room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('모임 취소'),
        content: const Text('정말로 이 모임을 취소하시겠습니까?\n참여자 전원에게 알림이 발송됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('아니요'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('취소하기', style: TextStyle(color: AppColors.error)),
          ),
        ],
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
}

class _InfoSection extends StatelessWidget {
  final Room room;

  const _InfoSection({required this.room});

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
            value: room.placeName ?? room.placeAddress ?? room.regionDong,
          ),
          const Divider(height: 20, color: AppColors.divider),
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

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
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
      ],
    );
  }
}

class _MapSection extends StatelessWidget {
  final Room room;

  const _MapSection({required this.room});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_rounded, size: 40, color: AppColors.textHint),
            const SizedBox(height: 8),
            Text(
              room.placeAddress ?? '지도에서 위치 보기',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class _HostSection extends StatelessWidget {
  final RoomHost host;

  const _HostSection({required this.host});

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
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.surfaceVariant,
            backgroundImage: host.profileImageUrl != null
                ? NetworkImage(host.profileImageUrl!)
                : null,
            child: host.profileImageUrl == null
                ? const Icon(Icons.person_rounded,
                    color: AppColors.textHint, size: 24)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(host.nickname, style: AppTextStyles.body1Bold),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '방장',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 10,
                          color: AppColors.accentDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (host.regionSigungu != null)
                  Text(host.regionSigungu!,
                      style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MembersSection extends StatelessWidget {
  final Room room;

  const _MembersSection({required this.room});

  @override
  Widget build(BuildContext context) {
    final members = room.members ?? [];

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
          ...members.map((member) => Container(
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
              )),
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

  const _BottomBar({
    required this.room,
    required this.isHost,
    required this.isAccepted,
    required this.isPending,
    required this.isJoining,
    required this.onJoin,
    required this.onChat,
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
      return PrimaryButton(
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
      text: room.isApprovalRequired ? '참여 신청' : '참여하기',
      isLoading: isJoining,
      onPressed: onJoin,
    );
  }
}
