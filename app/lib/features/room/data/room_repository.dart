import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../models/room.dart';

class RoomRepository {
  final Dio _dio = ApiClient.instance;

  Future<Room> getRoomDetail(String roomId) async {
    final response = await _dio.get('${ApiConstants.rooms}/$roomId');
    final data = response.data['data'] ?? response.data;
    return Room.fromJson(data);
  }

  Future<Room> createRoom(Map<String, dynamic> roomData) async {
    final response = await _dio.post(ApiConstants.rooms, data: roomData);
    final data = response.data['data'] ?? response.data;
    return Room.fromJson(data);
  }

  Future<Map<String, dynamic>> joinRoom(String roomId) async {
    final response = await _dio.post('${ApiConstants.rooms}/$roomId/join');
    return response.data['data'] ?? response.data;
  }

  Future<void> leaveRoom(String roomId) async {
    await _dio.delete('${ApiConstants.rooms}/$roomId/join');
  }

  Future<List<JoinRequest>> getJoinRequests(String roomId) async {
    final response =
        await _dio.get('${ApiConstants.rooms}/$roomId/join-requests');
    final data = response.data['data'] ?? response.data;
    final items = data['items'] as List<dynamic>? ?? data as List<dynamic>;
    return items
        .map((e) => JoinRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> handleJoinRequest(
    String roomId,
    String requestId,
    String action,
  ) async {
    await _dio.patch(
      '${ApiConstants.rooms}/$roomId/join-requests/$requestId',
      data: {'action': action},
    );
  }

  Future<void> cancelRoom(String roomId) async {
    await _dio.delete('${ApiConstants.rooms}/$roomId');
  }

  // My rooms
  Future<List<Room>> getMyRooms({
    String type = 'ALL',
    String status = 'UPCOMING',
  }) async {
    final response = await _dio.get(
      ApiConstants.myRooms,
      queryParameters: {'type': type, 'status': status},
    );
    final data = response.data['data'] ?? response.data;
    final items = data['items'] as List<dynamic>? ?? data as List<dynamic>;
    return items.map((e) => Room.fromJson(e as Map<String, dynamic>)).toList();
  }

  // Map
  Future<Map<String, dynamic>> getMapRooms({
    required double swLat,
    required double swLng,
    required double neLat,
    required double neLng,
    int? ageMonth,
    int? zoomLevel,
  }) async {
    final response = await _dio.get(ApiConstants.roomsMap, queryParameters: {
      'swLat': swLat,
      'swLng': swLng,
      'neLat': neLat,
      'neLng': neLng,
      if (ageMonth != null) 'ageMonth': ageMonth,
      if (zoomLevel != null) 'zoomLevel': zoomLevel,
    });
    return response.data['data'] ?? response.data;
  }
}
