import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

/// 월령 pill (예: "12+", "13-18개월") — 아이 정보는 늘 하늘색. `solid` 는 호환용(무시).
class AgeBadge extends StatelessWidget {
  final String label;
  final bool solid;

  const AgeBadge({super.key, required this.label, this.solid = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.sky,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.chip.copyWith(color: AppColors.skyInk),
      ),
    );
  }
}
