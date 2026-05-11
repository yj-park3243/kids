import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

/// KCP 본인인증 Repository
class KcpRepository {
  final Dio _dio = ApiClient.instance;

  /// KCP 인증 HTML Form 조회
  /// GET /v1/auth/kcp/form
  Future<String> getForm({String? returnUrl}) async {
    final response = await _dio.get(
      ApiConstants.kcpForm,
      queryParameters: returnUrl != null ? {'returnUrl': returnUrl} : null,
    );
    final data = response.data['data'] ?? response.data;
    return data['html'] as String;
  }
}

final kcpRepositoryProvider = Provider<KcpRepository>((ref) {
  return KcpRepository();
});
