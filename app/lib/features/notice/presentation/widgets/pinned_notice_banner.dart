import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../widgets/design/notebook.dart';
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
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: DashedBox(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            onTap: () => context.push('/notices/${first.id}'),
            child: Row(
              children: [
                const Icon(Icons.push_pin_rounded,
                    size: 16, color: AppColors.ink),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '[공지] ${first.title}',
                    style: AppTextStyles.body2Bold,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.line2),
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
