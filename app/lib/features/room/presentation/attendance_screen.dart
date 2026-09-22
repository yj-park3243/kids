import '../../../widgets/top_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/room.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/common_button.dart';
import '../../../widgets/design/avatar.dart';
import '../../../widgets/design/notebook.dart';
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
              attended: _attendance[m.id] ?? m.attended ?? true,
            ))
        .toList();

    if (records.isEmpty) {
      showTopToast(context, '출석 체크할 멤버가 없어요', backgroundColor: AppColors.warning);
      return;
    }

    final result = await ref
        .read(attendanceSubmitProvider(widget.roomId).notifier)
        .submit(records);

    if (!mounted) return;

    if (result == null) {
      showTopToast(context, '출석 저장에 실패했습니다', backgroundColor: AppColors.error);
      return;
    }

    final applied = result.noShowAppliedNicknames;
    final msg = applied.isEmpty
        ? '출석이 저장되었습니다'
        : applied.map((n) => '$n님 노쇼 1회 적용됨').join('\n');
    // 방 상세의 members.attended 를 최신으로.
    ref.read(roomDetailProvider(widget.roomId).notifier).loadRoom();
    showTopToast(context, msg, backgroundColor: AppColors.success);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roomDetailProvider(widget.roomId));
    final submitState = ref.watch(attendanceSubmitProvider(widget.roomId));
    final myId = ref.watch(authProvider).user?.id;

    if (state.isLoading && state.room == null) {
      return const Scaffold(
        backgroundColor: AppColors.paper,
        appBar: CustomAppBar(title: '출석 체크'),
        body: AppLoadingIndicator(),
      );
    }

    if (state.error != null && state.room == null) {
      return Scaffold(
        backgroundColor: AppColors.paper,
        appBar: const CustomAppBar(title: '출석 체크'),
        body: SafeArea(
          child: ErrorState(
            message: state.error!,
            onRetry: () => ref
                .read(roomDetailProvider(widget.roomId).notifier)
                .loadRoom(),
          ),
        ),
      );
    }

    final room = state.room!;
    final accessError = _accessError(room, myId);

    if (accessError != null) {
      return Scaffold(
        backgroundColor: AppColors.paper,
        appBar: const CustomAppBar(title: '출석 체크'),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_clock_rounded,
                      size: 48, color: AppColors.ink3),
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
      );
    }

    final members = (room.members ?? []).where((m) => !m.isHost).toList();

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: const CustomAppBar(title: '출석 체크'),
      body: SafeArea(
        child: Column(
          children: [
            // 안내 배너
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: DashedBox(
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 18, color: AppColors.ink3),
                    SizedBox(width: 8),
                    Expanded(
                      child: _BannerText(),
                    ),
                  ],
                ),
              ),
            ),

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
                          horizontal: 20, vertical: 4),
                      itemCount: members.length,
                      separatorBuilder: (_, __) => const DashedDivider(),
                      itemBuilder: (context, index) {
                        final m = members[index];
                        // 이미 저장한 결과가 있으면 그걸 기본값으로 — 재저장이 정정이 되게.
                        final attended =
                            _attendance[m.id] ?? m.attended ?? true;
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
                isLoading: submitState.isSubmitting,
                onPressed:
                    members.isEmpty ? null : () => _submit(room.members ?? []),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 배너 문구 — const 로 쓰려고 분리.
class _BannerText extends StatelessWidget {
  const _BannerText();

  @override
  Widget build(BuildContext context) {
    return Text(
      '노쇼 처리된 멤버는 쑥쑥 등급에 반영돼요',
      style: AppTextStyles.caption,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          InitialAvatar(
            label: member.nickname,
            size: 40,
            tone: InitialAvatar.toneFor(member.id),
            imageUrl: member.profileImageUrl,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.nickname, style: AppTextStyles.body1Bold),
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
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segmentButton('출석', attended, () => onChanged(true),
              activeColor: AppColors.ink),
          _segmentButton('노쇼', !attended, () => onChanged(false),
              activeColor: AppColors.bad),
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
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: active ? Colors.white : AppColors.ink2,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
