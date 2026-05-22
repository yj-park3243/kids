import 'dart:async';

import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

class AuthInterceptor extends Interceptor {
  final Dio _dio;

  /// refresh 진행 중이면 완료될 때까지 다른 401 요청들이 기다린다.
  Completer<bool>? _refreshing;

  AuthInterceptor(this._dio);

  static const _noAuthPaths = [
    ApiConstants.socialLogin,
    ApiConstants.emailLogin,
    ApiConstants.emailRegister,
    ApiConstants.refreshToken,
  ];

  bool _isNoAuth(String path) => _noAuthPaths.any((p) => path.contains(p));

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isNoAuth(options.path)) {
      final token = await SecureStorage.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final path = err.requestOptions.path;

    // refresh 엔드포인트 자체가 401/403 → refresh token 이 진짜로 무효.
    if (path.contains(ApiConstants.refreshToken)) {
      if (status == 401 || status == 403) {
        await SecureStorage.clearTokens();
      }
      return handler.next(err);
    }

    // 401 이 아니거나 인증 불필요 요청 → 그대로 전파.
    if (status != 401 || _isNoAuth(path)) {
      return handler.next(err);
    }

    // 이미 refresh 진행 중 — 끝날 때까지 대기 후 재시도.
    if (_refreshing != null) {
      final ok = await _refreshing!.future;
      if (!ok) return handler.next(err);
      return _retry(err, handler);
    }

    // refresh 시작.
    final completer = Completer<bool>();
    _refreshing = completer;
    try {
      final refreshToken = await SecureStorage.getRefreshToken();
      if (refreshToken == null) {
        _finishRefresh(completer, false);
        return handler.next(err);
      }

      final response = await _dio.post(
        ApiConstants.refreshToken,
        data: {'refreshToken': refreshToken},
      );
      final data = response.data['data'] ?? response.data;
      final newAccess = data['accessToken'] as String?;
      final newRefresh = data['refreshToken'] as String?;
      if (newAccess == null || newRefresh == null) {
        // 응답 형식 이상 — 일시적일 수 있으므로 토큰은 유지.
        _finishRefresh(completer, false);
        return handler.next(err);
      }

      await SecureStorage.saveTokens(
        accessToken: newAccess,
        refreshToken: newRefresh,
      );
      _finishRefresh(completer, true);
      return _retry(err, handler);
    } on DioException catch (e) {
      // 서버가 refresh token 을 명시적으로 거부(401/403)한 경우에만 정리한다.
      // 네트워크 오류·타임아웃·5xx 는 일시적이므로 토큰을 지우지 않는다.
      final rs = e.response?.statusCode;
      if (rs == 401 || rs == 403) {
        await SecureStorage.clearTokens();
      }
      _finishRefresh(completer, false);
      return handler.next(err);
    } catch (_) {
      _finishRefresh(completer, false);
      return handler.next(err);
    }
  }

  void _finishRefresh(Completer<bool> completer, bool ok) {
    _refreshing = null;
    if (!completer.isCompleted) completer.complete(ok);
  }

  /// 새로 저장된 access token 으로 실패한 요청을 재시도한다.
  Future<void> _retry(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      final token = await SecureStorage.getAccessToken();
      final opts = err.requestOptions;
      opts.headers['Authorization'] = 'Bearer $token';
      final retry = await _dio.fetch(opts);
      handler.resolve(retry);
    } catch (_) {
      handler.next(err);
    }
  }
}
