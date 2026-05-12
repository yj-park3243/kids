import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../models/growth_guide.dart';

class GrowthGuideRepository {
  final Dio _dio = ApiClient.instance;

  Future<List<GrowthGuide>> getGuides() async {
    final response = await _dio.get(ApiConstants.guides);
    final data = response.data['data'] ?? response.data;
    final items =
        (data is Map && data['items'] != null) ? data['items'] : data;
    return (items as List<dynamic>)
        .map((e) => GrowthGuide.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GrowthGuide> getGuide(int ageMonth) async {
    final response = await _dio.get(ApiConstants.guide(ageMonth));
    final data = response.data['data'] ?? response.data;
    return GrowthGuide.fromJson(data as Map<String, dynamic>);
  }
}
