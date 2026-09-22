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

  /// 비밀번호 재설정용 KCP 인증 Form (로그인 불필요)
  /// GET /v1/auth/kcp/reset-form
  Future<String> getResetForm() async {
    final response = await _dio.get(ApiConstants.kcpResetForm);
    final data = response.data['data'] ?? response.data;
    return data['html'] as String;
  }
}

final kcpRepositoryProvider = Provider<KcpRepository>((ref) {
  return KcpRepository();
});
