import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../providers/notice_provider.dart';

/// 홈 화면 앱바 아래에 노출되는 고정 공지 배너.
/// 첫 번째 고정 공지만 보여주고, 탭하면 상세로 이동.
class PinnedNoticeBanner extends ConsumerWidget {
  const PinnedNoticeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinnedAsync = ref.watch(pinnedNoticesProvider);

    return pinnedAsync.maybeWhen(
      data: (notices) {
        if (notices.isEmpty) return const SizedBox.shrink();
        final first = notices.first;
        return GestureDetector(
          onTap: () => context.push('/notices/${first.id}'),
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.primary50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary300),
            ),
            child: Row(
              children: [
                const Icon(Icons.campaign_rounded,
                    size: 20, color: AppColors.primary700),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '[공지] ${first.title}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 12, color: AppColors.primary700),
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
