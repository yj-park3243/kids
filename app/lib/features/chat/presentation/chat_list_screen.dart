import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/chat_message.dart';
import '../../../widgets/empty_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_provider.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authProvider).user?.id;

    if (userId == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: EmptyState(
          icon: Icons.chat_bubble_outline_rounded,
          title: '로그인이 필요합니다',
        ),
      );
    }

    final roomsAsync = ref.watch(chatRoomsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('채팅', style: AppTextStyles.heading1),
            ),
            Expanded(
              child: roomsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (err, _) => ErrorState(
                  message: '채팅 목록을 불러올 수 없습니다',
                  onRetry: () => ref.invalidate(chatRoomsProvider),
                ),
                data: (chatRooms) {
                  if (chatRooms.isEmpty) {
                    return const EmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: '참여 중인 채팅방이 없습니다',
                      subtitle: '모임에 참여하면 채팅방이 생성됩니다',
                    );
                  }
                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async => ref.invalidate(chatRoomsProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: chatRooms.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (context, index) {
                        final room = chatRooms[index];
                        return _ChatRoomTile(
                          chatRoom: room,
                          onTap: () => context.push('/chat/${room.id}'),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatRoomTile extends StatelessWidget {
  final ChatRoom chatRoom;
  final VoidCallback onTap;

  const _ChatRoomTile({
    required this.chatRoom,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.chat_bubble_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chatRoom.roomTitle ?? '채팅방',
                    style: AppTextStyles.body2Bold,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    chatRoom.lastMessage ?? '메시지가 없습니다',
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (chatRoom.lastMessageAt != null)
                  Text(
                    AppDateUtils.formatChatTime(chatRoom.lastMessageAt!),
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
                const SizedBox(height: 4),
                if (chatRoom.unreadCount > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.unreadBadge,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      chatRoom.unreadCount > 99
                          ? '99+'
                          : '${chatRoom.unreadCount}',
                      style: AppTextStyles.badge,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
