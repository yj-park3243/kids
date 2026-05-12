import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

/// 방 카테고리 배지. genderFilter / singleParentOnly 조합으로 라벨 표시.
/// ALL + false 조합은 빈 위젯 반환.
class CategoryBadge extends StatelessWidget {
  final String genderFilter; // 'ALL' | 'MOM_ONLY' | 'DAD_ONLY'
  final bool singleParentOnly;

  const CategoryBadge({
    super.key,
    required this.genderFilter,
    required this.singleParentOnly,
  });

  String? get _label {
    if (genderFilter == 'ALL' && !singleParentOnly) return null;
    if (genderFilter == 'MOM_ONLY' && !singleParentOnly) return '👩 엄마만';
    if (genderFilter == 'DAD_ONLY' && !singleParentOnly) return '👨 아빠만';
    if (genderFilter == 'ALL' && singleParentOnly) return '🤍 한부모';
    if (genderFilter == 'MOM_ONLY' && singleParentOnly) return '👩🤍 엄마 한부모';
    if (genderFilter == 'DAD_ONLY' && singleParentOnly) return '👨🤍 아빠 한부모';
    return null;
  }

  Color get _bgColor {
    if (singleParentOnly) {
      return AppColors.lilac.withValues(alpha: 0.5);
    }
    if (genderFilter == 'MOM_ONLY') {
      return AppColors.primary100;
    }
    if (genderFilter == 'DAD_ONLY') {
      return AppColors.mint.withValues(alpha: 0.6);
    }
    return AppColors.surfaceVariant;
  }

  Color get _fgColor {
    if (singleParentOnly) return AppColors.secondaryDark;
    if (genderFilter == 'MOM_ONLY') return AppColors.primary700;
    if (genderFilter == 'DAD_ONLY') return AppColors.success;
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final label = _label;
    if (label == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTextStyles.captionBold.copyWith(color: _fgColor),
      ),
    );
  }
}
