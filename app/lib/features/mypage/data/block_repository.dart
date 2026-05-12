import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

/// 차단 목록 1개 항목.
class BlockedUser {
  final String targetUserId;
  final String nickname;
  final String? profileImageUrl;
  final String createdAt;

  BlockedUser({
    required this.targetUserId,
    required this.nickname,
    this.profileImageUrl,
    required this.createdAt,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      targetUserId: json['targetUserId'] ?? '',
      nickname: json['nickname'] ?? '',
      profileImageUrl: json['profileImageUrl'],
      createdAt: json['createdAt'] ?? '',
    );
  }
}

class BlockRepository {
  final Dio _dio = ApiClient.instance;

  /// GET /blocks — 내 차단 목록
  Future<List<BlockedUser>> getBlockedUsers() async {
    final response = await _dio.get(ApiConstants.blocks);
    final data = response.data['data'] ?? response.data;
    final items = (data['items'] as List?) ?? const [];
    return items
        .map((e) => BlockedUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// DELETE /blocks/:targetUserId — 차단 해제
  Future<void> unblock(String targetUserId) async {
    await _dio.delete(ApiConstants.blockTarget(targetUserId));
  }
}
