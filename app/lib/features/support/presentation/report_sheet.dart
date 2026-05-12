import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../widgets/common_button.dart';
import '../../../widgets/common_input.dart';
import '../data/support_repository.dart';

const _reasons = <Map<String, String>>[
  {'code': 'SPAM', 'label': '광고/스팸'},
  {'code': 'ABUSE', 'label': '욕설/괴롭힘'},
  {'code': 'INAPPROPRIATE', 'label': '부적절한 콘텐츠'},
  {'code': 'FRAUD', 'label': '사기/허위정보'},
  {'code': 'OTHER', 'label': '기타'},
];

/// 신고 BottomSheet — 유저나 모임 상세에서 호출.
/// 호출 예:
/// ```
/// showReportSheet(context, targetUserId: 'xxx');
/// showReportSheet(context, targetRoomId: 'yyy');
/// ```
Future<void> showReportSheet(
  BuildContext context, {
  String? targetUserId,
  String? targetRoomId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReportSheet(
      targetUserId: targetUserId,
      targetRoomId: targetRoomId,
    ),
  );
}

class _ReportSheet extends ConsumerStatefulWidget {
  final String? targetUserId;
  final String? targetRoomId;
  const _ReportSheet({this.targetUserId, this.targetRoomId});

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  String? _selected;
  final _detailController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('신고 사유를 선택해주세요')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(supportRepositoryProvider).createReport(
            targetUserId: widget.targetUserId,
            targetRoomId: widget.targetRoomId,
            reason: _selected!,
            detail: _detailController.text.trim().isEmpty
                ? null
                : _detailController.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('신고가 접수되었습니다.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('신고 전송에 실패했습니다. 잠시 후 다시 시도해주세요.'),
          backgroundColor: AppColors.error,
        ),
      );
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
            ...List.generate(_reasons.length, (i) {
              final r = _reasons[i];
              final isSel = _selected == r['code'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
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
              text: '신고하기',
              isLoading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
