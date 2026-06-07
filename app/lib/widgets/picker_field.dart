import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';

/// 탭하면 휠 시트가 올라오는 "선택" 필드. DropdownButton 대체용.
///
/// 룩: 라벨(작게, 위) / 값(primary 굵게) / 우측 chevron 아이콘.
/// — room_create_screen 의 `_AgePickerCard` 패턴을 표준화한 것.
///
/// 값이 없을 때는 hint 가 textHint 색으로 표시된다.
class PickerField extends StatelessWidget {
  /// 위쪽 작은 라벨. null/빈 문자열이면 라벨 줄을 생략하고 값만 표시한다.
  final String? label;

  /// 현재 값. null 이면 [hint] 가 placeholder 로 노출.
  final String? value;

  /// value 가 null 일 때 보여줄 placeholder.
  final String hint;

  final VoidCallback onTap;

  /// 기본은 위아래 화살표 — Cupertino 휠을 암시한다.
  final IconData trailingIcon;

  const PickerField({
    super.key,
    this.label,
    required this.value,
    required this.hint,
    required this.onTap,
    this.trailingIcon = Icons.unfold_more_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    final showLabel = label != null && label!.isNotEmpty;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: showLabel ? 12 : 14,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showLabel) ...[
              Text(
                label!,
                style:
                    AppTextStyles.caption.copyWith(color: AppColors.textHint),
              ),
              const SizedBox(height: 4),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    hasValue ? value! : hint,
                    style: AppTextStyles.body1Bold.copyWith(
                      color: hasValue ? AppColors.primary : AppColors.textHint,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(trailingIcon, size: 18, color: AppColors.textHint),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
