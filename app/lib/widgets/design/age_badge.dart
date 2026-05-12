import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

/// 월령 pill (예: "12+", "13-18개월")
class AgeBadge extends StatelessWidget {
  final String label;
  final bool solid;

  const AgeBadge({super.key, required this.label, this.solid = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: solid ? AppColors.primaryGradient : null,
        color: solid ? null : AppColors.primary100.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
        border: solid
            ? null
            : Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
      ),
      child: Text(
        label,
        style: AppTextStyles.chip.copyWith(
          color: solid ? Colors.white : AppColors.primary700,
        ),
      ),
    );
  }
}
