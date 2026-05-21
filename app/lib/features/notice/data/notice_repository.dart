import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/response_utils.dart';
import '../../../models/notice.dart';

class NoticeRepository {
  final Dio _dio = ApiClient.instance;

  /// 공지 목록 (고정 우선 → 최신순).
  Future<List<Notice>> getNotices({int page = 1, int limit = 20}) async {
    final res = await _dio.get(
      ApiConstants.notices,
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = res.data['data'] ?? res.data;
    return extractItems(data)
        .map((e) => Notice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 홈 배너용 고정 공지 (최대 5).
  Future<List<Notice>> getPinnedNotices() async {
    final res = await _dio.get(ApiConstants.noticesPinned);
    final data = res.data['data'] ?? res.data;
    return extractItems(data)
        .map((e) => Notice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 공지 상세.
  Future<Notice> getNotice(String id) async {
    final res = await _dio.get(ApiConstants.noticeById(id));
    final data = res.data['data'] ?? res.data;
    return Notice.fromJson(data as Map<String, dynamic>);
  }
}

final noticeRepositoryProvider = Provider<NoticeRepository>((ref) {
  return NoticeRepository();
});
