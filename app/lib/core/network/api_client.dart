import 'package:dio/dio.dart';
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

    dio.interceptors.addAll([
      AuthInterceptor(dio),
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
      ),
    ]);

    return dio;
  }

  // Reset (for testing or re-initialization)
  static void reset() {
    _dio?.close();
    _dio = null;
  }
}
