import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../models/room_photo.dart';

class PhotoRepository {
  PhotoRepository(this._dio);

  final Dio _dio;

  Future<List<RoomPhoto>> list(
    String roomId, {
    String? childId,
    int page = 1,
    int limit = 30,
  }) async {
    final res = await _dio.get(
      '/rooms/$roomId/photos',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (childId != null) 'childId': childId,
      },
    );
    final data = _unwrap(res.data);
    final items = (data['items'] as List? ?? const []).cast<Map<String, dynamic>>();
    return items.map(RoomPhoto.fromJson).toList();
  }

  Future<RoomPhoto> upload(
    String roomId,
    Uint8List bytes, {
    String filename = 'photo.jpg',
  }) async {
    final form = FormData.fromMap({
      'image': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _dio.post('/rooms/$roomId/photos', data: form);
    return RoomPhoto.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<RoomPhoto> getOne(String photoId) async {
    final res = await _dio.get('/photos/$photoId');
    return RoomPhoto.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<void> delete(String photoId) async {
    await _dio.delete('/photos/$photoId');
  }

  Future<List<String>> updateTags(String photoId, List<String> childIds) async {
    final res = await _dio.patch(
      '/photos/$photoId/tags',
      data: {'childIds': childIds},
    );
    final data = _unwrap(res.data);
    return (data['childIds'] as List? ?? const []).cast<String>();
  }

  Future<List<PhotoComment>> listComments(String photoId) async {
    final res = await _dio.get('/photos/$photoId/comments');
    final data = _unwrap(res.data);
    final items = (data['items'] as List? ?? const []).cast<Map<String, dynamic>>();
    return items.map(PhotoComment.fromJson).toList();
  }

  Future<PhotoComment> addComment(String photoId, String content) async {
    final res = await _dio.post(
      '/photos/$photoId/comments',
      data: {'content': content},
    );
    return PhotoComment.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  dynamic _unwrap(dynamic body) {
    if (body is Map && body.containsKey('data')) return body['data'];
    return body;
  }
}

final photoRepositoryProvider = Provider<PhotoRepository>((ref) {
  return PhotoRepository(ApiClient.instance);
});
