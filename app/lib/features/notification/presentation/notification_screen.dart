import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/notification.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/design/pink_blobs.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading.dart';
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
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getNotificationIconColor(String type) {
    switch (type) {
      case 'JOIN_ACCEPTED':
        return AppColors.success;
      case 'JOIN_REJECTED':
      case 'ROOM_CANCELLED':
        return AppColors.error;
      case 'ROOM_REMINDER':
        return AppColors.warning;
      case 'NEW_CHAT':
        return AppColors.secondary;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(
        title: '알림',
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: Text(
              '모두 읽음',
              style: AppTextStyles.caption.copyWith(color: AppColors.pink500),
            ),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: PinkBlobsBackground(child: _buildBody()),
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
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _notifications!.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: AppColors.divider, indent: 72),
        itemBuilder: (context, index) {
          final notification = _notifications![index];
          return _NotificationTile(
            notification: notification,
            icon: _getNotificationIcon(notification.type),
            iconColor: _getNotificationIconColor(notification.type),
            onTap: () {
              // Mark as read
              ref
                  .read(notificationRepositoryProvider)
                  .markAsRead(notification.id);

              // Navigate
              if (notification.roomId != null) {
                context.push('/rooms/${notification.roomId}');
              }
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: notification.isRead
            ? Colors.transparent
            : AppColors.primary.withValues(alpha: 0.03),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: AppTextStyles.body2Bold.copyWith(
                      fontWeight: notification.isRead
                          ? FontWeight.w400
                          : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.body,
                    style: AppTextStyles.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppDateUtils.formatRelativeTime(
                        DateTime.parse(notification.createdAt)),
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
