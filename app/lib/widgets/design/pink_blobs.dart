import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// 화면 뒤 배경: 흰 베이스 + 핑크/코랄/라일락 블러 블롭.
class PinkBlobsBackground extends StatelessWidget {
  final Widget child;
  final bool strong;

  const PinkBlobsBackground({
    super.key,
    required this.child,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: strong ? AppColors.bg2 : AppColors.bg),
        Positioned(
          top: -140,
          left: -80,
          child: _blob(
            420,
            strong
                ? AppColors.pink500.withValues(alpha: 0.35)
                : const Color(0xFFFF8EB5).withValues(alpha: 0.35),
          ),
        ),
        Positioned(
          top: -100,
          right: -120,
          child: _blob(
            380,
            strong
                ? const Color(0xFFFF8EB5).withValues(alpha: 0.45)
                : AppColors.coral.withValues(alpha: 0.28),
          ),
        ),
        Positioned(
          bottom: -180,
          left: 40,
          child: _blob(
            420,
            strong
                ? AppColors.coral.withValues(alpha: 0.35)
                : AppColors.lilac.withValues(alpha: 0.32),
          ),
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
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
