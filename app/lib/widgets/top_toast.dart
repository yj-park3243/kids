import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';

/// 화면 상단(SafeArea 아래)에 잠깐 떴다 사라지는 토스트.
/// 기본 SnackBar는 화면 하단이라 잘 안 보일 때 사용한다.
void showTopToast(
  BuildContext context,
  String message, {
  Color? backgroundColor,
  Duration duration = const Duration(seconds: 3),
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _TopToast(
      message: message,
      backgroundColor: backgroundColor ?? AppColors.error,
      duration: duration,
      onDismissed: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _TopToast extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final Duration duration;
  final VoidCallback onDismissed;

  const _TopToast({
    required this.message,
    required this.backgroundColor,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_TopToast> createState() => _TopToastState();
}

class _TopToastState extends State<_TopToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  late final Animation<Offset> _offset = Tween(
    begin: const Offset(0, -1),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    _controller.forward();
    Future.delayed(widget.duration, () async {
      if (!mounted) return;
      await _controller.reverse();
      widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offset,
        child: FadeTransition(
          opacity: _controller,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                widget.message,
                style: AppTextStyles.body2.copyWith(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
