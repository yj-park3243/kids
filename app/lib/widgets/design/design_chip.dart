import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

/// 호환용 톤. 새 코드는 [Pill] / [FilterChipButton] 을 쓴다.
/// primarySolid→잉크, primaryGhost→형광펜, lilac→하늘, cream/outline→회색, ink→잉크.
enum ChipTone { primarySolid, primaryGhost, lilac, cream, ink, outline }

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
    this.tone = ChipTone.primaryGhost,
    this.icon,
    this.onTap,
    this.selected = false,
    this.height = 22,
  });

  PillTone get _pillTone {
    switch (tone) {
      case ChipTone.primarySolid:
      case ChipTone.ink:
        return PillTone.ink;
      case ChipTone.primaryGhost:
        return PillTone.hi;
      case ChipTone.lilac:
        return PillTone.sky;
      case ChipTone.cream:
      case ChipTone.outline:
        return PillTone.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Pill(
      label: label,
      tone: selected ? PillTone.ink : _pillTone,
      icon: icon,
      onTap: onTap,
      height: height,
    );
  }
}

/// 상태·속성 표시용 작은 알약. 색이 곧 의미다:
/// - [PillTone.hi]    형광펜 — 모집중 · 내가 만든 모임 · D-day
/// - [PillTone.sky]   아이 — 개월수
/// - [PillTone.sage]  쑥쑥 등급
/// - [PillTone.muted] 그 밖의 속성 — 승인 필요 · 마감 · 인원 · 준비물
/// - [PillTone.ink]   선택됨 · 강한 라벨
/// - [PillTone.line]  테두리만
/// 한 항목에 pill 은 2개까지.
enum PillTone { hi, sky, sage, muted, ink, line }

class Pill extends StatelessWidget {
  final String label;
  final PillTone tone;
  final IconData? icon;
  final VoidCallback? onTap;
  final double height;

  const Pill({
    super.key,
    required this.label,
    this.tone = PillTone.muted,
    this.icon,
    this.onTap,
    this.height = 22,
  });

  ({Color bg, Color fg, Color? border}) get _palette {
    switch (tone) {
      case PillTone.hi:
        return (bg: AppColors.hi, fg: AppColors.ink, border: null);
      case PillTone.sky:
        return (bg: AppColors.sky, fg: AppColors.skyInk, border: null);
      case PillTone.sage:
        return (bg: AppColors.sage, fg: AppColors.sageInk, border: null);
      case PillTone.muted:
        return (bg: AppColors.fill, fg: AppColors.ink2, border: null);
      case PillTone.ink:
        return (bg: AppColors.ink, fg: Colors.white, border: null);
      case PillTone.line:
        return (bg: Colors.transparent, fg: AppColors.ink2, border: AppColors.line2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _palette;
    final body = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(999),
        border: p.border != null ? Border.all(color: p.border!) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: p.fg),
            const SizedBox(width: 4),
          ],
          Text(label, style: AppTextStyles.chip.copyWith(color: p.fg)),
        ],
      ),
    );
    if (onTap == null) return body;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: body,
    );
  }
}

/// 필터 칩 (목록 상단). 선택되면 잉크 채움 — 형광펜은 상태 표시용이라 여기선 안 쓴다.
class FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? trailing;

  const FilterChipButton({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.ink;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 34,
        padding: EdgeInsets.only(left: 14, right: trailing != null ? 10 : 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppColors.ink : AppColors.line2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.body2.copyWith(
                color: fg,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              Icon(trailing, size: 15, color: fg),
            ],
          ],
        ),
      ),
    );
  }
}
