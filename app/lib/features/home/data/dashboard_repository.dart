import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import 'dashboard_summary.dart';

class DashboardRepository {
  final Dio _dio = ApiClient.instance;

  Future<DashboardSummary> getMyDashboard() async {
    final response = await _dio.get('/dashboard/me');
    final data = response.data['data'] ?? response.data;
    return DashboardSummary.fromJson(data as Map<String, dynamic>);
  }
}
