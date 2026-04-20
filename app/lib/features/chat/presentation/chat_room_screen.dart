import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/chat_message.dart';
import '../../../widgets/app_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_provider.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String chatRoomId;

  const ChatRoomScreen({super.key, required this.chatRoomId});

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  /// Newest-first list. History arrives via REST; live updates append (insert at 0).
  final List<ChatMessage> _messages = [];
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      final page = await repo.fetchMessages(widget.chatRoomId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(page.items);
        _loadingHistory = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingHistory = false);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final user = ref.read(authProvider).user;
    if (user == null) return;

    _messageController.clear();
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(widget.chatRoomId, content: content);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('메시지 전송 실패: $e')),
      );
    }
  }

  void _handleIncoming(ChatMessage message) {
    if (_messages.any((m) => m.id == message.id)) return;
    setState(() {
      _messages.insert(0, message);
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authProvider).user?.id ?? '';

    // Bind live stream via ref.listen so rebuilds don't re-subscribe.
    ref.listen<AsyncValue<ChatMessage>>(
      chatMessageStreamProvider(widget.chatRoomId),
      (_, next) {
        final message = next.value;
        if (message != null) _handleIncoming(message);
      },
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: '채팅'),
      body: Column(
        children: [
          Expanded(
            child: _loadingHistory
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  )
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          '첫 번째 메시지를 보내보세요!',
                          style: AppTextStyles.body2
                              .copyWith(color: AppColors.textHint),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isMine = message.senderId == userId;

                          if (message.isSystem) {
                            return _SystemMessage(message: message);
                          }
                          return _ChatBubble(message: message, isMine: isMine);
                        },
                      ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              8,
              MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: AppTextStyles.body2,
                      decoration: InputDecoration(
                        hintText: '메시지를 입력하세요',
                        hintStyle: AppTextStyles.body2
                            .copyWith(color: AppColors.textHint),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;

  const _ChatBubble({
    required this.message,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMine) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.surfaceVariant,
              child: Text(
                message.senderNickname.isNotEmpty
                    ? message.senderNickname[0]
                    : '?',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    message.senderNickname,
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isMine) ...[
                    Text(
                      AppDateUtils.formatChatTime(message.createdAt),
                      style: AppTextStyles.caption.copyWith(fontSize: 10),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.65,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMine
                          ? AppColors.chatBubbleMine
                          : AppColors.chatBubbleOther,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft:
                            isMine ? const Radius.circular(16) : Radius.zero,
                        bottomRight:
                            isMine ? Radius.zero : const Radius.circular(16),
                      ),
                    ),
                    child: Text(
                      message.content,
                      style: AppTextStyles.body2.copyWith(
                        color: isMine ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (!isMine) ...[
                    const SizedBox(width: 6),
                    Text(
                      AppDateUtils.formatChatTime(message.createdAt),
                      style: AppTextStyles.caption.copyWith(fontSize: 10),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SystemMessage extends StatelessWidget {
  final ChatMessage message;

  const _SystemMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.textHint.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.content,
            style: AppTextStyles.caption.copyWith(fontSize: 11),
          ),
        ),
      ),
    );
  }
}
