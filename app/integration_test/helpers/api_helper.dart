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
        )) {
    // hang/실패 디버그용 — 모든 요청·응답 print.
    _dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: false,
      requestBody: false,
      responseHeader: false,
      responseBody: false,
      error: true,
      logPrint: (o) => print('[E2E_DIO] $o'),
    ));
  }

  final Dio _dio;

  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  // ─── auth ──────────────────────────────────────────────────────────

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
    String? parentGender, // MOM | DAD
    bool? isSingleParent,
    String regionSido = '서울특별시',
    String regionSigungu = '강남구',
    String regionDong = '역삼동',
  }) async {
    final res = await _dio.post('/users/profile', data: {
      'nickname': nickname,
      if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
      if (parentGender != null) 'parentGender': parentGender,
      if (isSingleParent != null) 'isSingleParent': isSingleParent,
      'regionSido': regionSido,
      'regionSigungu': regionSigungu,
      'regionDong': regionDong,
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

  /// 풀 옵션 방 생성. 모든 필수 필드를 채워서 보낸다.
  Future<String> createRoom({
    required String title,
    required String description,
    String placeType = 'PLAYGROUND',
    String joinType = 'FREE',
    String genderFilter = 'ALL',
    bool singleParentOnly = false,
    int ageMonthMin = 0,
    int ageMonthMax = 84,
    int maxMembers = 5,
    String? date,
    String startTime = '14:00',
    String regionSido = '서울특별시',
    String regionSigungu = '강남구',
    String regionDong = '역삼동',
  }) async {
    final d = date ?? _tomorrow();
    final res = await _dio.post('/rooms', data: {
      'title': title,
      'description': description,
      'placeType': placeType,
      'joinType': joinType,
      'genderFilter': genderFilter,
      'singleParentOnly': singleParentOnly,
      'ageMonthMin': ageMonthMin,
      'ageMonthMax': ageMonthMax,
      'maxMembers': maxMembers,
      'date': d,
      'startTime': startTime,
      'regionSido': regionSido,
      'regionSigungu': regionSigungu,
      'regionDong': regionDong,
    });
    _assertOk(res, 'createRoom');
    final data = _unwrap(res.data);
    return data['id'] as String;
  }

  /// 방 참여. status code 그대로 반환해서 거부 케이스 검증 가능.
  Future<int> tryJoinRoom(String roomId) async {
    final res = await _dio.post('/rooms/$roomId/join');
    return res.statusCode ?? 0;
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

  /// action: ACCEPT | REJECT — 서버 JoinActionDto 와 일치해야 함
  /// (whitelist+forbidNonWhitelisted 라 잘못된 키는 400).
  Future<void> respondJoinRequest({
    required String roomId,
    required String requestId,
    required String action,
  }) async {
    final res = await _dio.patch(
      '/rooms/$roomId/join-requests/$requestId',
      data: {'action': action},
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

  // ─── review ────────────────────────────────────────────────────────

  /// score: 1~5, tags: 최대 10. 생성된 reviewId 를 반환(없으면 빈 문자열).
  Future<String> createReview({
    required String roomId,
    required String targetUserId,
    int score = 5,
    List<String> tags = const ['친절했어요'],
    String? comment,
  }) async {
    final res = await _dio.post('/rooms/$roomId/reviews', data: {
      'targetUserId': targetUserId,
      'score': score,
      'tags': tags,
      if (comment != null) 'comment': comment,
    });
    _assertOk(res, 'createReview');
    final data = _unwrap(res.data);
    return (data is Map && data['id'] != null) ? data['id'] as String : '';
  }

  /// 후기 수정 (완료 7일 이내). PATCH /reviews/:id
  Future<void> updateReview(
    String reviewId, {
    int? score,
    List<String>? tags,
    String? comment,
  }) async {
    final res = await _dio.patch('/reviews/$reviewId', data: {
      if (score != null) 'score': score,
      if (tags != null) 'tags': tags,
      if (comment != null) 'comment': comment,
    });
    _assertOk(res, 'updateReview');
  }

  // ─── report ────────────────────────────────────────────────────────

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

  /// 정식 신고 엔드포인트. POST /reports (CreateReportDto)
  /// targetType: USER | ROOM | CHAT_MESSAGE
  /// reason: SPAM | INAPPROPRIATE | HARASSMENT | FAKE_PROFILE | NO_SHOW | OTHER
  Future<void> reportTarget({
    required String targetType,
    required String targetId,
    String reason = 'HARASSMENT',
    String? description,
  }) async {
    final res = await _dio.post('/reports', data: {
      'targetType': targetType,
      'targetId': targetId,
      'reason': reason,
      if (description != null) 'description': description,
    });
    _assertOk(res, 'reportTarget');
  }

  // ─── block ─────────────────────────────────────────────────────────

  Future<void> blockUser(String targetUserId) async {
    final res = await _dio.post('/blocks', data: {'targetUserId': targetUserId});
    _assertOk(res, 'blockUser');
  }

  Future<void> unblockUser(String targetUserId) async {
    final res = await _dio.delete('/blocks/$targetUserId');
    _assertOk(res, 'unblockUser');
  }

  Future<List<dynamic>> listBlocks() async {
    final res = await _dio.get('/blocks');
    _assertOk(res, 'listBlocks');
    final data = _unwrap(res.data);
    return (data is List) ? data : (data['items'] as List? ?? []);
  }

  // ─── follow ────────────────────────────────────────────────────────

  Future<void> followUser(String targetUserId) async {
    final res = await _dio.post('/follows', data: {'targetUserId': targetUserId});
    _assertOk(res, 'followUser');
  }

  Future<void> unfollowUser(String targetUserId) async {
    final res = await _dio.delete('/follows/$targetUserId');
    _assertOk(res, 'unfollowUser');
  }

  Future<List<dynamic>> listFollowing() async {
    final res = await _dio.get('/follows/me');
    _assertOk(res, 'listFollowing');
    final data = _unwrap(res.data);
    return (data is List) ? data : (data['items'] as List? ?? []);
  }

  // ─── user (me / others) ────────────────────────────────────────────

  Future<Map<String, dynamic>> getMe() async {
    final res = await _dio.get('/users/me');
    _assertOk(res, 'getMe');
    return Map<String, dynamic>.from(_unwrap(res.data) as Map);
  }

  /// PATCH /users/me — 수정 불가 필드(parentGender/isSingleParent) 검증용.
  /// 서버는 받기만 하고 무시하므로 2xx 가 와도 값은 불변이어야 한다.
  Future<void> updateMe(Map<String, dynamic> data) async {
    final res = await _dio.patch('/users/me', data: data);
    _assertOk(res, 'updateMe');
  }

  Future<Map<String, dynamic>> getUserById(String userId) async {
    final res = await _dio.get('/users/$userId');
    _assertOk(res, 'getUserById');
    return Map<String, dynamic>.from(_unwrap(res.data) as Map);
  }

  // ─── room (read / manage) ──────────────────────────────────────────

  Future<Map<String, dynamic>> getRoomDetail(String roomId) async {
    final res = await _dio.get('/rooms/$roomId');
    _assertOk(res, 'getRoomDetail');
    return Map<String, dynamic>.from(_unwrap(res.data) as Map);
  }

  Future<List<dynamic>> listRooms() async {
    final res = await _dio.get('/rooms');
    _assertOk(res, 'listRooms');
    final data = _unwrap(res.data);
    return (data is List) ? data : (data['items'] as List? ?? []);
  }

  Future<List<dynamic>> listMyRooms({
    String type = 'ALL',
    String status = 'UPCOMING',
  }) async {
    final res = await _dio.get('/rooms/my',
        queryParameters: {'type': type, 'status': status});
    _assertOk(res, 'listMyRooms');
    final data = _unwrap(res.data);
    return (data is List) ? data : (data['items'] as List? ?? []);
  }

  /// 출석 체크 제출. status 반환 (방장 2xx / 비방장 403 검증).
  Future<int> submitAttendance(
    String roomId,
    List<Map<String, dynamic>> records,
  ) async {
    final res = await _dio.post('/rooms/$roomId/attendance',
        data: {'records': records});
    return res.statusCode ?? 0;
  }

  /// 참여자 강퇴. status 반환.
  Future<int> kickMember(String roomId, String targetUserId) async {
    final res = await _dio.delete('/rooms/$roomId/members/$targetUserId');
    return res.statusCode ?? 0;
  }

  /// 방 수정 시도. status 반환 (비방장 403 검증용).
  Future<int> tryUpdateRoom(String roomId, Map<String, dynamic> data) async {
    final res = await _dio.patch('/rooms/$roomId', data: data);
    return res.statusCode ?? 0;
  }

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

  static String _tomorrow() {
    final t = DateTime.now().add(const Duration(days: 1));
    return '${t.year.toString().padLeft(4, '0')}-'
        '${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')}';
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
