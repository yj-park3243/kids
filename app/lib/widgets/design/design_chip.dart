import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

enum ChipTone { pinkSolid, pinkGhost, mint, lilac, cream, ink, outline }

class DesignChip extends StatelessWidget {
  final String label;
  final ChipTone tone;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool selected;
  final double height;

  const DesignChip({
    super.key,
    required this.label,
    this.tone = ChipTone.pinkGhost,
    this.icon,
    this.onTap,
    this.selected = false,
    this.height = 28,
  });

  ({Color bg, Color fg, Color? border}) _palette() {
    switch (tone) {
      case ChipTone.pinkSolid:
        return (bg: AppColors.pink500, fg: Colors.white, border: null);
      case ChipTone.pinkGhost:
        return (
          bg: AppColors.pink100.withValues(alpha: 0.7),
          fg: AppColors.pink700,
          border: AppColors.pink300Real.withValues(alpha: 0.35),
        );
      case ChipTone.mint:
        return (bg: AppColors.mint.withValues(alpha: 0.7), fg: const Color(0xFF1F6B4A), border: null);
      case ChipTone.lilac:
        return (bg: AppColors.lilac.withValues(alpha: 0.7), fg: const Color(0xFF5A3F99), border: null);
      case ChipTone.cream:
        return (bg: AppColors.cream, fg: AppColors.ink700, border: AppColors.dividerStrong);
      case ChipTone.ink:
        return (bg: AppColors.ink900, fg: Colors.white, border: null);
      case ChipTone.outline:
        return (bg: Colors.white.withValues(alpha: 0.6), fg: AppColors.ink700, border: AppColors.dividerStrong);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = selected
        ? (bg: AppColors.pink500, fg: Colors.white, border: null)
        : _palette();
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: palette.bg,
          borderRadius: BorderRadius.circular(999),
          border: palette.border != null
              ? Border.all(color: palette.border!, width: 0.8)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: palette.fg),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTextStyles.chip.copyWith(color: palette.fg),
            ),
          ],
        ),
      ),
    );
  }
}
