import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/attendance_repository.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository();
});

class AttendanceSubmitState {
  final bool isSubmitting;
  final AttendanceResult? lastResult;
  final String? error;

  const AttendanceSubmitState({
    this.isSubmitting = false,
    this.lastResult,
    this.error,
  });

  AttendanceSubmitState copyWith({
    bool? isSubmitting,
    AttendanceResult? lastResult,
    String? error,
  }) {
    return AttendanceSubmitState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      lastResult: lastResult ?? this.lastResult,
      error: error,
    );
  }
}

class AttendanceSubmitNotifier extends StateNotifier<AttendanceSubmitState> {
  final AttendanceRepository _repo;
  final String roomId;

  AttendanceSubmitNotifier(this._repo, this.roomId)
      : super(const AttendanceSubmitState());

  Future<AttendanceResult?> submit(List<AttendanceRecord> records) async {
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      final result = await _repo.postAttendance(roomId, records);
      state = state.copyWith(isSubmitting: false, lastResult: result);
      return result;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: '출석 저장에 실패했습니다');
      return null;
    }
  }
}

final attendanceSubmitProvider = StateNotifierProvider.family<
    AttendanceSubmitNotifier, AttendanceSubmitState, String>((ref, roomId) {
  final repo = ref.watch(attendanceRepositoryProvider);
  return AttendanceSubmitNotifier(repo, roomId);
});
