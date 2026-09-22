import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/user.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/design/avatar.dart';
import '../../../widgets/design/design_chip.dart';
import '../../../widgets/design/glass_card.dart';
import '../../../widgets/design/notebook.dart';
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
      backgroundColor: AppColors.paper,
      appBar: const CustomAppBar(title: '프로필'),
      body: SafeArea(
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
    );
  }
}

class _Body extends StatelessWidget {
  final User user;

  const _Body({required this.user});

  @override
  Widget build(BuildContext context) {
    final intro = user.introduction?.trim();
    final tags = user.mannerTags ?? const <String>[];
    final children = user.children ?? const <Child>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context),
          const SizedBox(height: 18),
          _GrowthCard(user: user),
          if (intro != null && intro.isNotEmpty) ...[
            const SectionHeader(title: '자기소개'),
            Text(intro, style: AppTextStyles.paragraph),
          ],
          if (children.isNotEmpty) ...[
            const SectionHeader(title: '아이'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final c in children) _childPill(c)],
            ),
          ],
          if (tags.isNotEmpty) ...[
            const SectionHeader(title: '받은 후기'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in tags)
                  Pill(label: t, tone: PillTone.sage, height: 26),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // 아바타 · 닉네임 · 부모 구분 · 동네 · 팔로우 버튼
  Widget _header(BuildContext context) {
    final parentLabel = switch (user.parentGender) {
      'MOM' => '엄마',
      'DAD' => '아빠',
      _ => null,
    };
    final region = [
      user.regionSigungu,
      user.regionDong,
    ].whereType<String>().where((v) => v.isNotEmpty).join(' ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        InitialAvatar(
          label: user.nickname ?? '?',
          size: 56,
          imageUrl: user.profileImageUrl,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                user.nickname ?? '이름 없음',
                style: AppTextStyles.screenTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (parentLabel != null || region.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (region.isNotEmpty) Pill(label: region),
                    if (parentLabel != null) Pill(label: parentLabel),
                  ],
                ),
              ],
            ],
          ),
        ),
        // 차단 관계면 서버가 팔로우를 거부하므로 버튼 자체를 숨긴다.
        if (user.isFollowing != null && user.isBlocked != true) ...[
          const SizedBox(width: 10),
          FollowButton(targetUserId: user.id, isFollowing: user.isFollowing!),
        ],
      ],
    );
  }

  Widget _childPill(Child child) {
    final months =
        child.ageMonths ??
        AppDateUtils.calculateAgeMonths(child.birthYear, child.birthMonth);
    final genderLabel = AppConstants.genderLabels[child.gender];
    return Container(
      height: 40,
      padding: const EdgeInsets.only(left: 6, right: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InitialAvatar(
            label: child.nickname,
            size: 28,
            tone: InitialAvatar.toneFor(child.id),
            imageUrl: child.photoUrl,
          ),
          const SizedBox(width: 8),
          if (months < 0)
            Text(
              '${child.nickname} 출산예정',
              style: AppTextStyles.body2.copyWith(fontSize: 13.5),
            )
          else
            Text.rich(
              TextSpan(
                style: AppTextStyles.body2.copyWith(fontSize: 13.5),
                children: [
                  TextSpan(text: '${child.nickname} '),
                  TextSpan(
                    text: '$months',
                    style: AppTextStyles.handLg.copyWith(
                      color: AppColors.skyInk,
                    ),
                  ),
                  TextSpan(
                    text: genderLabel != null ? '개월 · $genderLabel' : '개월',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 쑥쑥 등급 + 참여 모임 · 단골 · 노쇼 통계.
class _GrowthCard extends StatelessWidget {
  final User user;

  const _GrowthCard({required this.user});

  static const _stages = ['새싹', '떡잎', '어린나무', '큰나무', '숲'];

  @override
  Widget build(BuildContext context) {
    final info = GrowthGradeInfo.fromScore(user.mannerScore);
    final stageIndex = GrowthStage.values.indexOf(info.stage);
    final remain = (info.nextThreshold - user.mannerScore).ceil();
    final nextLabel = stageIndex + 1 < _stages.length
        ? _stages[stageIndex + 1]
        : null;
    final noShow = switch (user.noShowLevel) {
      'OCCASIONAL' => '가끔',
      'FREQUENT' => '잦음',
      _ => '없음',
    };

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Pill(
                label: '${info.emoji} 쑥쑥 ${info.label}',
                // 강등 단계(새싹)는 초록을 빼고 회색으로 — growth_grade 와 같은 규칙.
                tone: info.isDemoted ? PillTone.muted : PillTone.sage,
              ),
              const Spacer(),
              if (nextLabel != null && remain > 0)
                Text.rich(
                  TextSpan(
                    style: AppTextStyles.caption,
                    children: [
                      TextSpan(text: '$nextLabel까지 '),
                      TextSpan(
                        text: '$remain',
                        style: AppTextStyles.hand.copyWith(fontSize: 17),
                      ),
                      const TextSpan(text: '점'),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 8,
              color: AppColors.fill,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: info.progressToNext.clamp(0.0, 1.0),
                child: Container(color: info.color),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < _stages.length; i++)
                Expanded(
                  child: Text(
                    _stages[i],
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10.5,
                      color: i == stageIndex ? info.color : AppColors.ink3,
                      fontWeight: i == stageIndex
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const DashedDivider(margin: EdgeInsets.only(top: 14)),
          Row(
            children: [
              _stat('참여 모임', '${user.roomCount ?? 0}', unit: '회'),
              _divider(),
              _stat('단골', '${user.followerCount ?? 0}', unit: '명'),
              _divider(),
              _stat('노쇼', noShow),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 30, color: AppColors.line);

  Widget _stat(String label, String value, {String? unit}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (unit == null)
              Text(value, style: AppTextStyles.cardTitle.copyWith(fontSize: 17))
            else
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: value, style: AppTextStyles.handXl),
                    TextSpan(
                      text: unit,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.ink2,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}
