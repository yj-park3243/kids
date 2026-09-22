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

  /// 내 문의 내역 — 답변(reply)·상태(OPEN|REPLIED|CLOSED) 포함, 최신순.
  Future<List<Inquiry>> listMyInquiries() async {
    final res = await _dio.get(ApiConstants.supportInquiries);
    final data = res.data['data'] ?? res.data;
    return (data as List)
        .map((e) => Inquiry.fromJson(e as Map<String, dynamic>))
        .toList();
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

class Inquiry {
  final String id;
  final String subject;
  final String message;
  final String? reply;
  final String status;
  final DateTime createdAt;
  final DateTime? repliedAt;

  const Inquiry({
    required this.id,
    required this.subject,
    required this.message,
    required this.reply,
    required this.status,
    required this.createdAt,
    required this.repliedAt,
  });

  factory Inquiry.fromJson(Map<String, dynamic> json) => Inquiry(
        id: json['id'] as String,
        subject: json['subject'] as String? ?? '',
        message: json['message'] as String? ?? '',
        reply: json['reply'] as String?,
        status: json['status'] as String? ?? 'OPEN',
        createdAt: DateTime.tryParse('${json['createdAt']}') ?? DateTime.now(),
        repliedAt: json['repliedAt'] != null
            ? DateTime.tryParse('${json['repliedAt']}')
            : null,
      );
}
