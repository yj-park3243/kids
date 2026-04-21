import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../core/constants/app_shadows.dart';
import '../../core/constants/app_text_styles.dart';

/// Primary CTA: 핑크 그라디언트 + 흰 텍스트 + 핑크 그림자
class PinkButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isEnabled;
  final double height;
  final double? width;
  final IconData? icon;
  final double radius;

  const PinkButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.height = 54,
    this.width,
    this.icon,
    this.radius = 18,
  });

  @override
  State<PinkButton> createState() => _PinkButtonState();
}

class _PinkButtonState extends State<PinkButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.isEnabled && !widget.isLoading && widget.onPressed != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: enabled ? widget.onPressed : null,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 80),
        child: Container(
          width: widget.width ?? double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: enabled ? AppColors.pinkGradient : null,
            color: enabled ? null : AppColors.pink200,
            boxShadow: enabled ? AppShadows.pinkCta : null,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 0.5,
            ),
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.4,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 20, color: Colors.white),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.text,
                        style: AppTextStyles.button.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Secondary glass button
class GlassButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final double radius;
  final Color textColor;

  const GlassButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.height = 54,
    this.radius = 18,
    this.textColor = AppColors.pink700,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(radius),
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: Colors.white.withValues(alpha: 0.7),
          border: Border.all(color: AppColors.pink200, width: 0.8),
          boxShadow: AppShadows.glass,
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: textColor),
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style: AppTextStyles.button.copyWith(color: textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon-only glass button (round)
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color iconColor;
  final bool showDot;

  const GlassIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 42,
    this.iconColor = AppColors.ink700,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: AppRadius.rSm,
              color: Colors.white.withValues(alpha: 0.7),
              border: Border.all(color: AppColors.glassBorder, width: 0.5),
              boxShadow: AppShadows.glass,
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          if (showDot)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.pink500,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
