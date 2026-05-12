import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_radius.dart';
import '../core/constants/app_shadows.dart';
import '../core/constants/app_spacing.dart';
import '../core/constants/app_text_styles.dart';

/// 일관된 라운드 + soft shadow + 여유 padding 의 섹션 카드.
/// 좁고 답답한 인상을 풀기 위해 기본값을 후하게 잡음.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.action,
    this.padding,
    this.margin,
    this.color,
  });

  final Widget child;
  final String? title;
  final Widget? action;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding ?? AppSpacing.cardAll,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: AppRadius.rMd,
        boxShadow: AppShadows.glass,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(title!, style: AppTextStyles.sectionHead),
                ),
                if (action != null) action!,
              ],
            ),
            AppSpacing.gapMdV,
          ],
          child,
        ],
      ),
    );
  }
}

/// 화면 본문 좌우 여백을 일관되게. SafeArea 안에서 사용.
class ScreenPadding extends StatelessWidget {
  const ScreenPadding({super.key, required this.child, this.top = 0, this.bottom = 0});

  final Widget child;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screen,
        top,
        AppSpacing.screen,
        bottom,
      ),
      child: child,
    );
  }
}
