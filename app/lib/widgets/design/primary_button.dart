import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../core/constants/app_text_styles.dart';

/// Primary CTA: 민트 그라디언트 + 흰 텍스트 + 민트 그림자.
class PrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isEnabled;
  final double height;
  final double? width;
  final IconData? icon;
  final double radius;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.height = 52,
    this.width,
    this.icon,
    this.radius = 14,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
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
          // 잉크 단색. 비활성은 회색 면 + 힌트색 글씨 (docs/09_UI_수첩안.md).
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            color: enabled ? AppColors.ink : AppColors.fill,
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
                        Icon(widget.icon,
                            size: 20,
                            color: enabled ? Colors.white : AppColors.ink3),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.text,
                        style: AppTextStyles.button.copyWith(
                          color: enabled ? Colors.white : AppColors.ink3,
                        ),
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
  /// null 이면 가로로 꽉 찬다. 카드 안 작은 버튼은 `compact: true`.
  final double? width;
  final bool compact;

  const GlassButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.height = 52,
    this.radius = 14,
    this.textColor = AppColors.ink,
    this.width,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final h = compact ? 38.0 : height;
    final r = compact ? 11.0 : radius;
    final style = compact ? AppTextStyles.buttonSmall : AppTextStyles.button;
    return InkWell(
      borderRadius: BorderRadius.circular(r),
      onTap: onPressed,
      child: Container(
        width: compact ? width : (width ?? double.infinity),
        height: h,
        // 고정 폭이 주어지면 안쪽 여백은 최소로 — 좁은 폭에서 글자가 넘치지 않게.
        padding: EdgeInsets.symmetric(
          horizontal: width != null ? 8 : (compact ? 14 : 20),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r),
          color: AppColors.surface,
          border: Border.all(color: AppColors.line2, width: 1),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: compact ? 16 : 20, color: textColor),
                SizedBox(width: compact ? 6 : 8),
              ],
              Text(
                text,
                style: style.copyWith(color: textColor),
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
              color: Colors.transparent,
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
                decoration: BoxDecoration(
                  color: AppColors.berry,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.paper, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
