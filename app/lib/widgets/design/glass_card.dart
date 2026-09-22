import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../core/constants/app_shadows.dart';

enum GlassTone { white }

/// 카드 — 흰 면 + 1px 헤어라인. 그림자 없음.
///
/// 떠 있어야 하는 카드(홈의 '다음 모임')만 [hero] 로 그림자를 준다.
/// 한 화면에 hero 는 하나. 이름(GlassCard)은 호환용이며 유리 효과는 더 이상 없다.
/// `accentColor`(좌측 컬러 바)는 무시된다 — 색 대신 굵기로 강조한다.
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
  final double borderWidth;
  final bool hero;
  final Color? color;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppRadius.md,
    this.tone = GlassTone.white,
    this.onTap,
    this.blur = 0,
    this.width,
    this.height,
    this.accentColor,
    this.accentWidth = 0,
    this.borderWidth = 1,
    this.hero = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(hero ? AppRadius.lg : radius);

    final decoration = BoxDecoration(
      borderRadius: borderRadius,
      color: color ?? AppColors.surface,
      border: Border.all(
        color: hero ? AppColors.line2 : AppColors.line,
        width: borderWidth,
      ),
      boxShadow: hero ? AppShadows.hero : null,
    );

    final body = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: decoration,
      child: child,
    );

    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: body,
      ),
    );
  }
}

/// 새 이름. 내부는 [GlassCard] 와 같다 — 새 코드는 이쪽을 쓴다.
class AppCard extends GlassCard {
  const AppCard({
    super.key,
    required super.child,
    super.padding,
    super.radius,
    super.onTap,
    super.width,
    super.height,
    super.hero,
    super.color,
  });
}
