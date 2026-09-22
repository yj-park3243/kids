import '../../../widgets/top_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/design/avatar.dart';
import '../../../widgets/design/glass_card.dart';
import '../../../widgets/design/notebook.dart';
import '../../../widgets/design/primary_button.dart';
import '../providers/review_provider.dart';
import 'widgets/tag_picker.dart';

/// 후기 작성 화면 진입 인자.
/// 라우트: /reviews/write?roomId=X (members는 라우트 extra로 전달)
class ReviewWriteArgs {
  final String roomId;
  final List<ReviewMember> members;

  const ReviewWriteArgs({required this.roomId, required this.members});
}

class ReviewMember {
  final String id;
  final String nickname;
  final String? profileImageUrl;

  const ReviewMember({
    required this.id,
    required this.nickname,
    this.profileImageUrl,
  });
}

class ReviewWriteScreen extends ConsumerWidget {
  final ReviewWriteArgs args;

  const ReviewWriteScreen({super.key, required this.args});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providerArgs = (
      roomId: args.roomId,
      targetUserIds: args.members.map((m) => m.id).toList(),
    );
    final state = ref.watch(reviewWriteProvider(providerArgs));
    final notifier = ref.read(reviewWriteProvider(providerArgs).notifier);

    // 기존 후기를 채우기 전엔 폼을 그리지 않는다 (댓글 initialValue 는 첫 빌드에만 먹는다).
    if (state.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.paper,
        appBar: CustomAppBar(title: '모임 후기'),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.ink),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: const CustomAppBar(title: '모임 후기'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _NoticeBanner(),
              const SizedBox(height: 16),
              ...args.members.map((m) {
                final draft = state.drafts[m.id] ?? const ReviewDraft();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _MemberReviewCard(
                    member: m,
                    draft: draft,
                    onScoreChanged: (s) => notifier.setScore(m.id, s),
                    onTagToggle: (t) => notifier.toggleTag(m.id, t),
                    onCommentChanged: (c) => notifier.setComment(m.id, c),
                  ),
                );
              }),
              const SizedBox(height: 8),
              if (state.globalError != null) ...[
                Text(
                  state.globalError!,
                  style: AppTextStyles.caption.copyWith(color: AppColors.bad),
                ),
                const SizedBox(height: 8),
              ],
              PrimaryButton(
                key: const Key('btn-review-submit'),
                text: state.allSaved
                    ? '저장됨'
                    : state.anySaved
                        ? '수정 저장'
                        : '제출',
                isLoading: state.isSubmitting,
                isEnabled: !state.allSaved,
                onPressed: state.allSaved
                    ? null
                    : () => _onSubmit(context, notifier),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onSubmit(
    BuildContext context,
    ReviewWriteNotifier notifier,
  ) async {
    final ok = await notifier.submitAll();
    if (!context.mounted) return;
    showTopToast(context, ok ? '후기를 저장했어요' : '일부 후기 저장에 실패했어요',
        backgroundColor: ok ? AppColors.ink : AppColors.error);
    if (ok) {
      // 마이페이지 또는 홈으로 이동. router 미통합이라 단순 pop.
      Navigator.of(context).maybePop();
    }
  }
}

/// 작성 기한 안내 — 점선 상자(약속).
class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner();

  @override
  Widget build(BuildContext context) {
    return DashedBox(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.ink3),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '모임 종료 후 7일 이내만 작성/수정 가능합니다.',
              style: AppTextStyles.caption.copyWith(color: AppColors.ink2),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberReviewCard extends StatelessWidget {
  final ReviewMember member;
  final ReviewDraft draft;
  final ValueChanged<int> onScoreChanged;
  final ValueChanged<String> onTagToggle;
  final ValueChanged<String> onCommentChanged;

  const _MemberReviewCard({
    required this.member,
    required this.draft,
    required this.onScoreChanged,
    required this.onTagToggle,
    required this.onCommentChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialAvatar(
                label: member.nickname,
                size: 44,
                tone: InitialAvatar.toneFor(member.id),
                imageUrl: member.profileImageUrl,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  member.nickname,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 16),
                ),
              ),
              // 서버에 저장된 후기 — 7일 이내면 그대로 고쳐서 다시 저장할 수 있다.
              if (draft.reviewId != null)
                Icon(
                  draft.dirty
                      ? Icons.edit_note_rounded
                      : Icons.check_circle_rounded,
                  color: draft.dirty ? AppColors.ink3 : AppColors.ink,
                  size: 22,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text('쑥쑥 점수', style: AppTextStyles.captionBold),
          const SizedBox(height: 6),
          _ScoreSlider(
            score: draft.score,
            enabled: true,
            onChanged: onScoreChanged,
          ),
          const SizedBox(height: 14),
          Text('정성 태그', style: AppTextStyles.captionBold),
          const SizedBox(height: 8),
          TagPicker(
            options: kReviewTags,
            selected: draft.tags,
            onToggle: onTagToggle,
          ),
          const SizedBox(height: 14),
          Text('후기 (선택)', style: AppTextStyles.captionBold),
          const SizedBox(height: 6),
          TextFormField(
            key: Key('input-review-comment-${member.id}'),
            initialValue: draft.comment,
            maxLength: 200,
            maxLines: 3,
            style: AppTextStyles.body1,
            cursorColor: AppColors.ink,
            inputFormatters: [LengthLimitingTextInputFormatter(200)],
            onChanged: onCommentChanged,
            decoration: InputDecoration(
              hintText: '함께한 시간에 대한 후기를 남겨주세요',
              hintStyle:
                  AppTextStyles.body2.copyWith(color: AppColors.ink3),
              filled: true,
              fillColor: AppColors.surface,
              counterStyle: AppTextStyles.caption,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.line2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.line2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.ink, width: 1.5),
              ),
            ),
          ),
          if (draft.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                draft.error!,
                style: AppTextStyles.caption.copyWith(color: AppColors.bad),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScoreSlider extends StatelessWidget {
  final int score;
  final bool enabled;
  final ValueChanged<int> onChanged;

  const _ScoreSlider({
    required this.score,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.ink,
              inactiveTrackColor: AppColors.fill,
              thumbColor: AppColors.ink,
              overlayColor: AppColors.line,
              activeTickMarkColor: AppColors.surface,
              inactiveTickMarkColor: AppColors.line2,
              valueIndicatorColor: AppColors.ink,
              trackHeight: 4,
            ),
            child: Slider(
              value: score.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: '$score',
              onChanged:
                  enabled ? (v) => onChanged(v.round()) : null,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 32,
          child: Text(
            '$score',
            textAlign: TextAlign.center,
            style: AppTextStyles.handLg,
          ),
        ),
      ],
    );
  }
}
