import 'package:dio/dio.dart';

import 'test_config.dart';

/// e2e 테스트에서 서버 API를 직접 호출하기 위한 thin 래퍼.
///
/// UI tap이 fragile한 흐름(회원가입 직후 본인인증, 방 참여 승인 등)은
/// 이 helper로 우회하고, 핵심 UX만 실제 UI로 검증.
class ApiHelper {
  ApiHelper({String? baseUrl, String? token})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl ?? TestConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'Content-Type': 'application/json',
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
          validateStatus: (_) => true,
        ));

  final Dio _dio;

  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  // ─── auth ──────────────────────────────────────────────────────────

  /// 이메일 회원가입. 응답에서 accessToken/refreshToken/user.id 추출.
  Future<RegisterResult> registerEmail({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post('/auth/email/register', data: {
      'email': email,
      'password': password,
    });
    _assertOk(res, 'registerEmail');
    final data = _unwrap(res.data);
    return RegisterResult(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      userId: (data['user'] as Map)['id'] as String,
    );
  }

  Future<RegisterResult> loginEmail({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post('/auth/email/login', data: {
      'email': email,
      'password': password,
    });
    _assertOk(res, 'loginEmail');
    final data = _unwrap(res.data);
    return RegisterResult(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      userId: (data['user'] as Map)['id'] as String,
    );
  }

  // ─── profile / child ───────────────────────────────────────────────

  Future<void> setupProfile({
    required String nickname,
    String? profileImageUrl,
  }) async {
    final res = await _dio.post('/users/profile', data: {
      'nickname': nickname,
      if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
    });
    _assertOk(res, 'setupProfile');
  }

  Future<String> addChild({
    required String nickname,
    required int birthYear,
    required int birthMonth,
    String gender = 'MALE',
  }) async {
    final res = await _dio.post('/children', data: {
      'nickname': nickname,
      'birthYear': birthYear,
      'birthMonth': birthMonth,
      'gender': gender,
    });
    _assertOk(res, 'addChild');
    final data = _unwrap(res.data);
    return data['id'] as String;
  }

  // ─── room ──────────────────────────────────────────────────────────

  /// 방 생성. 핵심 필드만 채움 — 나머지는 서버 default.
  Future<String> createRoom({
    required String title,
    required String description,
    String placeType = 'PLAYGROUND',
    String joinType = 'FREE',
  }) async {
    final res = await _dio.post('/rooms', data: {
      'title': title,
      'description': description,
      'placeType': placeType,
      'joinType': joinType,
    });
    _assertOk(res, 'createRoom');
    final data = _unwrap(res.data);
    return data['id'] as String;
  }

  Future<void> joinRoom(String roomId) async {
    final res = await _dio.post('/rooms/$roomId/join');
    _assertOk(res, 'joinRoom');
  }

  Future<List<dynamic>> listJoinRequests(String roomId) async {
    final res = await _dio.get('/rooms/$roomId/join-requests');
    _assertOk(res, 'listJoinRequests');
    final data = _unwrap(res.data);
    return (data is List) ? data : (data['items'] as List? ?? []);
  }

  /// status: APPROVED | REJECTED
  Future<void> respondJoinRequest({
    required String roomId,
    required String requestId,
    required String status,
  }) async {
    final res = await _dio.patch(
      '/rooms/$roomId/join-requests/$requestId',
      data: {'status': status},
    );
    _assertOk(res, 'respondJoinRequest');
  }

  // ─── chat ──────────────────────────────────────────────────────────

  Future<void> sendChatMessage(String roomId, String content) async {
    final res = await _dio.post('/chat/rooms/$roomId/messages', data: {
      'content': content,
    });
    _assertOk(res, 'sendChatMessage');
  }

  Future<List<dynamic>> listChatMessages(String roomId) async {
    final res = await _dio.get('/chat/rooms/$roomId/messages');
    _assertOk(res, 'listChatMessages');
    final data = _unwrap(res.data);
    return (data is List) ? data : (data['items'] as List? ?? []);
  }

  // ─── report / block ────────────────────────────────────────────────

  /// reason: SPAM | ABUSE | INAPPROPRIATE | FRAUD | OTHER
  Future<void> reportUser({
    required String targetUserId,
    String reason = 'ABUSE',
    String? detail,
  }) async {
    final res = await _dio.post('/support/report', data: {
      'targetUserId': targetUserId,
      'reason': reason,
      if (detail != null) 'detail': detail,
    });
    _assertOk(res, 'reportUser');
  }

  // TODO: user-to-user block — 서버에 endpoint 구현 후 활성화.
  // Future<void> blockUser(String targetUserId) async { ... }

  // ─── internal ──────────────────────────────────────────────────────

  void _assertOk(Response res, String op) {
    final ok = res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 300;
    if (!ok) {
      throw Exception('[$op] HTTP ${res.statusCode}: ${res.data}');
    }
  }

  /// kids 서버는 envelope `{success, data}` 와 raw 둘 다 쓰는 경우가 있어 둘 다 허용.
  dynamic _unwrap(dynamic body) {
    if (body is Map && body.containsKey('data')) return body['data'];
    return body;
  }
}

class RegisterResult {
  RegisterResult({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
  });

  final String accessToken;
  final String refreshToken;
  final String userId;
}
