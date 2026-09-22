import '../../../widgets/top_toast.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/design/avatar.dart';
import '../../../widgets/design/glass_card.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading.dart';
import '../data/block_repository.dart';
import '../providers/block_provider.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedAsync = ref.watch(blockedUsersProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: const CustomAppBar(title: '차단한 유저'),
      body: SafeArea(
        child: blockedAsync.when(
          loading: () => const AppLoadingIndicator(),
          error: (err, _) => ErrorState(
            message: '차단 목록을 불러올 수 없습니다',
            onRetry: () => ref.invalidate(blockedUsersProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const EmptyState(
                icon: Icons.block_rounded,
                title: '차단한 유저가 없어요',
              );
            }
            return RefreshIndicator(
              color: AppColors.ink,
              onRefresh: () async {
                ref.invalidate(blockedUsersProvider);
                await ref.read(blockedUsersProvider.future);
              },
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final u = items[index];
                  return _BlockedUserTile(
                    user: u,
                    onUnblock: () => _confirmUnblock(context, ref, u),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmUnblock(
    BuildContext context,
    WidgetRef ref,
    BlockedUser user,
  ) async {
    var confirmed = false;
    await AwesomeDialog(
      context: context,
      dialogType: DialogType.question,
      animType: AnimType.scale,
      title: '차단 해제',
      desc: '${user.nickname}님의 차단을 해제하시겠어요?',
      btnCancelText: '취소',
      btnOkText: '해제',
      btnCancelOnPress: () {},
      btnOkOnPress: () => confirmed = true,
    ).show();
    if (!confirmed) return;

    try {
      await ref.read(blockRepositoryProvider).unblock(user.targetUserId);
      ref.invalidate(blockedUsersProvider);
      if (context.mounted) {
        showTopToast(context, '${user.nickname}님의 차단이 해제되었습니다', backgroundColor: AppColors.success);
      }
    } catch (e) {
      if (context.mounted) {
        showTopToast(context, '차단 해제에 실패했습니다', backgroundColor: AppColors.error);
      }
    }
  }
}

class _BlockedUserTile extends StatelessWidget {
  final BlockedUser user;
  final VoidCallback onUnblock;

  const _BlockedUserTile({required this.user, required this.onUnblock});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          InitialAvatar(
            label: user.nickname,
            size: 44,
            tone: InitialAvatar.toneFor(user.targetUserId),
            imageUrl: user.profileImageUrl,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(user.nickname, style: AppTextStyles.body1Bold),
                const SizedBox(height: 2),
                Text('차단일 ${_formatDate(user.createdAt)}',
                    style: AppTextStyles.caption),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            key: Key('btn-unblock-${user.targetUserId}'),
            onTap: onUnblock,
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.line2),
              ),
              child: Text(
                '차단 해제',
                style: AppTextStyles.chip.copyWith(color: AppColors.ink2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    if (iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
