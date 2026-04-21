import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../core/constants/app_shadows.dart';

enum GlassTone { white, pink }

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final GlassTone tone;
  final VoidCallback? onTap;
  final double blur;
  final double? width;
  final double? height;

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
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);

    final decoration = tone == GlassTone.pink
        ? BoxDecoration(
            borderRadius: borderRadius,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.glassPinkTop, AppColors.glassPinkBottom],
            ),
            border: Border.all(color: AppColors.glassBorder, width: 0.5),
            boxShadow: AppShadows.glassPink,
          )
        : BoxDecoration(
            borderRadius: borderRadius,
            color: AppColors.glassWhite,
            border: Border.all(color: AppColors.glassBorder, width: 0.5),
            boxShadow: AppShadows.glass,
          );

    Widget content = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: decoration,
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: content,
        ),
      );
    }

    return content;
  }
}
