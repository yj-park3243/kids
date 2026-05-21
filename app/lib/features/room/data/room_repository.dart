import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/response_utils.dart';
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
    return extractItems(data)
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
    return extractItems(data)
        .map((e) => Room.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Map
  Future<Map<String, dynamic>> getMapRooms({
    required double swLat,
    required double swLng,
    required double neLat,
    required double neLng,
    int? zoomLevel,
    Map<String, dynamic>? filters,
  }) async {
    final response = await _dio.get(ApiConstants.roomsMap, queryParameters: {
      'swLat': swLat,
      'swLng': swLng,
      'neLat': neLat,
      'neLng': neLng,
      if (zoomLevel != null) 'zoomLevel': zoomLevel,
      ...?filters,
    });
    return response.data['data'] ?? response.data;
  }

  /// 주소 → 좌표. 방 생성 시 핀이 찍히도록 좌표를 확보한다.
  Future<({double? lat, double? lng})> geocode(String address) async {
    final response = await _dio.get(
      ApiConstants.roomsGeocode,
      queryParameters: {'address': address},
    );
    final data = response.data['data'] ?? response.data;
    return (
      lat: (data['latitude'] as num?)?.toDouble(),
      lng: (data['longitude'] as num?)?.toDouble(),
    );
  }
}
