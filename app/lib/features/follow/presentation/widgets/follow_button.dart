import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_shadows.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../providers/follow_provider.dart';

/// 팔로우/언팔로우 토글 버튼.
/// - 유저 프로필 화면, 방 상세의 호스트 카드 등에서 재사용.
/// - 외부에서 초기 isFollowing을 넘기면 그 값을 시작점으로 사용.
class FollowButton extends ConsumerWidget {
  final String targetUserId;
  final bool isFollowing;
  final double height;
  final ValueChanged<bool>? onChanged;

  const FollowButton({
    super.key,
    required this.targetUserId,
    required this.isFollowing,
    this.height = 36,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (targetUserId: targetUserId, initial: isFollowing);
    final state = ref.watch(followToggleProvider(args));
    final following = state.value ?? isFollowing;
    final loading = state.isLoading;

    return GestureDetector(
      onTap: loading
          ? null
          : () async {
              await ref.read(followToggleProvider(args).notifier).toggle();
              final next = ref.read(followToggleProvider(args)).value;
              if (next != null) onChanged?.call(next);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: following ? null : AppColors.primaryGradient,
          color: following ? Colors.white.withValues(alpha: 0.7) : null,
          border: Border.all(
            color: following ? AppColors.primary200 : Colors.transparent,
            width: 0.8,
          ),
          boxShadow: following ? AppShadows.glass : AppShadows.primaryCta,
        ),
        child: Center(
          child: loading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: following ? AppColors.primary : Colors.white,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      following
                          ? Icons.check_rounded
                          : Icons.person_add_alt_1_rounded,
                      size: 16,
                      color: following ? AppColors.primary700 : Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      following ? '팔로잉' : '팔로우',
                      style: AppTextStyles.chip.copyWith(
                        color:
                            following ? AppColors.primary700 : Colors.white,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
