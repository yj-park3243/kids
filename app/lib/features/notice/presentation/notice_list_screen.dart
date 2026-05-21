import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../widgets/app_bar.dart';
import '../providers/notice_provider.dart';

class NoticeListScreen extends ConsumerWidget {
  const NoticeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncNotices = ref.watch(noticeListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
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
            onRefresh: () => ref.refresh(noticeListProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notices.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.divider),
              itemBuilder: (context, i) {
                final n = notices[i];
                return ListTile(
                  onTap: () => context.push('/notices/${n.id}'),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  title: Row(
                    children: [
                      if (n.isPinned) ...[
                        const Icon(Icons.push_pin_rounded,
                            size: 15, color: AppColors.primary),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          n.title,
                          style: AppTextStyles.body1Bold,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _formatDate(n.createdAt),
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textHint),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textHint),
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
          Icon(icon, size: 48, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text(
            text,
            style:
                AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ],
      ),
    );
  }
}
