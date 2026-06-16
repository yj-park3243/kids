import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/user.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/design/accent_blobs.dart';
import '../../../widgets/design/baby_avatar.dart';
import '../../../widgets/design/design_chip.dart';
import '../../../widgets/design/glass_card.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading.dart';
import '../../follow/presentation/widgets/follow_button.dart';
import '../../review/presentation/widgets/growth_grade.dart';
import '../providers/user_profile_provider.dart';

/// 상대방(방장·참여자) 프로필 상세 — 방 상세 화면의 멤버를 탭하면 진입.
class UserProfileScreen extends ConsumerWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider(userId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: '프로필'),
      body: AccentBlobsBackground(
        child: SafeArea(
          top: false,
          child: userAsync.when(
            loading: () => const AppLoadingIndicator(),
            error: (e, _) => ErrorState(
              message: '프로필을 불러올 수 없어요',
              onRetry: () => ref.invalidate(userProfileProvider(userId)),
            ),
            data: (user) => _Body(user: user),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final User user;

  const _Body({required this.user});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _headerCard(context),
          const SizedBox(height: 14),
          _gradeCard(),
          const SizedBox(height: 14),
          _introCard(),
          if (user.children != null && user.children!.isNotEmpty) ...[
            const SizedBox(height: 14),
            _childrenCard(),
          ],
          if (user.mannerTags != null && user.mannerTags!.isNotEmpty) ...[
            const SizedBox(height: 14),
            _mannerTagsCard(),
          ],
          const SizedBox(height: 14),
          _reviewsLink(context),
        ],
      ),
    );
  }

  // 프로필 헤더 — 아바타 / 닉네임 / 부모 구분 · 지역 / 팔로우 버튼
  Widget _headerCard(BuildContext context) {
    final parentLabel = switch (user.parentGender) {
      'MOM' => '엄마',
      'DAD' => '아빠',
      _ => null,
    };
    return GlassCard(
      tone: GlassTone.white,
      radius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.surfaceVariant,
            backgroundImage: user.profileImageUrl != null
                ? NetworkImage(user.profileImageUrl!)
                : null,
            child: user.profileImageUrl == null
                ? const Icon(Icons.person_rounded,
                    size: 40, color: AppColors.textHint)
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            user.nickname ?? '이름 없음',
            style: AppTextStyles.sectionHead,
          ),
          if (parentLabel != null || user.regionSigungu != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (parentLabel != null)
                  DesignChip(
                    label: parentLabel,
                    tone: ChipTone.primaryGhost,
                    height: 22,
                  ),
                if (parentLabel != null && user.regionSigungu != null)
                  const SizedBox(width: 8),
                if (user.regionSigungu != null) ...[
                  const Icon(Icons.location_on_rounded,
                      size: 13, color: AppColors.ink500),
                  const SizedBox(width: 2),
                  Text(user.regionSigungu!, style: AppTextStyles.caption),
                ],
              ],
            ),
          ],
          if (user.isFollowing != null) ...[
            const SizedBox(height: 16),
            Center(
              child: FollowButton(
                targetUserId: user.id,
                isFollowing: user.isFollowing!,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 쑥쑥 등급 + 참여 모임 수 / 노쇼 레벨
  Widget _gradeCard() {
    final noShowLabel = switch (user.noShowLevel) {
      'OCCASIONAL' => '가끔',
      'FREQUENT' => '잦음',
      _ => null,
    };
    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
      child: Column(
        children: [
          GrowthGrade(score: user.mannerScore, size: 130),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _stat('참여 모임', '${user.roomCount ?? 0}회'),
              if (noShowLabel != null) ...[
                Container(
                  width: 1,
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  color: AppColors.divider,
                ),
                _stat('노쇼', noShowLabel),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: AppTextStyles.body1Bold
                .copyWith(color: AppColors.primary700)),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }

  // 자기소개
  Widget _introCard() {
    final intro = user.introduction?.trim();
    final hasIntro = intro != null && intro.isNotEmpty;
    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('자기소개', style: AppTextStyles.body1Bold),
          const SizedBox(height: 10),
          Text(
            hasIntro ? intro : '아직 소개를 작성하지 않았어요.',
            style: AppTextStyles.body2.copyWith(
              color: hasIntro ? AppColors.ink700 : AppColors.ink500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // 아이 정보
  Widget _childrenCard() {
    final children = user.children!;
    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('아이', style: AppTextStyles.body1Bold),
          const SizedBox(height: 12),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _childRow(children[i]),
          ],
        ],
      ),
    );
  }

  Widget _childRow(Child child) {
    final genderLabel = AppConstants.genderLabels[child.gender];
    final age = AppDateUtils.formatAgeMonths(child.ageMonths ?? 0);
    return Row(
      children: [
        BabyAvatar(
          size: 42,
          tone: child.gender == 'MALE'
              ? BabyAvatarTone.lilac
              : BabyAvatarTone.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(child.nickname, style: AppTextStyles.body2Bold),
              const SizedBox(height: 2),
              Text(
                genderLabel != null ? '$age · $genderLabel' : age,
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 자주 받은 칭찬 태그
  Widget _mannerTagsCard() {
    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('자주 받은 칭찬', style: AppTextStyles.body1Bold),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: user.mannerTags!
                .map((t) => DesignChip(
                      label: t,
                      tone: ChipTone.primaryGhost,
                      height: 30,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // 받은 후기 요약 화면으로 이동
  Widget _reviewsLink(BuildContext context) {
    return GlassCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      onTap: () => context.push('/users/${user.id}/reviews'),
      child: Row(
        children: [
          const Icon(Icons.rate_review_rounded,
              size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text('받은 후기 보기', style: AppTextStyles.body2Bold),
          ),
          const Icon(Icons.chevron_right_rounded,
              size: 20, color: AppColors.ink500),
        ],
      ),
    );
  }
}
