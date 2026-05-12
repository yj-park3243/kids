import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/room.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/common_button.dart';
import '../../../widgets/design/accent_blobs.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/attendance_repository.dart';
import '../providers/attendance_provider.dart';
import '../providers/room_detail_provider.dart';

// TODO: register route /rooms/:id/attendance → AttendanceScreen (core/router/app_router.dart)

class AttendanceScreen extends ConsumerStatefulWidget {
  final String roomId;

  const AttendanceScreen({super.key, required this.roomId});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  // userId → attended(true) / no-show(false)
  final Map<String, bool> _attendance = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(roomDetailProvider(widget.roomId).notifier).loadRoom();
    });
  }

  /// 방장 + 모임 종료 후 24h 이내일 때만 출석 체크 가능.
  String? _accessError(Room room, String? myUserId) {
    if (room.host.id != myUserId) {
      return '방장만 출석 체크를 할 수 있어요';
    }
    final completedAt = room.completedAt;
    if (completedAt == null) {
      return '모임 종료 후 출석 체크가 가능해요';
    }
    final hours = DateTime.now().difference(completedAt).inHours;
    if (hours > 24) {
      return '출석 체크 가능 시간(24시간)이 지났어요';
    }
    return null;
  }

  Future<void> _submit(List<RoomMember> members) async {
    final records = members
        .where((m) => !m.isHost)
        .map((m) => AttendanceRecord(
              userId: m.id,
              attended: _attendance[m.id] ?? true,
            ))
        .toList();

    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('출석 체크할 멤버가 없어요'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final result = await ref
        .read(attendanceSubmitProvider(widget.roomId).notifier)
        .submit(records);

    if (!mounted) return;

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('출석 저장에 실패했습니다'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final applied = result.noShowAppliedNicknames;
    final msg = applied.isEmpty
        ? '출석이 저장되었습니다'
        : applied.map((n) => '$n님 노쇼 1회 적용됨').join('\n');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roomDetailProvider(widget.roomId));
    final submitState = ref.watch(attendanceSubmitProvider(widget.roomId));
    final myId = ref.watch(authProvider).user?.id;

    if (state.isLoading && state.room == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        appBar: CustomAppBar(title: '출석 체크'),
        extendBodyBehindAppBar: true,
        body: AccentBlobsBackground(child: AppLoadingIndicator()),
      );
    }

    if (state.error != null && state.room == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const CustomAppBar(title: '출석 체크'),
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

    final room = state.room!;
    final accessError = _accessError(room, myId);

    if (accessError != null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const CustomAppBar(title: '출석 체크'),
        extendBodyBehindAppBar: true,
        body: AccentBlobsBackground(
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_clock_rounded,
                        size: 48, color: AppColors.textHint),
                    const SizedBox(height: 16),
                    Text(
                      accessError,
                      style: AppTextStyles.body1Bold,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final members = (room.members ?? []).where((m) => !m.isHost).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: '출석 체크'),
      extendBodyBehindAppBar: true,
      body: AccentBlobsBackground(
        child: SafeArea(
          child: Column(
            children: [
              // 안내 배너
              Container(
                margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 18, color: AppColors.primaryDark),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '노쇼 처리된 멤버는 매너 점수에 반영돼요',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.primary700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: members.isEmpty
                    ? Center(
                        child: Text(
                          '출석 체크할 멤버가 없어요',
                          style: AppTextStyles.body2,
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        itemCount: members.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final m = members[index];
                          final attended = _attendance[m.id] ?? true;
                          return _AttendanceRow(
                            member: m,
                            attended: attended,
                            onChanged: (v) =>
                                setState(() => _attendance[m.id] = v),
                          );
                        },
                      ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: PrimaryButton(
                  text: '저장',
                  icon: Icons.check_circle_outline_rounded,
                  isLoading: submitState.isSubmitting,
                  onPressed:
                      members.isEmpty ? null : () => _submit(room.members ?? []),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  final RoomMember member;
  final bool attended;
  final ValueChanged<bool> onChanged;

  const _AttendanceRow({
    required this.member,
    required this.attended,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                Text(member.nickname, style: AppTextStyles.body2Bold),
                if (member.children != null && member.children!.isNotEmpty)
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
          _ToggleSegment(
            attended: attended,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ToggleSegment extends StatelessWidget {
  final bool attended;
  final ValueChanged<bool> onChanged;

  const _ToggleSegment({required this.attended, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segmentButton('출석', attended, () => onChanged(true),
              activeColor: AppColors.success),
          _segmentButton('노쇼', !attended, () => onChanged(false),
              activeColor: AppColors.error),
        ],
      ),
    );
  }

  Widget _segmentButton(
    String label,
    bool active,
    VoidCallback onTap, {
    required Color activeColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: active ? Colors.white : AppColors.textSecondary,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
