import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

/// 아바타 톤 — 하늘(기본) / 노랑 / 회색. 이름은 호환용(primary=하늘, coral=노랑, lilac=회색).
enum AvatarTone { primary, coral, lilac }

/// 이니셜 아바타. 둥근 네모(스티커) 모양, 단색 틴트. 그라데이션·링 없음.
class InitialAvatar extends StatelessWidget {
  final String label;
  final double size;
  final AvatarTone tone;
  final bool ring;
  final String? imageUrl;

  const InitialAvatar({
    super.key,
    required this.label,
    this.size = 40,
    this.tone = AvatarTone.primary,
    this.ring = false,
    this.imageUrl,
  });

  ({Color bg, Color fg}) get _colors {
    switch (tone) {
      case AvatarTone.primary:
        return (bg: AppColors.sky, fg: AppColors.skyInk);
      case AvatarTone.coral:
        return (bg: AppColors.hi, fg: AppColors.hiInk);
      case AvatarTone.lilac:
        return (bg: AppColors.fill, fg: AppColors.ink2);
    }
  }

  /// 문자열(닉네임·id)로 톤을 안정적으로 고른다 — 같은 사람은 늘 같은 색.
  static AvatarTone toneFor(String key) {
    if (key.isEmpty) return AvatarTone.primary;
    final hash = key.codeUnits.fold<int>(0, (a, b) => (a + b) & 0xffff);
    return AvatarTone.values[hash % AvatarTone.values.length];
  }

  @override
  Widget build(BuildContext context) {
    final initial = label.isEmpty ? '🙂' : label.characters.first.toUpperCase();
    final c = _colors;
    final radius = BorderRadius.circular(size * 0.38);
    Widget box = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: radius,
        border: ring ? Border.all(color: AppColors.surface, width: 2) : null,
      ),
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? Image.network(
              imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initialText(initial, c.fg),
            )
          : _initialText(initial, c.fg),
    );
    return box;
  }

  Widget _initialText(String initial, Color color) {
    return Text(
      initial,
      style: AppTextStyles.captionBold.copyWith(
        color: color,
        fontSize: size * 0.4,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
