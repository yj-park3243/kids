import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../models/follow.dart';

class FollowRepository {
  final Dio _dio = ApiClient.instance;

  /// 팔로우 — POST /follows
  Future<void> follow(String targetUserId) async {
    await _dio.post(
      ApiConstants.follows,
      data: {'targetUserId': targetUserId},
    );
  }

  /// 언팔로우 — DELETE /follows/:targetUserId
  Future<void> unfollow(String targetUserId) async {
    await _dio.delete(ApiConstants.followByTarget(targetUserId));
  }

  /// 내 팔로잉 목록 — GET /follows/me
  Future<List<Follow>> getMyFollowing() async {
    final response = await _dio.get(ApiConstants.myFollows);
    final data = response.data['data'] ?? response.data;
    final items = data['items'] as List<dynamic>? ?? data as List<dynamic>;
    return items
        .map((e) => Follow.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
