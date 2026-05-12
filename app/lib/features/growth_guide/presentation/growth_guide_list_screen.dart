import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/growth_guide.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/design/glass_card.dart';
import '../../../widgets/design/accent_blobs.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading.dart';
import '../providers/growth_guide_provider.dart';

class GrowthGuideListScreen extends ConsumerWidget {
  const GrowthGuideListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guidesAsync = ref.watch(growthGuideListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: '발달 가이드'),
      extendBodyBehindAppBar: true,
      body: AccentBlobsBackground(
        child: SafeArea(
          child: guidesAsync.when(
            loading: () => const ShimmerList(),
            error: (_, __) => ErrorState(
              message: '발달 가이드를 불러오지 못했어요',
              onRetry: () => ref.invalidate(growthGuideListProvider),
            ),
            data: (guides) {
              if (guides.isEmpty) {
                return const EmptyState(
                  icon: Icons.menu_book_rounded,
                  title: '가이드가 아직 없어요',
                );
              }
              return RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(growthGuideListProvider),
                color: AppColors.primary,
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: guides.length,
                  itemBuilder: (context, index) =>
                      _GuideCard(guide: guides[index]),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  final GrowthGuide guide;
  const _GuideCard({required this.guide});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () => context.push('/growth-guide/${guide.ageMonth}'),
      radius: 20,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: guide.coverImage != null && guide.coverImage!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: guide.coverImage!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: AppColors.primary100),
                      errorWidget: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppDateUtils.formatAgeMonths(guide.ageMonth),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  guide.title,
                  style: AppTextStyles.body2Bold,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      alignment: Alignment.center,
      child: const Icon(Icons.child_care_rounded,
          size: 48, color: Colors.white),
    );
  }
}
