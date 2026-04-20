import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/room.dart';
import '../data/home_repository.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository();
});

// Date filter
enum DateFilter { today, tomorrow, thisWeek, all }

// Home state
class HomeState {
  final List<Room> rooms;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? nextCursor;
  final String? error;
  final DateFilter dateFilter;
  final String? placeTypeFilter;
  final int unreadCount;

  const HomeState({
    this.rooms = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.nextCursor,
    this.error,
    this.dateFilter = DateFilter.all,
    this.placeTypeFilter,
    this.unreadCount = 0,
  });

  HomeState copyWith({
    List<Room>? rooms,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? nextCursor,
    String? error,
    DateFilter? dateFilter,
    String? placeTypeFilter,
    int? unreadCount,
  }) {
    return HomeState(
      rooms: rooms ?? this.rooms,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      error: error,
      dateFilter: dateFilter ?? this.dateFilter,
      placeTypeFilter: placeTypeFilter ?? this.placeTypeFilter,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class HomeNotifier extends StateNotifier<HomeState> {
  final HomeRepository _repository;

  HomeNotifier(this._repository) : super(const HomeState());

  int? _selectedAgeMonth;

  Future<void> loadRooms({bool refresh = false, int? ageMonth}) async {
    if (state.isLoading) return;

    if (ageMonth != null || (refresh && ageMonth == null)) {
      _selectedAgeMonth = ageMonth;
    }

    state = state.copyWith(
      isLoading: true,
      error: null,
      rooms: refresh ? [] : state.rooms,
      nextCursor: refresh ? null : state.nextCursor,
    );

    try {
      final now = DateTime.now();
      String? dateFrom;
      String? dateTo;

      switch (state.dateFilter) {
        case DateFilter.today:
          dateFrom = _formatDate(now);
          dateTo = _formatDate(now);
          break;
        case DateFilter.tomorrow:
          final tomorrow = now.add(const Duration(days: 1));
          dateFrom = _formatDate(tomorrow);
          dateTo = _formatDate(tomorrow);
          break;
        case DateFilter.thisWeek:
          dateFrom = _formatDate(now);
          dateTo = _formatDate(now.add(const Duration(days: 7)));
          break;
        case DateFilter.all:
          dateFrom = _formatDate(now);
          break;
      }

      final result = await _repository.getRooms(
        dateFrom: dateFrom,
        dateTo: dateTo,
        placeType: state.placeTypeFilter,
        ageMonth: _selectedAgeMonth,
      );

      state = state.copyWith(
        rooms: result.items,
        isLoading: false,
        hasMore: result.hasMore,
        nextCursor: result.nextCursor,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '방 목록을 불러오는 데 실패했습니다',
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.nextCursor == null) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final result = await _repository.getRooms(
        cursor: state.nextCursor,
        placeType: state.placeTypeFilter,
      );

      state = state.copyWith(
        rooms: [...state.rooms, ...result.items],
        isLoadingMore: false,
        hasMore: result.hasMore,
        nextCursor: result.nextCursor,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void setDateFilter(DateFilter filter) {
    state = state.copyWith(dateFilter: filter);
    loadRooms(refresh: true);
  }

  void setPlaceTypeFilter(String? placeType) {
    state = state.copyWith(placeTypeFilter: placeType);
    loadRooms(refresh: true);
  }

  Future<void> loadUnreadCount() async {
    final count = await _repository.getUnreadNotificationCount();
    state = state.copyWith(unreadCount: count);
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>((ref) {
  final repository = ref.watch(homeRepositoryProvider);
  return HomeNotifier(repository);
});
