import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';
import 'design/pink_button.dart';

/// Legacy PrimaryButton — 내부적으로 PinkButton을 사용.
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isEnabled;
  final double? width;
  final double height;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.width,
    this.height = 54,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return PinkButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      isEnabled: isEnabled,
      height: height,
      width: width,
      icon: icon,
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  const SecondaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GlassButton(
      text: text,
      icon: icon,
      onPressed: isLoading ? null : onPressed,
    );
  }
}

class SocialLoginButton extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback? onPressed;

  const SocialLoginButton({
    super.key,
    required this.text,
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
    this.icon,
    this.iconWidget,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: borderColor != null
                  ? Border.all(color: borderColor!, width: 0.8)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink900.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (iconWidget != null)
                  iconWidget!
                else if (icon != null)
                  Icon(icon, size: 20, color: textColor),
                const SizedBox(width: 10),
                Text(
                  text,
                  style: AppTextStyles.button.copyWith(color: textColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
