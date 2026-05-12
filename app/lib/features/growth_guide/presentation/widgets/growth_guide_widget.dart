import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../models/user.dart';
import '../../../../widgets/design/glass_card.dart';
import '../../providers/growth_guide_provider.dart';

/// 홈 화면 상단에 노출되는 발달 가이드 요약 카드.
/// 자녀 1명을 받아 그 자녀의 개월수 가이드를 한 줄 미리보기로 보여준다.
class GrowthGuideWidget extends ConsumerWidget {
  final Child child;
  const GrowthGuideWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ageMonth =
        AppDateUtils.calculateAgeMonths(child.birthYear, child.birthMonth);
    final clampedAge = ageMonth.clamp(0, 72);
    final guideAsync =
        ref.watch(growthGuideDetailProvider(clampedAge));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: GlassCard(
        radius: 20,
        padding: const EdgeInsets.all(14),
        onTap: () => context.push('/growth-guide/$clampedAge'),
        child: guideAsync.when(
          loading: () => _skeleton(),
          error: (_, __) => _content(
            title: '${AppDateUtils.formatAgeMonths(clampedAge)} 발달 가이드',
            summary: '자세히 보러 가기',
          ),
          data: (g) => _content(
            title: g.title,
            summary: g.summary,
            ageLabel: AppDateUtils.formatAgeMonths(clampedAge),
          ),
        ),
      ),
    );
  }

  Widget _content({
    required String title,
    required String summary,
    String? ageLabel,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.menu_book_rounded,
              color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text('발달 가이드',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.primary700)),
                  if (ageLabel != null) ...[
                    const SizedBox(width: 6),
                    Text('· $ageLabel', style: AppTextStyles.caption),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: AppTextStyles.cardTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                summary,
                style: AppTextStyles.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.ink500),
      ],
    );
  }

  Widget _skeleton() {
    return const SizedBox(
      height: 52,
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }
}
