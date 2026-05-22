import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../features/support/data/support_repository.dart';

/// 전역 에러 리포터. 같은 메시지 30초 안에 반복되면 skip.
class ErrorReporter {
  ErrorReporter._();
  static final ErrorReporter instance = ErrorReporter._();

  final _repo = SupportRepository();
  final Map<String, int> _recent = {}; // signature → last ms
  static const _throttleMs = 30 * 1000;

  Future<void> report(
    String message, {
    String? stackTrace,
    String? screenName,
  }) async {
    if (kDebugMode) return; // 디버그 빌드에서는 안 보냄

    final sig = '${screenName ?? ''}|${message.substring(0, message.length > 80 ? 80 : message.length)}';
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _recent[sig] ?? 0;
    if (now - last < _throttleMs) return;
    _recent[sig] = now;
    if (_recent.length > 200) _recent.clear();

    try {
      await _repo.reportError(
        errorMessage: message,
        stackTrace: stackTrace,
        screenName: screenName,
        deviceInfo: {
          'platform': Platform.operatingSystem,
          'platformVersion': Platform.operatingSystemVersion,
        },
      );
    } catch (_) {
      // 리포트 전송 실패는 무시 — 앱 흐름에 영향 주지 않는다.
    }
  }
}
