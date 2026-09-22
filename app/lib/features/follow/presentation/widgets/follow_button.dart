import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../widgets/top_toast.dart';
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
              final error =
                  await ref.read(followToggleProvider(args).notifier).toggle();
              if (error != null) {
                if (context.mounted) {
                  showTopToast(context, error,
                      backgroundColor: AppColors.error);
                }
                return;
              }
              final next = ref.read(followToggleProvider(args)).value;
              if (next != null) onChanged?.call(next);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        // 팔로우 = 잉크 채움(CTA), 팔로잉 = 흰 면 + 테두리 + 체크.
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: following ? AppColors.surface : AppColors.ink,
          border: Border.all(
            color: following ? AppColors.line2 : AppColors.ink,
          ),
        ),
        child: Center(
          child: loading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: following ? AppColors.ink : Colors.white,
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
                      color: following ? AppColors.ink : Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      following ? '팔로잉' : '팔로우',
                      style: AppTextStyles.chip.copyWith(
                        color: following ? AppColors.ink : Colors.white,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
