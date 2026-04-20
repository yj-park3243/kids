import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../models/notification.dart';

class NotificationRepository {
  final Dio _dio = ApiClient.instance;

  Future<List<AppNotification>> getNotifications({String? cursor}) async {
    final queryParams = <String, dynamic>{};
    if (cursor != null) queryParams['cursor'] = cursor;

    final response = await _dio.get(
      ApiConstants.notifications,
      queryParameters: queryParams,
    );
    final data = response.data['data'] ?? response.data;
    final items = data['items'] as List<dynamic>? ?? data as List<dynamic>;
    return items
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markAsRead(String notificationId) async {
    await _dio.patch('${ApiConstants.notifications}/$notificationId/read');
  }

  Future<void> markAllAsRead() async {
    await _dio.patch('${ApiConstants.notifications}/read-all');
  }

  Future<int> getUnreadCount() async {
    final response = await _dio.get(ApiConstants.unreadCount);
    final data = response.data['data'] ?? response.data;
    return data['count'] ?? 0;
  }
}
