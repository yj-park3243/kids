import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/notification.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/design/notebook.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading.dart';
import '../../share/deeplink/fcm_tap_handler.dart';
import '../data/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  List<AppNotification>? _notifications;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final notifications =
          await ref.read(notificationRepositoryProvider).getNotifications();
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '알림을 불러올 수 없습니다';
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await ref.read(notificationRepositoryProvider).markAllAsRead();
      _loadNotifications();
    } catch (e) {
      // Ignore
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'JOIN_REQUEST':
        return Icons.person_add_rounded;
      case 'JOIN_ACCEPTED':
        return Icons.check_circle_rounded;
      case 'JOIN_REJECTED':
        return Icons.cancel_rounded;
      case 'ROOM_CANCELLED':
        return Icons.event_busy_rounded;
      case 'ROOM_REMINDER':
        return Icons.alarm_rounded;
      case 'NEW_CHAT':
        return Icons.chat_bubble_rounded;
      case 'NEW_ROOM':
        return Icons.celebration_rounded;
      case 'INQUIRY_REPLIED':
        return Icons.mark_email_read_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: CustomAppBar(
        title: '알림',
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: Text(
              '모두 읽음',
              style: AppTextStyles.body2.copyWith(color: AppColors.ink2),
            ),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const AppLoadingIndicator();

    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _loadNotifications);
    }

    if (_notifications == null || _notifications!.isEmpty) {
      return const EmptyState(
        icon: Icons.notifications_none_rounded,
        title: '알림이 없습니다',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: AppColors.ink,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        itemCount: _notifications!.length,
        separatorBuilder: (_, __) => const DashedDivider(),
        itemBuilder: (context, index) {
          final notification = _notifications![index];
          return _NotificationRow(
            notification: notification,
            icon: _getNotificationIcon(notification.type),
            onTap: () {
              // Mark as read
              ref
                  .read(notificationRepositoryProvider)
                  .markAsRead(notification.id);

              // Navigate — 푸시 탭과 같은 규칙(사진 댓글은 사진으로, 문의 답변은 문의함으로).
              final route = FcmTapHandler.resolveRoute({
                ...?notification.data,
                'type': notification.type,
              });
              if (route != null && route != '/notifications') {
                context.push(route);
              }
            },
          );
        },
      ),
    );
  }
}

/// 알림 한 줄 — 왼쪽 미읽음 점(berry) · 아이콘(ink3) · 제목/본문 · 시간.
class _NotificationRow extends StatelessWidget {
  final AppNotification notification;
  final IconData icon;
  final VoidCallback onTap;

  const _NotificationRow({
    required this.notification,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 10,
                child: unread
                    ? Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 7),
                        decoration: const BoxDecoration(
                          color: AppColors.berry,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 1, right: 12),
                child: Icon(icon, size: 19, color: AppColors.ink3),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notification.title, style: AppTextStyles.body1Bold),
                    const SizedBox(height: 2),
                    Text(
                      notification.body,
                      style: AppTextStyles.body2,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      AppDateUtils.formatRelativeTime(
                          DateTime.parse(notification.createdAt)),
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
