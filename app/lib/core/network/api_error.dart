import 'package:dio/dio.dart';

/// 서버가 내려준 실패 사유를 사용자에게 보여줄 문구로 바꾼다.
///
/// 서버(http-exception.filter)는 항상 `{success:false, error:{code, message}}`
/// 로 응답하므로 `error.message` 를 우선 쓴다. 아래 경우엔 [fallback] 을 쓴다.
/// - 5xx: message 가 내부 예외 원문이라 사용자에게 노출하면 안 된다.
/// - JSON 이 아닌 응답(프록시/LB 가 내려주는 HTML 등).
/// - DioException 이 아닌 예외(응답 파싱 실패 등).
String apiErrorMessage(Object error, {required String fallback}) {
  if (error is! DioException) return fallback;

  // 서버 응답 자체가 없는 경우 — 실패 사유는 네트워크다.
  if (error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.connectionError) {
    return '네트워크 연결을 확인해 주세요';
  }

  // 4xx(사용자가 조치할 수 있는 사유)만 서버 문구를 그대로 노출한다.
  final status = error.response?.statusCode ?? 0;
  if (status < 400 || status >= 500) return fallback;

  final data = error.response?.data;
  if (data is! Map) return fallback;
  final err = data['error'];
  return _messageText(err is Map ? err['message'] : null) ??
      _messageText(data['message']) ??
      fallback;
}

/// 서버가 "이 요청은 거절"이라고 답한 게 아니라 아예 닿지 못한 실패인지.
/// (네트워크 없음/타임아웃/5xx) — 인증 실패와 구분해야 할 때 쓴다.
bool isUnreachableError(Object error) {
  if (error is! DioException) return false;
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return true;
    default:
      break;
  }
  final status = error.response?.statusCode ?? 0;
  return status == 0 || status >= 500;
}

/// message 는 String 이 기본이지만, 검증 실패 응답이 배열로 올 수 있어 방어한다.
String? _messageText(dynamic message) {
  if (message is String) {
    final text = message.trim();
    return text.isEmpty ? null : text;
  }
  if (message is List) {
    final text = message.whereType<String>().join(', ').trim();
    return text.isEmpty ? null : text;
  }
  return null;
}
