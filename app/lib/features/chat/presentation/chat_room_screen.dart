import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/chat_message.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/design/avatar.dart';
import '../../../widgets/design/accent_blobs.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/chat_repository.dart';
import '../providers/chat_provider.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String chatRoomId;

  const ChatRoomScreen({super.key, required this.chatRoomId});

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen>
    with WidgetsBindingObserver {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  final List<ChatMessage> _messages = [];
  // messageId -> userIds who've read it. 같은 유저 중복 차감을 방지.
  final Map<String, Set<String>> _readers = {};
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
        _readers.clear();
        _loadingHistory = false;
      });
      _markReadIfAny();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingHistory = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _markReadIfAny();
    }
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

  /// 가장 최근 메시지 시점까지 읽음 처리. 화면을 보고 있는 동안 새 메시지가
  /// 들어오면 즉시 카운트가 -1 되도록.
  void _markReadIfAny() {
    if (_messages.isEmpty) return;
    final latest = _messages.first.createdAt;
    ref.read(chatRepositoryProvider).markRoomRead(
          widget.chatRoomId,
          asOf: latest,
        );
  }

  void _handleEvent(ChatRoomEvent event) {
    switch (event) {
      case ChatMessageEvent(:final message):
        if (_messages.any((m) => m.id == message.id)) return;
        setState(() => _messages.insert(0, message));
        _markReadIfAny();
      case ChatReadEvent(:final userId, :final lastReadAt):
        _applyReadReceipt(userId, lastReadAt);
    }
  }

  void _applyReadReceipt(String userId, DateTime lastReadAt) {
    bool changed = false;
    for (var i = 0; i < _messages.length; i++) {
      final msg = _messages[i];
      if (msg.createdAt.isAfter(lastReadAt)) continue;
      if (msg.senderId == userId) continue;
      final readers = _readers.putIfAbsent(msg.id, () => <String>{});
      if (readers.add(userId)) {
        final next = (msg.unreadCount - 1).clamp(0, msg.unreadCount);
        if (next != msg.unreadCount) {
          _messages[i] = msg.copyWith(unreadCount: next);
          changed = true;
        }
      }
    }
    if (changed && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authProvider).user?.id ?? '';

    ref.listen<AsyncValue<ChatRoomEvent>>(
      chatRoomEventStreamProvider(widget.chatRoomId),
      (_, next) {
        final event = next.value;
        if (event != null) _handleEvent(event);
      },
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: '채팅'),
      extendBodyBehindAppBar: true,
      body: AccentBlobsBackground(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: _loadingHistory
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary),
                      )
                    : _messages.isEmpty
                        ? Center(
                            child: Text(
                              '첫 번째 메시지를 보내보세요!',
                              style: AppTextStyles.body2
                                  .copyWith(color: AppColors.ink300),
                            ),
                          )
                        : _buildMessageList(userId),
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

  Widget _buildMessageList(String userId) {
    // _messages는 최신이 [0]. 카카오톡 스타일을 위해선 같은 발신자/같은 분
    // 묶음의 "마지막" 발화에만 시간/카운트가 붙고, "첫" 발화 위에 아바타+이름이
    // 붙어야 한다. reverse:true 상태에서 인덱스 i와 양쪽 이웃을 비교한다.
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        if (message.isSystem) {
          return _SystemMessage(message: message);
        }
        // reverse:true이므로 [index+1]이 시각적으로 위쪽(=더 오래된) 메시지.
        final older = index + 1 < _messages.length ? _messages[index + 1] : null;
        final newer = index - 1 >= 0 ? _messages[index - 1] : null;

        final isMine = message.senderId == userId;
        final showDateHeader = older == null ||
            !_sameDay(older.createdAt.toLocal(), message.createdAt.toLocal()) ||
            older.isSystem;
        final showSenderHeader = !isMine &&
            (showDateHeader ||
                older.senderId != message.senderId ||
                older.isSystem);
        final showTimeFooter = newer == null ||
            newer.isSystem ||
            newer.senderId != message.senderId ||
            !_sameMinute(
                newer.createdAt.toLocal(), message.createdAt.toLocal()) ||
            !_sameDay(
                newer.createdAt.toLocal(), message.createdAt.toLocal());

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDateHeader) _DateHeader(date: message.createdAt),
            _ChatBubble(
              message: message,
              isMine: isMine,
              showSenderHeader: showSenderHeader,
              showTimeFooter: showTimeFooter,
            ),
          ],
        );
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _sameMinute(DateTime a, DateTime b) =>
      _sameDay(a, b) && a.hour == b.hour && a.minute == b.minute;
}

class _DateHeader extends StatelessWidget {
  final DateTime date;
  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            AppDateUtils.formatChatDateHeader(date),
            style: AppTextStyles.caption.copyWith(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
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
                      key: const Key('input-chat-message'),
                      controller: controller,
                      style: AppTextStyles.body1,
                      cursorColor: AppColors.primary,
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
                  key: const Key('btn-chat-send'),
                  onTap: onSend,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
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
  final bool showSenderHeader;
  final bool showTimeFooter;

  const _ChatBubble({
    required this.message,
    required this.isMine,
    required this.showSenderHeader,
    required this.showTimeFooter,
  });

  @override
  Widget build(BuildContext context) {
    final timeLabel =
        DateFormat('a h:mm', 'ko').format(message.createdAt.toLocal());
    final meta = _BubbleMeta(
      unreadCount: message.unreadCount,
      timeLabel: showTimeFooter ? timeLabel : null,
      alignRight: isMine,
    );

    return Padding(
      padding: EdgeInsets.only(top: showSenderHeader ? 10 : 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMine) ...[
            SizedBox(
              width: 30,
              child: showSenderHeader
                  ? InitialAvatar(
                      label: message.senderNickname,
                      size: 30,
                      tone: AvatarTone.values[
                          message.senderId.hashCode.abs() %
                              AvatarTone.values.length],
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showSenderHeader)
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
                    if (isMine) ...[meta, const SizedBox(width: 6)],
                    Flexible(
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width * 0.65,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: isMine ? AppColors.primaryGradient : null,
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
                                  color: AppColors.primary100
                                      .withValues(alpha: 0.8),
                                  width: 0.5,
                                ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors.primary.withValues(alpha: 0.08),
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
                    if (!isMine) ...[const SizedBox(width: 6), meta],
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

/// 카카오톡 식: 안 읽은 사람 수는 위, 전송 시각은 아래.
class _BubbleMeta extends StatelessWidget {
  final int unreadCount;
  final String? timeLabel;
  final bool alignRight;

  const _BubbleMeta({
    required this.unreadCount,
    required this.timeLabel,
    required this.alignRight,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      if (unreadCount > 0)
        Text(
          '$unreadCount',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
        ),
      if (timeLabel != null)
        Padding(
          padding: EdgeInsets.only(top: unreadCount > 0 ? 2 : 0),
          child: Text(
            timeLabel!,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              color: AppColors.ink300,
              height: 1.0,
            ),
          ),
        ),
    ];

    if (children.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment:
            alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
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
