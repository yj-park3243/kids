import 'package:flutter/material.dart';

enum BabyAvatarTone { primary, coral, lilac }

/// 아기 얼굴 placeholder: radial gradient + 눈 2개 + 볼터치 + 미소.
class BabyAvatar extends StatelessWidget {
  final double size;
  final BabyAvatarTone tone;
  final String? imageUrl;

  const BabyAvatar({
    super.key,
    this.size = 64,
    this.tone = BabyAvatarTone.primary,
    this.imageUrl,
  });

  List<Color> get _bgGradient {
    switch (tone) {
      case BabyAvatarTone.primary:
        return const [Color(0xFFFCDDE5), Color(0xFFF9A8BF)];
      case BabyAvatarTone.coral:
        return const [Color(0xFFFFE0D2), Color(0xFFFFC0AC)];
      case BabyAvatarTone.lilac:
        return const [Color(0xFFEEE5FA), Color(0xFFD5C7F2)];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _facePlaceholder(),
        ),
      );
    }
    return _facePlaceholder();
  }

  Widget _facePlaceholder() {
    final eyeSize = size * 0.08;
    final eyeOffsetX = size * 0.22;
    final eyeOffsetY = size * 0.4;
    final cheekSize = size * 0.14;
    final cheekOffsetX = size * 0.32;
    final cheekOffsetY = size * 0.54;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: _bgGradient,
          stops: const [0.2, 1.0],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Eyes
          Positioned(
            top: eyeOffsetY,
            left: size / 2 - eyeOffsetX - eyeSize / 2,
            child: _eye(eyeSize),
          ),
          Positioned(
            top: eyeOffsetY,
            right: size / 2 - eyeOffsetX - eyeSize / 2,
            child: _eye(eyeSize),
          ),
          // Cheeks
          Positioned(
            top: cheekOffsetY,
            left: size / 2 - cheekOffsetX - cheekSize / 2,
            child: _cheek(cheekSize),
          ),
          Positioned(
            top: cheekOffsetY,
            right: size / 2 - cheekOffsetX - cheekSize / 2,
            child: _cheek(cheekSize),
          ),
          // Smile
          Positioned(
            top: size * 0.6,
            child: Container(
              width: size * 0.2,
              height: size * 0.1,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: const Color(0xFF1A1A2E).withValues(alpha: 0.5),
                    width: size * 0.025,
                  ),
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(size * 0.2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _eye(double s) => Container(
        width: s,
        height: s,
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          shape: BoxShape.circle,
        ),
      );

  Widget _cheek(double s) => Container(
        width: s,
        height: s * 0.55,
        decoration: BoxDecoration(
          color: const Color(0xFFFF9476).withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
        ),
      );
}
