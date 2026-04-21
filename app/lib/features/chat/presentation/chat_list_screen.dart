import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/chat_message.dart';
import '../../../widgets/design/avatar.dart';
import '../../../widgets/design/glass_card.dart';
import '../../../widgets/design/pink_blobs.dart';
import '../../../widgets/empty_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_provider.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authProvider).user?.id;

    if (userId == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: PinkBlobsBackground(
          child: const EmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            title: '로그인이 필요합니다',
          ),
        ),
      );
    }

    final roomsAsync = ref.watch(chatRoomsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PinkBlobsBackground(
        child: SafeArea(
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
                    child: CircularProgressIndicator(color: AppColors.pink500),
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
                      color: AppColors.pink500,
                      onRefresh: () async => ref.invalidate(chatRoomsProvider),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                        itemCount: chatRooms.length,
                        itemBuilder: (context, index) {
                          final room = chatRooms[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: GlassCard(
                              radius: 20,
                              padding: const EdgeInsets.all(14),
                              onTap: () => context.push('/chat/${room.id}'),
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
      ),
    );
  }

  Widget _tileContent(ChatRoom chatRoom) {
    final tone = AvatarTone.values[chatRoom.id.hashCode.abs() % AvatarTone.values.length];
    return Row(
      children: [
        InitialAvatar(
          label: chatRoom.roomTitle ?? '채',
          size: 46,
          tone: tone,
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
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  gradient: AppColors.pinkGradient,
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
