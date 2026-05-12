import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_shadows.dart';
import '../../../../core/constants/app_text_styles.dart';

/// 매너 온도 시각화 위젯.
/// - 기준 36.5°C (분홍)
/// - < 36.5°C: 파랑 톤
/// - > 36.5°C: 빨강(핑크) 톤
/// 표시 범위는 0.0 ~ 100.0 (max는 매너 점수 상한)
class MannerTemperature extends StatelessWidget {
  final double score;
  final double size;
  final bool showLabel;

  const MannerTemperature({
    super.key,
    required this.score,
    this.size = 120,
    this.showLabel = true,
  });

  Color get _color {
    if (score < 36.5) return const Color(0xFF6FA8FF); // cool blue
    if (score > 36.5) return AppColors.primary;
    return AppColors.primary400;
  }

  double get _ratio {
    // 0~100을 0.0~1.0으로
    final clamped = score.clamp(0, 100);
    return clamped / 100.0;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: _ratio,
                  strokeWidth: size * 0.085,
                  backgroundColor: AppColors.primary100,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              Container(
                width: size * 0.7,
                height: size * 0.7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.9),
                  boxShadow: AppShadows.glass,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        score.toStringAsFixed(1),
                        style: AppTextStyles.cardTitle.copyWith(
                          color: color,
                          fontSize: size * 0.22,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '°C',
                        style: AppTextStyles.caption.copyWith(
                          color: color,
                          fontSize: size * 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 10),
          Text(
            '매너 온도',
            style: AppTextStyles.caption.copyWith(color: AppColors.ink700),
          ),
        ],
      ],
    );
  }
}
