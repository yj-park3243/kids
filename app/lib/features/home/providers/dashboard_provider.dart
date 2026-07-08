import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/room.dart';
import '../../room/providers/room_detail_provider.dart';
import '../data/dashboard_repository.dart';
import '../data/dashboard_summary.dart';

final dashboardRepositoryProvider =
    Provider<DashboardRepository>((ref) => DashboardRepository());

class DashboardState {
  final DashboardSummary summary;
  final bool isLoading;
  final String? error;

  const DashboardState({
    this.summary = DashboardSummary.empty,
    this.isLoading = false,
    this.error,
  });

  DashboardState copyWith({
    DashboardSummary? summary,
    bool? isLoading,
    Object? error = _keep,
  }) {
    return DashboardState(
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _keep) ? this.error : error as String?,
    );
  }
}

const Object _keep = Object();

class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier(this._repo) : super(const DashboardState());

  final DashboardRepository _repo;

  Future<void> load({bool silent = false}) async {
    if (!silent) state = state.copyWith(isLoading: true, error: null);
    try {
      final summary = await _repo.getMyDashboard();
      state = state.copyWith(summary: summary, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '활동 일지를 불러오지 못했어요');
    }
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier(ref.read(dashboardRepositoryProvider));
});

// 참여/호스팅 중인 다가오는 모임. 방 상세에 들어갈 때 invalidate 되어
// 새로고침 없이 홈이 자동으로 최신 목록을 받는다.
final joinedRoomsProvider = FutureProvider<List<Room>>((ref) async {
  return ref.watch(roomRepositoryProvider).getMyRooms(
        type: 'ALL',
        status: 'UPCOMING',
      );
});

// 지난 모임 참여 이력 유무 — 예정 모임이 없을 때 홈 빈 화면이
// "첫 모임" 문구(신규 가입자용)를 쓸지 판단하는 용도.
final hasPastRoomsProvider = FutureProvider<bool>((ref) async {
  final rooms = await ref.watch(roomRepositoryProvider).getMyRooms(
        type: 'ALL',
        status: 'PAST',
      );
  return rooms.isNotEmpty;
});
