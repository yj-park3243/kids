import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/design/design_chip.dart';
import '../../../widgets/design/notebook.dart';
import '../providers/notice_provider.dart';

class NoticeDetailScreen extends ConsumerWidget {
  final String noticeId;

  const NoticeDetailScreen({super.key, required this.noticeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncNotice = ref.watch(noticeDetailProvider(noticeId));

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: const CustomAppBar(title: '공지사항'),
      body: asyncNotice.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('공지사항을 불러올 수 없습니다.', style: AppTextStyles.body2),
        ),
        data: (n) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (n.isPinned) ...[
                const Pill(
                  label: '중요 공지',
                  tone: PillTone.hi,
                  icon: Icons.push_pin_rounded,
                ),
                const SizedBox(height: 12),
              ],
              Text(n.title, style: AppTextStyles.display),
              const SizedBox(height: 6),
              Text(_formatDate(n.createdAt), style: AppTextStyles.caption),
              const SizedBox(height: 18),
              const DashedDivider(),
              const SizedBox(height: 18),
              Text(
                n.content.replaceAll('\\n', '\n'),
                style: AppTextStyles.paragraph,
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
