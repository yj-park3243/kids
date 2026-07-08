import '../../../widgets/top_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/design/avatar.dart';
import '../../../widgets/design/glass_card.dart';
import '../../../widgets/design/accent_blobs.dart';
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: '모임 후기'),
      extendBodyBehindAppBar: true,
      body: AccentBlobsBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _NoticeBanner(),
                const SizedBox(height: 14),
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
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.error),
                  ),
                  const SizedBox(height: 8),
                ],
                PrimaryButton(
                  key: const Key('btn-review-submit'),
                  text: state.allSubmitted ? '제출 완료' : '제출',
                  isLoading: state.isSubmitting,
                  isEnabled: !state.allSubmitted,
                  onPressed: state.allSubmitted
                      ? null
                      : () => _onSubmit(context, notifier),
                ),
              ],
            ),
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
    showTopToast(context, ok ? '후기를 제출했어요' : '일부 후기 제출에 실패했어요', backgroundColor: ok ? AppColors.primary : AppColors.error);
    if (ok) {
      // 마이페이지 또는 홈으로 이동. router 미통합이라 단순 pop.
      Navigator.of(context).maybePop();
    }
  }
}

class _NoticeBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tone: GlassTone.white,
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: AppColors.primary700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '모임 종료 후 7일 이내만 작성/수정 가능합니다.',
              style: AppTextStyles.caption.copyWith(color: AppColors.primary700),
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
    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialAvatar(
                label: member.nickname,
                size: 44,
                tone: AvatarTone.primary,
                imageUrl: member.profileImageUrl,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  member.nickname,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 16),
                ),
              ),
              if (draft.submitted)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.primary, size: 22),
            ],
          ),
          const SizedBox(height: 14),
          Text('쑥쑥 점수', style: AppTextStyles.body2Bold),
          const SizedBox(height: 6),
          _ScoreSlider(
            score: draft.score,
            enabled: !draft.submitted,
            onChanged: onScoreChanged,
          ),
          const SizedBox(height: 14),
          Text('정성 태그', style: AppTextStyles.body2Bold),
          const SizedBox(height: 8),
          TagPicker(
            options: kReviewTags,
            selected: draft.tags,
            onToggle: draft.submitted ? (_) {} : onTagToggle,
          ),
          const SizedBox(height: 14),
          Text('후기 (선택)', style: AppTextStyles.body2Bold),
          const SizedBox(height: 6),
          TextField(
            key: Key('input-review-comment-${member.id}'),
            enabled: !draft.submitted,
            maxLength: 200,
            maxLines: 3,
            inputFormatters: [LengthLimitingTextInputFormatter(200)],
            onChanged: onCommentChanged,
            decoration: InputDecoration(
              hintText: '함께한 시간에 대한 후기를 남겨주세요',
              hintStyle: AppTextStyles.body2
                  .copyWith(color: AppColors.textHint),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.primary200, width: 0.8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.primary200, width: 0.8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.2),
              ),
            ),
          ),
          if (draft.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                draft.error!,
                style:
                    AppTextStyles.caption.copyWith(color: AppColors.error),
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
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.primary100,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary200,
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
            style: AppTextStyles.body1Bold.copyWith(color: AppColors.primary700),
          ),
        ),
      ],
    );
  }
}
