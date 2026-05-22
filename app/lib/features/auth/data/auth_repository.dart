import 'dart:async';

import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/push/push_token_service.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../models/user.dart';

class AuthRepository {
  final Dio _dio = ApiClient.instance;

  // Social Login
  Future<AuthResult> socialLogin({
    required String provider,
    required String accessToken,
    String? idToken,
  }) async {
    final response = await _dio.post(ApiConstants.socialLogin, data: {
      'provider': provider,
      'accessToken': accessToken,
      'idToken': idToken,
    });
    return _handleAuthResponse(response.data);
  }

  // Email Login
  Future<AuthResult> emailLogin({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(ApiConstants.emailLogin, data: {
      'email': email,
      'password': password,
    });
    return _handleAuthResponse(response.data);
  }

  // Email Register
  Future<AuthResult> emailRegister({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(ApiConstants.emailRegister, data: {
      'email': email,
      'password': password,
    });
    return _handleAuthResponse(response.data);
  }

  // Setup Profile
  Future<User> setupProfile({
    required String nickname,
    String? profileImageUrl,
    String? introduction,
    String? parentGender,
    bool? isSingleParent,
  }) async {
    final response = await _dio.post(ApiConstants.userProfile, data: {
      'nickname': nickname,
      'profileImageUrl': profileImageUrl,
      'introduction': introduction,
      if (parentGender != null) 'parentGender': parentGender,
      if (isSingleParent != null) 'isSingleParent': isSingleParent,
    });
    final data = response.data['data'] ?? response.data;
    return User.fromJson(data);
  }

  // Add Child
  Future<Child> addChild({
    required String nickname,
    required int birthYear,
    required int birthMonth,
    String? gender,
    String? photoUrl,
  }) async {
    final response = await _dio.post(ApiConstants.children, data: {
      'nickname': nickname,
      'birthYear': birthYear,
      'birthMonth': birthMonth,
      'gender': gender,
      if (photoUrl != null) 'photoUrl': photoUrl,
    });
    final data = response.data['data'] ?? response.data;
    return Child.fromJson(data);
  }

  // Update Child
  Future<Child> updateChild({
    required String childId,
    String? nickname,
    int? birthYear,
    int? birthMonth,
    String? gender,
    String? photoUrl,
  }) async {
    final response = await _dio.patch('${ApiConstants.children}/$childId', data: {
      if (nickname != null) 'nickname': nickname,
      if (birthYear != null) 'birthYear': birthYear,
      if (birthMonth != null) 'birthMonth': birthMonth,
      if (gender != null) 'gender': gender,
      if (photoUrl != null) 'photoUrl': photoUrl,
    });
    final data = response.data['data'] ?? response.data;
    return Child.fromJson(data);
  }

  // Check Nickname
  Future<bool> checkNickname(String nickname) async {
    final response = await _dio.get(
      ApiConstants.checkNickname,
      queryParameters: {'nickname': nickname},
    );
    final data = response.data['data'] ?? response.data;
    return data['available'] == true;
  }

  // Get My Profile
  Future<User> getMyProfile() async {
    final response = await _dio.get(ApiConstants.userMe);
    final data = response.data['data'] ?? response.data;
    return User.fromJson(data);
  }

  // Logout
  Future<void> logout() async {
    try {
      await _dio.post(ApiConstants.logout);
    } catch (_) {}
    await SecureStorage.clearTokens();
  }

  // Delete Account
  Future<void> deleteAccount(String? reason) async {
    await _dio.delete(ApiConstants.userMe, data: {
      'reason': reason,
    });
    await SecureStorage.clearTokens();
  }

  // Upload Image
  Future<String> uploadImage(String filePath) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(filePath),
    });
    final response = await _dio.post(
      ApiConstants.uploadImage,
      data: formData,
    );
    final data = response.data['data'] ?? response.data;
    return data['url'];
  }

  /// 정지(SUSPENDED) 해제 요청용 증거 사진 제출.
  Future<void> submitAppeal(String photoUrl) async {
    await _dio.post(
      '${ApiConstants.userMe}/appeal',
      data: {'photoUrl': photoUrl},
    );
  }

  // Helper
  Future<AuthResult> _handleAuthResponse(dynamic responseData) async {
    final data = responseData['data'] ?? responseData;
    final accessToken = data['accessToken'] as String?;
    final refreshToken = data['refreshToken'] as String?;
    if (accessToken == null || refreshToken == null) {
      throw Exception('서버 응답에 토큰이 없습니다.');
    }
    final isNewUser = data['isNewUser'] as bool? ?? false;
    final user = User.fromJson(data['user']);

    await SecureStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    // 로그인 직후 FCM 토큰 등록 — 앱 시작 시점엔 미로그인이라 보류됐을 수 있음.
    unawaited(PushTokenService.instance.registerCurrentToken());

    return AuthResult(
      user: user,
      isNewUser: isNewUser,
    );
  }
}

class AuthResult {
  final User user;
  final bool isNewUser;

  AuthResult({required this.user, required this.isNewUser});
}
