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
            Text('(선택)', style: AppTextStyles.caption),
          ],
        ),
        const SizedBox(height: 10),
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
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('기질 태그', style: AppTextStyles.body2Bold),
            const SizedBox(width: 6),
            Text('(선택, 최대 $maxTemperamentTags개)', style: AppTextStyles.caption),
            const Spacer(),
            Text(
              '${selectedKeys.length}/$maxTemperamentTags',
              style: AppTextStyles.hand.copyWith(
                color: atMax ? AppColors.ink : AppColors.ink3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in temperamentTags)
              _TraitChip(
                label: tag.label,
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

/// 선택 칩 — 목록 필터(`FilterChipButton`)와 같은 규칙. 선택되면 잉크로 채운다.
class _TraitChip extends StatelessWidget {
  final String label;
  final bool isSelected;

  /// 최대 개수를 채워 더 고를 수 없는 상태 — 회색 면으로 물러난다.
  final bool isDimmed;
  final VoidCallback onTap;

  const _TraitChip({
    required this.label,
    required this.isSelected,
    this.isDimmed = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color border;
    final Color fg;
    if (isSelected) {
      bg = AppColors.ink;
      border = AppColors.ink;
      fg = Colors.white;
    } else if (isDimmed) {
      bg = AppColors.fill;
      border = AppColors.line;
      fg = AppColors.ink3;
    } else {
      bg = AppColors.surface;
      border = AppColors.line2;
      fg = AppColors.ink;
    }
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 34,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: AppTextStyles.body2.copyWith(
            color: fg,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
