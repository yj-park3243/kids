import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../constants/api_constants.dart';
import 'api_interceptor.dart';

class ApiClient {
  static Dio? _dio;

  static Dio get instance {
    _dio ??= _createDio();
    return _dio!;
  }

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.apiUrl,
        connectTimeout: const Duration(milliseconds: ApiConstants.connectTimeout),
        receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(AuthInterceptor(dio));
    // 요청/응답 본문에 Authorization 헤더와 로그인 응답의 토큰 원문이 들어간다.
    // 릴리스에서 기기 로그(os_log)로 새어나가지 않도록 디버그에서만 붙인다.
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          error: true,
        ),
      );
    }

    return dio;
  }

  // Reset (for testing or re-initialization)
  static void reset() {
    _dio?.close();
    _dio = null;
  }
}
