import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/follow.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/design/avatar.dart';
import '../../../widgets/design/glass_card.dart';
import '../../../widgets/design/accent_blobs.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading.dart';
import '../providers/follow_provider.dart';
import '../../review/presentation/widgets/growth_grade.dart';

class FollowingListScreen extends ConsumerWidget {
  const FollowingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(followingProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: '단골 부모'),
      body: AccentBlobsBackground(
        child: SafeArea(
          top: false,
          child: _buildBody(context, ref, state),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    FollowingState state,
  ) {
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
      color: AppColors.primary,
      onRefresh: () => ref.read(followingProvider.notifier).load(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: state.items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final f = state.items[i];
          return _FollowingTile(
            follow: f,
            onUnfollow: () => _confirmUnfollow(context, ref, f),
            onTap: () {
              // TODO: navigate to /users/${f.targetUserId}
            },
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('언팔로우'),
        content: Text('${f.nickname} 님을 언팔로우 할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('언팔로우',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(followingProvider.notifier).unfollow(f.targetUserId);
    }
  }
}

class _FollowingTile extends StatelessWidget {
  final Follow follow;
  final VoidCallback onUnfollow;
  final VoidCallback onTap;

  const _FollowingTile({
    required this.follow,
    required this.onUnfollow,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          InitialAvatar(
            label: follow.nickname,
            size: 48,
            tone: AvatarTone.primary,
            imageUrl: follow.profileImageUrl,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  follow.nickname,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 4),
                GrowthGradeChip(score: follow.mannerScore),
              ],
            ),
          ),
          _UnfollowButton(onTap: onUnfollow),
        ],
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
          color: Colors.white.withValues(alpha: 0.7),
          border: Border.all(color: AppColors.primary200, width: 0.8),
        ),
        child: Center(
          child: Text(
            '언팔로우',
            style: AppTextStyles.chip.copyWith(color: AppColors.primary700),
          ),
        ),
      ),
    );
  }
}
