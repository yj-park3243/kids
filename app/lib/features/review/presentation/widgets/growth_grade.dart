import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_shadows.dart';
import '../../../../core/constants/app_text_styles.dart';

/// 쑥쑥 등급 — 같이크자 컨셉의 신뢰 지표.
/// 점수(0~) 를 단계(새싹/떡잎/어린나무/큰나무/숲)로 매핑해서 표시.
/// 쑥쑥 등급 단계.
/// 가입은 [sprout] (떡잎) 부터 시작. 호평/모임 누적으로 위로 성장,
/// 신고·노쇼로 점수가 떨어지면 [seedling] (새싹) 으로 강등될 수 있다.
enum GrowthStage {
  seedling, // 새싹(강등) 0~9
  sprout, // 떡잎(시작)  10~29
  sapling, // 어린나무   30~59
  tree, // 큰나무       60~99
  forest, // 숲          100+
}

class GrowthGradeInfo {
  final GrowthStage stage;
  final String label;
  final String emoji;
  final Color color;
  final double progressToNext; // 0.0~1.0, 다음 단계까지 진행률
  final int nextThreshold; // 다음 단계 임계값 (현재 단계 마지막이면 현재값)

  const GrowthGradeInfo({
    required this.stage,
    required this.label,
    required this.emoji,
    required this.color,
    required this.progressToNext,
    required this.nextThreshold,
  });

  static GrowthGradeInfo fromScore(double score) {
    final s = score < 0 ? 0.0 : score;
    if (s < 10) {
      // 강등 단계 — 시들한 회갈색 톤으로 경고 의미 표시.
      return GrowthGradeInfo(
        stage: GrowthStage.seedling,
        label: '새싹',
        emoji: '🌱',
        color: const Color(0xFFB89B85),
        progressToNext: s / 10,
        nextThreshold: 10,
      );
    }
    if (s < 30) {
      // 시작 단계 — 가장 밝은 연두로 "막 자라기 시작" 느낌.
      return GrowthGradeInfo(
        stage: GrowthStage.sprout,
        label: '떡잎',
        emoji: '🪴',
        color: AppColors.accentLime,
        progressToNext: (s - 10) / 20,
        nextThreshold: 30,
      );
    }
    if (s < 60) {
      return GrowthGradeInfo(
        stage: GrowthStage.sapling,
        label: '어린나무',
        emoji: '🌿',
        color: const Color(0xFF7BC47F),
        progressToNext: (s - 30) / 30,
        nextThreshold: 60,
      );
    }
    if (s < 100) {
      return GrowthGradeInfo(
        stage: GrowthStage.tree,
        label: '큰나무',
        emoji: '🌳',
        color: const Color(0xFF2E7D5C),
        progressToNext: (s - 60) / 40,
        nextThreshold: 100,
      );
    }
    return GrowthGradeInfo(
      stage: GrowthStage.forest,
      label: '숲',
      emoji: '🌲',
      color: const Color(0xFF1F5C46),
      progressToNext: 1.0,
      nextThreshold: 100,
    );
  }
}

/// 큰 원형 게이지 — 마이페이지/프로필 요약 등 강조 위치용.
class GrowthGrade extends StatelessWidget {
  final double score;
  final double size;
  final bool showLabel;

  const GrowthGrade({
    super.key,
    required this.score,
    this.size = 120,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final info = GrowthGradeInfo.fromScore(score);
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
                  value: info.progressToNext,
                  strokeWidth: size * 0.085,
                  backgroundColor: AppColors.primary100,
                  valueColor: AlwaysStoppedAnimation(info.color),
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
                        info.emoji,
                        style: TextStyle(fontSize: size * 0.22, height: 1.0),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        info.label,
                        style: AppTextStyles.cardTitle.copyWith(
                          color: info.color,
                          fontSize: size * 0.14,
                          height: 1.0,
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
            '쑥쑥 등급',
            style: AppTextStyles.caption.copyWith(color: AppColors.ink700),
          ),
        ],
      ],
    );
  }
}

/// 작은 칩 — 카드/리스트의 한 줄 표시용.
class GrowthGradeChip extends StatelessWidget {
  final double score;

  const GrowthGradeChip({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final info = GrowthGradeInfo.fromScore(score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(info.emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            info.label,
            style: AppTextStyles.caption.copyWith(
              color: info.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
