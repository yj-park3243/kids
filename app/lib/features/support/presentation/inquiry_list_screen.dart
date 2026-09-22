import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_error.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/design/design_chip.dart';
import '../../../widgets/design/glass_card.dart';
import '../../../widgets/design/notebook.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading.dart';
import '../data/support_repository.dart';

final myInquiriesProvider = FutureProvider.autoDispose<List<Inquiry>>((ref) {
  return ref.watch(supportRepositoryProvider).listMyInquiries();
});

/// 내 1:1 문의 내역 — 답변이 여기로 온다. (푸시 INQUIRY_REPLIED 의 목적지)
class InquiryListScreen extends ConsumerWidget {
  const InquiryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myInquiriesProvider);
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: CustomAppBar(
        title: '1:1 문의',
        actions: [
          TextButton(
            onPressed: () async {
              await context.push('/inquiry');
              ref.invalidate(myInquiriesProvider);
            },
            child: Text('문의하기',
                style: AppTextStyles.body2Bold.copyWith(color: AppColors.ink)),
          ),
        ],
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const AppLoadingIndicator(),
          error: (e, _) => ErrorState(
            message: apiErrorMessage(e, fallback: '문의 내역을 불러오지 못했어요'),
            onRetry: () => ref.invalidate(myInquiriesProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return EmptyState(
                icon: Icons.mail_outline_rounded,
                title: '아직 문의한 내용이 없어요',
                subtitle: '궁금한 점이나 불편한 점을 남겨주세요',
                buttonText: '문의하기',
                onButtonTap: () async {
                  await context.push('/inquiry');
                  ref.invalidate(myInquiriesProvider);
                },
              );
            }
            return RefreshIndicator(
              color: AppColors.ink,
              onRefresh: () async => ref.refresh(myInquiriesProvider.future),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _InquiryCard(inquiry: items[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _InquiryCard extends StatelessWidget {
  final Inquiry inquiry;
  const _InquiryCard({required this.inquiry});

  @override
  Widget build(BuildContext context) {
    final replied = inquiry.reply != null && inquiry.reply!.trim().isNotEmpty;
    final fmt = DateFormat('M월 d일 HH:mm');
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(inquiry.subject, style: AppTextStyles.cardTitle),
              ),
              const SizedBox(width: 8),
              Pill(
                label: replied ? '답변 완료' : '답변 대기',
                tone: replied ? PillTone.hi : PillTone.muted,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(fmt.format(inquiry.createdAt.toLocal()),
              style: AppTextStyles.caption),
          const SizedBox(height: 10),
          Text(inquiry.message, style: AppTextStyles.paragraph),
          if (replied) ...[
            const SizedBox(height: 12),
            DashedBox(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('운영자 답변', style: AppTextStyles.captionBold),
                      const Spacer(),
                      if (inquiry.repliedAt != null)
                        Text(fmt.format(inquiry.repliedAt!.toLocal()),
                            style: AppTextStyles.caption),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(inquiry.reply!, style: AppTextStyles.paragraph),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
