import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/chat_message.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/design/avatar.dart';
import '../../../widgets/design/pink_blobs.dart';
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
    setState(() => _messages.insert(0, message));
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authProvider).user?.id ?? '';

    ref.listen<AsyncValue<ChatMessage>>(
      chatMessageStreamProvider(widget.chatRoomId),
      (_, next) {
        final message = next.value;
        if (message != null) _handleIncoming(message);
      },
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: '채팅'),
      extendBodyBehindAppBar: true,
      body: PinkBlobsBackground(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: _loadingHistory
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.pink500),
                      )
                    : _messages.isEmpty
                        ? Center(
                            child: Text(
                              '첫 번째 메시지를 보내보세요!',
                              style: AppTextStyles.body2
                                  .copyWith(color: AppColors.ink300),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              final isMine = message.senderId == userId;
                              if (message.isSystem) {
                                return _SystemMessage(message: message);
                              }
                              return _ChatBubble(
                                  message: message, isMine: isMine);
                            },
                          ),
              ),
              _InputBar(
                controller: _messageController,
                onSend: _sendMessage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _InputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 7, 7, 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.glassBorder,
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: TextField(
                      controller: controller,
                      style: AppTextStyles.body1,
                      cursorColor: AppColors.pink500,
                      decoration: InputDecoration(
                        hintText: '메시지 보내기...',
                        hintStyle: AppTextStyles.body1
                            .copyWith(color: AppColors.ink300),
                        border: InputBorder.none,
                        isCollapsed: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onSend,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: AppColors.pinkGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.pink500.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;

  const _ChatBubble({required this.message, required this.isMine});

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
            InitialAvatar(
              label: message.senderNickname,
              size: 30,
              tone: AvatarTone
                  .values[message.senderId.hashCode.abs() % AvatarTone.values.length],
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMine)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 4),
                    child: Text(
                      message.senderNickname,
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink700,
                      ),
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: isMine
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  children: [
                    if (isMine) ...[
                      Text(
                        AppDateUtils.formatChatTime(message.createdAt),
                        style: AppTextStyles.caption.copyWith(fontSize: 10),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.65,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: isMine ? AppColors.pinkGradient : null,
                          color: isMine
                              ? null
                              : Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(isMine ? 20 : 6),
                            bottomRight: Radius.circular(isMine ? 6 : 20),
                          ),
                          border: isMine
                              ? null
                              : Border.all(
                                  color: AppColors.pink100
                                      .withValues(alpha: 0.8),
                                  width: 0.5,
                                ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors.pink500.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          message.content,
                          style: AppTextStyles.body1.copyWith(
                            color: isMine ? Colors.white : AppColors.ink900,
                          ),
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
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.divider),
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
