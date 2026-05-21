import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../widgets/app_bar.dart';
import '../providers/notice_provider.dart';

class NoticeDetailScreen extends ConsumerWidget {
  final String noticeId;

  const NoticeDetailScreen({super.key, required this.noticeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncNotice = ref.watch(noticeDetailProvider(noticeId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: '공지사항'),
      body: asyncNotice.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            '공지사항을 불러올 수 없습니다.',
            style:
                AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
          ),
        ),
        data: (n) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (n.isPinned) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: const Text(
                    '중요 공지',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(n.title, style: AppTextStyles.sectionHead),
              const SizedBox(height: 8),
              Text(
                _formatDate(n.createdAt),
                style:
                    AppTextStyles.caption.copyWith(color: AppColors.textHint),
              ),
              const SizedBox(height: 20),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 20),
              Text(
                n.content.replaceAll('\\n', '\n'),
                style: AppTextStyles.body1.copyWith(height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
