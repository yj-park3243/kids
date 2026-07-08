import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/design/design_chip.dart';
import '../../../widgets/design/glass_card.dart';
import '../../../widgets/design/accent_blobs.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading.dart';
import '../data/review_repository.dart';
import '../providers/review_provider.dart';
import 'widgets/growth_grade.dart';

class ReviewSummaryScreen extends ConsumerWidget {
  final String userId;

  const ReviewSummaryScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aggregateAsync = ref.watch(userReviewAggregateProvider(userId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: '받은 후기'),
      extendBodyBehindAppBar: true,
      body: AccentBlobsBackground(
        child: SafeArea(
          child: aggregateAsync.when(
            loading: () => const AppLoadingIndicator(),
            error: (e, _) => ErrorState(
              message: '후기를 불러올 수 없어요',
              onRetry: () => ref.invalidate(userReviewAggregateProvider(userId)),
            ),
            data: (agg) => _Body(agg: agg),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final ReviewAggregate agg;

  const _Body({required this.agg});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 쑥쑥 등급 게이지
          GlassCard(
            tone: GlassTone.white,
            radius: 24,
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                GrowthGrade(score: agg.mannerScore, size: 140),
                const SizedBox(height: 12),
                Text(
                  '받은 후기 ${agg.reviewCount}개',
                  style: AppTextStyles.body1Bold
                      .copyWith(color: AppColors.primary700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Top tags
          if (agg.topTags.isNotEmpty) ...[
            GlassCard(
              radius: 22,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('가장 많이 받은 태그', style: AppTextStyles.body1Bold),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: agg.topTags.take(3).map((t) {
                      return DesignChip(
                        label: '${t.tag} · ${t.count}',
                        tone: ChipTone.primaryGhost,
                        height: 30,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 점수 분포
          if (agg.scoreDistribution.isNotEmpty)
            GlassCard(
              radius: 22,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('점수 분포', style: AppTextStyles.body1Bold),
                  const SizedBox(height: 12),
                  ..._buildDistributionBars(agg.scoreDistribution),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildDistributionBars(Map<String, int> dist) {
    final keys = ['5', '4', '3', '2', '1'];
    final total = dist.values.fold<int>(0, (a, b) => a + b);
    return keys.map((k) {
      final count = dist[k] ?? 0;
      final ratio = total == 0 ? 0.0 : count / total;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '$k점',
                style: AppTextStyles.caption.copyWith(color: AppColors.ink700),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  backgroundColor: AppColors.primary100,
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 32,
              child: Text(
                '$count',
                textAlign: TextAlign.right,
                style: AppTextStyles.caption.copyWith(color: AppColors.ink500),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
