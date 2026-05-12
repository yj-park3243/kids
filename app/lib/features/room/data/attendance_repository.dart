import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

class AttendanceRecord {
  final String userId;
  final bool attended;

  const AttendanceRecord({required this.userId, required this.attended});

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'status': attended ? 'ATTENDED' : 'NO_SHOW',
      };
}

class AttendanceResult {
  /// 노쇼 1회가 새로 적용된 유저 닉네임 목록.
  final List<String> noShowAppliedNicknames;

  const AttendanceResult({this.noShowAppliedNicknames = const []});

  factory AttendanceResult.fromJson(Map<String, dynamic> json) {
    final raw = (json['noShowApplied'] as List<dynamic>?) ?? [];
    final names = raw
        .map((e) {
          if (e is Map<String, dynamic>) {
            return (e['nickname'] ?? e['userId'] ?? '').toString();
          }
          return e.toString();
        })
        .where((s) => s.isNotEmpty)
        .toList();
    return AttendanceResult(noShowAppliedNicknames: names);
  }
}

class AttendanceRepository {
  final Dio _dio = ApiClient.instance;

  Future<AttendanceResult> postAttendance(
    String roomId,
    List<AttendanceRecord> records,
  ) async {
    final response = await _dio.post(
      '${ApiConstants.rooms}/$roomId/attendance',
      data: {
        'records': records.map((r) => r.toJson()).toList(),
      },
    );
    final data = response.data['data'] ?? response.data;
    if (data is Map<String, dynamic>) {
      return AttendanceResult.fromJson(data);
    }
    return const AttendanceResult();
  }
}
