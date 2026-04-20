import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../models/room.dart';

class HomeRepository {
  final Dio _dio = ApiClient.instance;

  Future<RoomListResult> getRooms({
    String? regionDong,
    String? dateFrom,
    String? dateTo,
    int? ageMonth,
    String? placeType,
    String? cursor,
    int limit = ApiConstants.pageSize,
  }) async {
    final queryParams = <String, dynamic>{
      'limit': limit,
    };
    if (regionDong != null) queryParams['regionDong'] = regionDong;
    if (dateFrom != null) queryParams['dateFrom'] = dateFrom;
    if (dateTo != null) queryParams['dateTo'] = dateTo;
    if (ageMonth != null) queryParams['ageMonth'] = ageMonth;
    if (placeType != null) queryParams['placeType'] = placeType;
    if (cursor != null) queryParams['cursor'] = cursor;

    final response = await _dio.get(
      ApiConstants.rooms,
      queryParameters: queryParams,
    );
    final data = response.data['data'] ?? response.data;
    return RoomListResult.fromJson(data);
  }

  Future<Room> getRoomDetail(String roomId) async {
    final response = await _dio.get('${ApiConstants.rooms}/$roomId');
    final data = response.data['data'] ?? response.data;
    return Room.fromJson(data);
  }

  Future<int> getUnreadNotificationCount() async {
    try {
      final response = await _dio.get(ApiConstants.unreadCount);
      final data = response.data['data'] ?? response.data;
      return data['count'] ?? 0;
    } catch (e) {
      return 0;
    }
  }
}

class RoomListResult {
  final List<Room> items;
  final String? nextCursor;
  final bool hasMore;

  RoomListResult({
    required this.items,
    this.nextCursor,
    required this.hasMore,
  });

  factory RoomListResult.fromJson(Map<String, dynamic> json) {
    return RoomListResult(
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => Room.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      nextCursor: json['nextCursor'],
      hasMore: json['hasMore'] ?? false,
    );
  }
}
