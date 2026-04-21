import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

enum AvatarTone { pink, coral, lilac, mint, cream }

/// 이니셜/이모지 아바타. 그라디언트 원 + 선택적 핑크 ring.
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
    this.tone = AvatarTone.pink,
    this.ring = false,
    this.imageUrl,
  });

  List<Color> get _gradient {
    switch (tone) {
      case AvatarTone.pink:
        return const [Color(0xFFFF8EB5), Color(0xFFE84C88)];
      case AvatarTone.coral:
        return const [Color(0xFFFFCABD), Color(0xFFFF8E7A)];
      case AvatarTone.lilac:
        return const [Color(0xFFE6D5FF), Color(0xFFB08AE8)];
      case AvatarTone.mint:
        return const [Color(0xFFD5F5E6), Color(0xFF7DCFA4)];
      case AvatarTone.cream:
        return const [Color(0xFFFFF7F1), Color(0xFFFFE0CC)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = label.isEmpty ? '🙂' : label.characters.first.toUpperCase();
    Widget circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _gradient,
        ),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? ClipOval(
              child: Image.network(
                imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _initialText(initial),
              ),
            )
          : _initialText(initial),
    );

    if (ring) {
      circle = Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: const [
            BoxShadow(color: AppColors.pink500, blurRadius: 0, spreadRadius: 1.5),
          ],
        ),
        child: circle,
      );
    }
    return circle;
  }

  Widget _initialText(String initial) {
    final fontSize = size * 0.4;
    return Text(
      initial,
      style: AppTextStyles.captionBold.copyWith(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
