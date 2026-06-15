import '../../../widgets/top_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../widgets/common_button.dart';
import '../../../widgets/common_input.dart';
import '../../mypage/providers/block_provider.dart';
import '../data/support_repository.dart';

const _reasons = <Map<String, String>>[
  {'code': 'SPAM', 'label': '광고/스팸'},
  {'code': 'ABUSE', 'label': '욕설/괴롭힘'},
  {'code': 'INAPPROPRIATE', 'label': '부적절한 콘텐츠'},
  {'code': 'FRAUD', 'label': '사기/허위정보'},
  {'code': 'OTHER', 'label': '기타'},
];

/// 방/유저 신고 시 사용할 후보 대상.
class ReportTarget {
  final String label; // "방 자체" / 닉네임 등
  final String? userId; // 멤버 신고일 때
  final String? roomId; // 방 자체 신고일 때
  final bool isHost; // 호스트 표시용 — UI 강조
  const ReportTarget({
    required this.label,
    this.userId,
    this.roomId,
    this.isHost = false,
  });
}

/// 신고 BottomSheet — 방/유저 상세에서 호출.
///
/// - 단일 대상 신고: [targetUserId] 또는 [targetRoomId] 만 전달.
/// - 방 신고에서 멤버 중 선택 가능: [targets] 에 후보 여러 개 전달 →
///   사용자가 "방 자체" 또는 특정 멤버 선택 후 신고.
Future<void> showReportSheet(
  BuildContext context, {
  String? targetUserId,
  String? targetRoomId,
  List<ReportTarget> targets = const [],
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReportSheet(
      targetUserId: targetUserId,
      targetRoomId: targetRoomId,
      targets: targets,
    ),
  );
}

class _ReportSheet extends ConsumerStatefulWidget {
  final String? targetUserId;
  final String? targetRoomId;
  final List<ReportTarget> targets;
  const _ReportSheet({
    this.targetUserId,
    this.targetRoomId,
    this.targets = const [],
  });

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  String? _selected;
  final _detailController = TextEditingController();
  bool _submitting = false;
  // 다중 후보 모드에서 선택된 인덱스. 단일 모드면 무의미.
  int _selectedTargetIdx = 0;

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selected == null) {
      showTopToast(context, '신고 사유를 선택해주세요');
      return;
    }
    setState(() => _submitting = true);
    try {
      // 후보 multi-mode 면 선택된 후보의 userId/roomId 우선, 아니면 widget 인자.
      String? userId = widget.targetUserId;
      String? roomId = widget.targetRoomId;
      if (widget.targets.isNotEmpty) {
        final t = widget.targets[_selectedTargetIdx];
        userId = t.userId;
        roomId = t.roomId;
      }
      await ref.read(supportRepositoryProvider).createReport(
            targetUserId: userId,
            targetRoomId: roomId,
            reason: _selected!,
            detail: _detailController.text.trim().isEmpty
                ? null
                : _detailController.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      showTopToast(context, '신고가 접수되었습니다.');
    } catch (_) {
      if (!mounted) return;
      showTopToast(context, '신고 전송에 실패했습니다. 잠시 후 다시 시도해주세요.', backgroundColor: AppColors.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// 선택된 대상의 userId — 다중 후보 모드면 선택 항목, 아니면 단일 인자.
  String? get _selectedUserId {
    if (widget.targets.isNotEmpty) {
      return widget.targets[_selectedTargetIdx].userId;
    }
    return widget.targetUserId;
  }

  Future<void> _blockUser() async {
    final userId = _selectedUserId;
    if (userId == null) return;
    setState(() => _submitting = true);
    try {
      await ref.read(blockRepositoryProvider).block(userId);
      if (!mounted) return;
      Navigator.of(context).pop();
      showTopToast(context, '해당 사용자를 차단했습니다.');
    } catch (_) {
      if (!mounted) return;
      showTopToast(context, '차단에 실패했습니다. 잠시 후 다시 시도해주세요.', backgroundColor: AppColors.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('신고하기', style: AppTextStyles.heading3),
            const SizedBox(height: 4),
            Text(
              '신고 사유를 선택해주세요. 검토 후 처리됩니다.',
              style:
                  AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            if (widget.targets.isNotEmpty) ...[
              Text('신고 대상', style: AppTextStyles.body2Bold),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(widget.targets.length, (i) {
                  final t = widget.targets[i];
                  final sel = _selectedTargetIdx == i;
                  return InkWell(
                    key: Key('report-target-$i'),
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => setState(() => _selectedTargetIdx = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary50 : AppColors.bg2,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: sel
                              ? AppColors.primary400
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (t.isHost)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(Icons.star_rounded,
                                  size: 14, color: AppColors.primary),
                            ),
                          Text(
                            t.label,
                            style: AppTextStyles.body2.copyWith(
                              color: sel
                                  ? AppColors.primary
                                  : AppColors.ink700,
                              fontWeight:
                                  sel ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              Text('신고 사유', style: AppTextStyles.body2Bold),
              const SizedBox(height: 8),
            ],
            ...List.generate(_reasons.length, (i) {
              final r = _reasons[i];
              final isSel = _selected == r['code'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  key: Key('report-reason-${r['code']}'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _selected = r['code']),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSel ? AppColors.primary50 : AppColors.bg2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isSel ? AppColors.primary400 : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSel
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: isSel
                              ? AppColors.primary
                              : AppColors.textHint,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(r['label']!, style: AppTextStyles.body1),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            CommonInput(
              label: '상세 내용 (선택)',
              hint: '추가로 알리고 싶은 내용을 적어주세요',
              controller: _detailController,
              maxLines: 4,
              maxLength: 2000,
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              key: const Key('btn-report-submit'),
              text: '신고하기',
              isLoading: _submitting,
              onPressed: _submit,
            ),
            if (_selectedUserId != null) ...[
              const SizedBox(height: 10),
              SecondaryButton(
                text: '이 사용자 차단하기',
                icon: Icons.block_rounded,
                onPressed: _blockUser,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
