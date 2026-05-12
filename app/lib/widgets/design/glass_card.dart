import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../core/constants/app_shadows.dart';

enum GlassTone { white }

/// 흰 베이스 카드. `accentColor` 지정 시 좌측 3px 컬러 보더 표시.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final GlassTone tone;
  final VoidCallback? onTap;
  final double blur;
  final double? width;
  final double? height;
  final Color? accentColor;
  final double accentWidth;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppRadius.md,
    this.tone = GlassTone.white,
    this.onTap,
    this.blur = 22,
    this.width,
    this.height,
    this.accentColor,
    this.accentWidth = 3,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);

    final decoration = BoxDecoration(
      borderRadius: borderRadius,
      color: AppColors.surface,
      border: Border.all(color: AppColors.divider, width: 1),
      boxShadow: AppShadows.glass,
    );

    Widget body = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: decoration,
      child: child,
    );

    if (accentColor != null) {
      body = ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          children: [
            body,
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: accentWidth,
                color: accentColor,
              ),
            ),
          ],
        ),
      );
    }

    if (onTap != null) {
      body = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: body,
        ),
      );
    }

    return body;
  }
}
