import 'package:flutter_riverpod/flutter_riverpod.dart';
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
