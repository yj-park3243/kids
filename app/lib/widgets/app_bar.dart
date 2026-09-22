import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final bool showBack;
  final VoidCallback? onBack;
  final Color? backgroundColor;
  final double elevation;

  const CustomAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.showBack = true,
    this.onBack,
    this.backgroundColor,
    this.elevation = 0,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // 종이 위에 그대로 — 앱바도 배경과 같은 색이라 경계가 없다.
      backgroundColor: backgroundColor ?? Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: elevation,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              color: AppColors.ink900,
              onPressed: onBack ?? () => Navigator.of(context).pop(),
            )
          : null,
      automaticallyImplyLeading: showBack,
      title: titleWidget ??
          (title != null
              ? Text(
                  title!,
                  style: AppTextStyles.screenTitle,
                )
              : null),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
