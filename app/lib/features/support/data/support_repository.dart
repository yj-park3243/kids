import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

class SupportRepository {
  final Dio _dio = ApiClient.instance;

  /// 앱 에러 리포팅 (인증 선택적 — 서버가 헤더 있으면 userId 추출)
  /// 실패해도 throw 하지 않음. 글로벌 에러 핸들러에서 무한 루프 방지.
  Future<void> reportError({
    required String errorMessage,
    String? stackTrace,
    String? screenName,
    Map<String, dynamic>? deviceInfo,
  }) async {
    try {
      await _dio.post(
        ApiConstants.errorLogs,
        data: {
          'errorMessage': errorMessage,
          if (stackTrace != null) 'stackTrace': stackTrace,
          if (screenName != null) 'screenName': screenName,
          if (deviceInfo != null) 'deviceInfo': deviceInfo,
        },
        // 에러 리포트 호출 자체의 에러는 무시 (timeout 짧게)
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
    } catch (_) {
      // 에러 리포팅 실패는 의도적으로 무시
    }
  }

  Future<String> createInquiry({
    required String subject,
    required String message,
  }) async {
    final res = await _dio.post(
      ApiConstants.supportInquiry,
      data: {'subject': subject, 'message': message},
    );
    final data = res.data['data'] ?? res.data;
    return data['id'] as String;
  }

  Future<String> createReport({
    String? targetUserId,
    String? targetRoomId,
    required String reason, // SPAM | ABUSE | INAPPROPRIATE | FRAUD | OTHER
    String? detail,
  }) async {
    final res = await _dio.post(
      ApiConstants.supportReport,
      data: {
        if (targetUserId != null) 'targetUserId': targetUserId,
        if (targetRoomId != null) 'targetRoomId': targetRoomId,
        'reason': reason,
        if (detail != null) 'detail': detail,
      },
    );
    final data = res.data['data'] ?? res.data;
    return data['id'] as String;
  }
}

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository();
});
