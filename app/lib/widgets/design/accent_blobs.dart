import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// 흰 베이스 + 분홍/코랄/라벤더 블러 블롭.
class AccentBlobsBackground extends StatelessWidget {
  final Widget child;
  final bool strong;

  const AccentBlobsBackground({
    super.key,
    required this.child,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    final base = strong ? 0.32 : 0.20;
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: strong ? AppColors.backgroundSoft : AppColors.background),
        Positioned(
          top: -140,
          left: -80,
          child: _blob(420, AppColors.primary.withValues(alpha: base)),
        ),
        Positioned(
          top: -100,
          right: -120,
          child: _blob(380, AppColors.accentCoral.withValues(alpha: base + 0.04)),
        ),
        Positioned(
          bottom: -180,
          left: 40,
          child: _blob(420, AppColors.accentLavender.withValues(alpha: base)),
        ),
        Positioned(
          bottom: -120,
          right: -60,
          child: _blob(320, AppColors.primaryDark.withValues(alpha: base - 0.04)),
        ),
        child,
      ],
    );
  }

  Widget _blob(double size, Color color) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
