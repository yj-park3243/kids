import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/chat_message.dart';
import '../../../widgets/design/avatar.dart';
import '../../../widgets/design/notebook.dart';
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
        backgroundColor: AppColors.paper,
        body: EmptyState(
          icon: Icons.chat_bubble_outline_rounded,
          title: '로그인이 필요합니다',
        ),
      );
    }

    final roomsAsync = ref.watch(chatRoomsProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Text('내 방', style: AppTextStyles.screenTitle),
            ),
            Expanded(
              child: roomsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.ink),
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
                    color: AppColors.ink,
                    onRefresh: () async => ref.invalidate(chatRoomsProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                      itemCount: chatRooms.length,
                      separatorBuilder: (_, __) => const DashedDivider(),
                      itemBuilder: (context, index) {
                        final room = chatRooms[index];
                        return GestureDetector(
                          onTap: () => context.push('/chat/${room.id}'),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 15),
                            child: _tileContent(room),
                          ),
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

  Widget _tileContent(ChatRoom chatRoom) {
    return Row(
      children: [
        InitialAvatar(
          label: chatRoom.roomTitle ?? '채',
          size: 44,
          tone: InitialAvatar.toneFor(chatRoom.id),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                chatRoom.roomTitle ?? '채팅방',
                style: AppTextStyles.cardTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
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
            const SizedBox(height: 5),
            if (chatRoom.unreadCount > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.berry,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  chatRoom.unreadCount > 99 ? '99+' : '${chatRoom.unreadCount}',
                  style: AppTextStyles.badge,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
