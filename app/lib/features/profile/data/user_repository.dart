import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../models/user.dart';

class UserRepository {
  final Dio _dio = ApiClient.instance;

  /// 상대방 프로필 조회 — GET /users/:userId
  /// 응답: 프로필 + 아이 정보 + 매너 점수/태그 + 노쇼 레벨 + 팔로우/차단 상태
  Future<User> getUserById(String userId) async {
    final response = await _dio.get(ApiConstants.userById(userId));
    final data = response.data['data'] ?? response.data;
    return User.fromJson(data as Map<String, dynamic>);
  }
}
