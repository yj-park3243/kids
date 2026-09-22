import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_error.dart';
import '../../../models/follow.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/design/avatar.dart';
import '../../../widgets/design/notebook.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading.dart';
import '../../../widgets/top_toast.dart';
import '../providers/follow_provider.dart';
import '../../review/presentation/widgets/growth_grade.dart';
import 'widgets/follow_button.dart';

/// 단골 부모 — [팔로잉 | 팔로워] 두 탭. 팔로워 탭에서 바로 맞팔로우할 수 있다.
class FollowingListScreen extends ConsumerWidget {
  const FollowingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final following = ref.watch(followingProvider);
    final followers = ref.watch(followersProvider);
    final followingCount = following.items.length;
    final followerCount = followers.value?.length;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.paper,
        appBar: const CustomAppBar(title: '단골 부모'),
        body: SafeArea(
          child: Column(
            children: [
              TabBar(
                labelColor: AppColors.ink,
                unselectedLabelColor: AppColors.ink3,
                labelStyle: AppTextStyles.body1Bold,
                unselectedLabelStyle: AppTextStyles.body1,
                indicatorColor: AppColors.ink,
                indicatorWeight: 2,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: AppColors.line,
                dividerHeight: 1,
                tabs: [
                  Tab(text: '팔로잉 $followingCount'),
                  Tab(
                      text: followerCount == null
                          ? '팔로워'
                          : '팔로워 $followerCount'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _FollowingTab(state: following),
                    _FollowersTab(async: followers),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FollowingTab extends ConsumerWidget {
  final FollowingState state;
  const _FollowingTab({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading && state.items.isEmpty) {
      return const AppLoadingIndicator();
    }
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        message: state.error!,
        onRetry: () => ref.read(followingProvider.notifier).load(),
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.favorite_border_rounded,
        title: '팔로우한 부모가 아직 없어요',
        subtitle: '함께 모임을 가진 부모를 팔로우해보세요',
      );
    }
    return RefreshIndicator(
      color: AppColors.ink,
      onRefresh: () => ref.read(followingProvider.notifier).load(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        itemCount: state.items.length,
        separatorBuilder: (_, __) => const DashedDivider(),
        itemBuilder: (context, i) {
          final f = state.items[i];
          return _FollowTile(
            follow: f,
            trailing: _UnfollowButton(
                onTap: () => _confirmUnfollow(context, ref, f)),
            onTap: () => context.push('/users/${f.targetUserId}'),
          );
        },
      ),
    );
  }

  Future<void> _confirmUnfollow(
    BuildContext context,
    WidgetRef ref,
    Follow f,
  ) async {
    var ok = false;
    await AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.scale,
      title: '언팔로우',
      desc: '${f.nickname} 님을 언팔로우 할까요?',
      btnCancelText: '취소',
      btnOkText: '언팔로우',
      btnCancelOnPress: () {},
      btnOkOnPress: () => ok = true,
    ).show();
    if (!ok) return;
    await ref.read(followingProvider.notifier).unfollow(f.targetUserId);
    final error = ref.read(followingProvider).error;
    if (error != null && context.mounted) {
      showTopToast(context, error, backgroundColor: AppColors.error);
    }
    // 팔로워 탭의 맞팔 표시도 갱신.
    ref.invalidate(followersProvider);
  }
}

class _FollowersTab extends ConsumerWidget {
  final AsyncValue<List<Follow>> async;
  const _FollowersTab({required this.async});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return async.when(
      loading: () => const AppLoadingIndicator(),
      error: (e, _) => ErrorState(
        message: apiErrorMessage(e, fallback: '팔로워 목록을 불러올 수 없어요'),
        onRetry: () => ref.invalidate(followersProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.people_outline_rounded,
            title: '아직 나를 팔로우한 부모가 없어요',
            subtitle: '모임에서 좋은 인상을 남기면 단골이 생겨요',
          );
        }
        return RefreshIndicator(
          color: AppColors.ink,
          onRefresh: () async => ref.refresh(followersProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => const DashedDivider(),
            itemBuilder: (context, i) {
              final f = items[i];
              return _FollowTile(
                follow: f,
                trailing: FollowButton(
                  targetUserId: f.targetUserId,
                  isFollowing: f.isFollowing ?? false,
                  height: 32,
                  // 맞팔로우하면 팔로잉 탭 목록도 바뀐다.
                  onChanged: (_) =>
                      ref.read(followingProvider.notifier).load(),
                ),
                onTap: () => context.push('/users/${f.targetUserId}'),
              );
            },
          ),
        );
      },
    );
  }
}

class _FollowTile extends StatelessWidget {
  final Follow follow;
  final Widget trailing;
  final VoidCallback onTap;

  const _FollowTile({
    required this.follow,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            InitialAvatar(
              label: follow.nickname,
              size: 48,
              tone: InitialAvatar.toneFor(follow.targetUserId),
              imageUrl: follow.profileImageUrl,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(follow.nickname, style: AppTextStyles.cardTitle),
                  const SizedBox(height: 5),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GrowthGradeChip(score: follow.mannerScore),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _UnfollowButton extends StatelessWidget {
  final VoidCallback onTap;

  const _UnfollowButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: AppColors.surface,
          border: Border.all(color: AppColors.line2),
        ),
        child: Center(
          child: Text(
            '언팔로우',
            style: AppTextStyles.chip.copyWith(color: AppColors.ink2),
          ),
        ),
      ),
    );
  }
}
