import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';
import '../core/constants/child_traits.dart';

/// 아이 낮잠 시간대 단일 선택 칩 그리드.
/// 같은 칩을 다시 탭하면 해제(null) — "굳이 안 정함" 도 허용.
class NapTimeSelector extends StatelessWidget {
  final String? selectedKey;
  final ValueChanged<String?> onChanged;

  const NapTimeSelector({
    super.key,
    required this.selectedKey,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('낮잠 시간대', style: AppTextStyles.body2Bold),
            const SizedBox(width: 6),
            Text(
              '(선택)',
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.textHint),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opt in napTimeOptions)
              _TraitChip(
                label: opt.label,
                isSelected: selectedKey == opt.key,
                onTap: () =>
                    onChanged(selectedKey == opt.key ? null : opt.key),
              ),
          ],
        ),
      ],
    );
  }
}

/// 기질 태그 다중 선택 — 최대 5개까지만 활성화, 그 외는 비활성 표시.
class TemperamentTagSelector extends StatelessWidget {
  final Set<String> selectedKeys;
  final ValueChanged<String> onToggle;

  const TemperamentTagSelector({
    super.key,
    required this.selectedKeys,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final atMax = selectedKeys.length >= maxTemperamentTags;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('기질 태그', style: AppTextStyles.body2Bold),
            const SizedBox(width: 6),
            Text(
              '(선택, 최대 $maxTemperamentTags개)',
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.textHint),
            ),
            const Spacer(),
            Text(
              '${selectedKeys.length}/$maxTemperamentTags',
              style: AppTextStyles.caption.copyWith(
                color: atMax ? AppColors.primary : AppColors.textHint,
                fontWeight: atMax ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in temperamentTags)
              _TraitChip(
                label: tag.label,
                emoji: tag.emoji,
                accent: _traitCategoryColor(tag.category),
                isSelected: selectedKeys.contains(tag.key),
                isDimmed: atMax && !selectedKeys.contains(tag.key),
                onTap: () => onToggle(tag.key),
              ),
          ],
        ),
      ],
    );
  }
}

/// 카테고리 → 액센트 색. 모델에 디자인 의존성을 끌어들이지 않으려 위젯 쪽에서 매핑한다.
Color _traitCategoryColor(TraitCategory c) {
  switch (c) {
    case TraitCategory.energetic:
      return AppColors.accentCoral;
    case TraitCategory.composed:
      return AppColors.accentLavender;
    case TraitCategory.warm:
      return AppColors.primary;
    case TraitCategory.hobby:
      return AppColors.accentLime;
    case TraitCategory.assertive:
      return AppColors.accentYellow;
  }
}

class _TraitChip extends StatelessWidget {
  final String label;
  final String? emoji;
  // 선택 시 적용할 액센트 색. null 이면 primary 로 폴백 — NapTimeSelector 처럼
  // 카테고리 분리가 없는 칩에 그대로 쓰인다.
  final Color? accent;
  final bool isSelected;
  final bool isDimmed;
  final VoidCallback onTap;

  const _TraitChip({
    required this.label,
    this.emoji,
    this.accent,
    required this.isSelected,
    this.isDimmed = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color tone = accent ?? AppColors.primary;
    final Color bg;
    final Color border;
    final Color fg;
    if (isSelected) {
      bg = tone.withValues(alpha: 0.12);
      border = tone;
      fg = tone;
    } else if (isDimmed) {
      bg = AppColors.surface;
      border = AppColors.divider;
      fg = AppColors.textHint;
    } else {
      bg = AppColors.surface;
      border = AppColors.divider;
      fg = AppColors.textSecondary;
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) ...[
              // 이모지는 비선택/dim 상태에서 살짝 덜 강조 — 라벨 정렬에 영향 없게 고정 폭.
              Opacity(
                opacity: isDimmed ? 0.5 : 1,
                child: Text(
                  emoji!,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppTextStyles.body2.copyWith(
                color: fg,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
