import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/design/design_chip.dart';
import '../../../widgets/design/accent_blobs.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading.dart';
import '../../home/presentation/widgets/room_card.dart';
import '../providers/growth_guide_provider.dart';

class GrowthGuideDetailScreen extends ConsumerWidget {
  final int ageMonth;
  const GrowthGuideDetailScreen({super.key, required this.ageMonth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guideAsync = ref.watch(growthGuideDetailProvider(ageMonth));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar:
          CustomAppBar(title: AppDateUtils.formatAgeMonths(ageMonth)),
      extendBodyBehindAppBar: true,
      body: AccentBlobsBackground(
        child: SafeArea(
          child: guideAsync.when(
            loading: () => const AppLoadingIndicator(),
            error: (_, __) => ErrorState(
              message: '가이드를 불러오지 못했어요',
              onRetry: () =>
                  ref.invalidate(growthGuideDetailProvider(ageMonth)),
            ),
            data: (guide) {
              final rooms = guide.recommendedRooms ?? const [];
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  if (guide.coverImage != null &&
                      guide.coverImage!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: CachedNetworkImage(
                          imageUrl: guide.coverImage!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: AppColors.primary100),
                          errorWidget: (_, __, ___) =>
                              Container(color: AppColors.primary100),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(guide.title, style: AppTextStyles.screenTitle),
                  const SizedBox(height: 8),
                  Text(
                    guide.summary,
                    style: AppTextStyles.body1.copyWith(
                      color: AppColors.ink700,
                    ),
                  ),
                  if (guide.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: guide.tags
                          .map((t) => DesignChip(
                                label: '#$t',
                                tone: ChipTone.primaryGhost,
                                height: 26,
                              ))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Divider(color: AppColors.divider, height: 1),
                  const SizedBox(height: 16),
                  // TODO: flutter_markdown 패키지 추가되면 MarkdownBody 로 교체.
                  Text(
                    guide.bodyMarkdown,
                    style: AppTextStyles.body1.copyWith(height: 1.7),
                  ),
                  const SizedBox(height: 28),
                  if (rooms.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.recommend_rounded,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text('이번 달 추천 모임',
                            style: AppTextStyles.sectionHead),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...rooms.map((r) => RoomCard(
                          room: r,
                          onTap: () => context.push('/rooms/${r.id}'),
                        )),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
