import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/design/notebook.dart';
import '../providers/notice_provider.dart';

class NoticeListScreen extends ConsumerWidget {
  const NoticeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncNotices = ref.watch(noticeListProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: const CustomAppBar(title: '공지사항'),
      body: asyncNotices.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message(
          icon: Icons.error_outline_rounded,
          text: '공지사항을 불러올 수 없습니다.',
          onRetry: () => ref.invalidate(noticeListProvider),
        ),
        data: (notices) {
          if (notices.isEmpty) {
            return const _Message(
              icon: Icons.campaign_outlined,
              text: '등록된 공지사항이 없습니다.',
            );
          }
          return RefreshIndicator(
            color: AppColors.ink,
            onRefresh: () => ref.refresh(noticeListProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              itemCount: notices.length,
              separatorBuilder: (_, __) => const DashedDivider(),
              itemBuilder: (context, i) {
                final n = notices[i];
                return InkWell(
                  onTap: () => context.push('/notices/${n.id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Row(
                      children: [
                        if (n.isPinned) ...[
                          const Icon(Icons.push_pin_rounded,
                              size: 15, color: AppColors.ink),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                n.title,
                                style: AppTextStyles.cardTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(_formatDate(n.createdAt),
                                  style: AppTextStyles.caption),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right_rounded,
                            size: 18, color: AppColors.line2),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

String _formatDate(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  const _Message({required this.icon, required this.text, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.ink3),
          const SizedBox(height: 12),
          Text(text, style: AppTextStyles.body2),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ],
      ),
    );
  }
}
