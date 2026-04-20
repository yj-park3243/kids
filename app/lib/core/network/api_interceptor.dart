import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

class AuthInterceptor extends Interceptor {
  final Dio _dio;
  bool _isRefreshing = false;

  AuthInterceptor(this._dio);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip auth for login/register endpoints
    final noAuthPaths = [
      ApiConstants.socialLogin,
      ApiConstants.emailLogin,
      ApiConstants.emailRegister,
      ApiConstants.refreshToken,
      ApiConstants.resetPassword,
    ];

    if (!noAuthPaths.any((path) => options.path.contains(path))) {
      final token = await SecureStorage.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;

      try {
        final refreshToken = await SecureStorage.getRefreshToken();
        if (refreshToken == null) {
          _isRefreshing = false;
          return handler.next(err);
        }

        final response = await _dio.post(
          ApiConstants.refreshToken,
          data: {'refreshToken': refreshToken},
        );

        if (response.statusCode == 200) {
          final data = response.data['data'] ?? response.data;
          final newAccessToken = data['accessToken'] as String;
          final newRefreshToken = data['refreshToken'] as String;

          await SecureStorage.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
          );

          // Retry the failed request
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer $newAccessToken';

          final retryResponse = await _dio.fetch(opts);
          _isRefreshing = false;
          return handler.resolve(retryResponse);
        }
      } catch (e) {
        _isRefreshing = false;
        // Token refresh failed, clear tokens
        await SecureStorage.clearTokens();
      }

      _isRefreshing = false;
    }

    handler.next(err);
  }
}
