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
    Object? nextCursor = _unset,
    Object? error = _unset,
    DateFilter? dateFilter,
    Object? placeTypeFilter = _unset,
    int? unreadCount,
  }) {
    return HomeState(
      rooms: rooms ?? this.rooms,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      // sentinel: 안 넘기면 유지. `??` 였을 때는 refresh 의 null 이 무시돼
      // 커서 비우기가 동작하지 않았다.
      nextCursor:
          identical(nextCursor, _unset) ? this.nextCursor : nextCursor as String?,
      // sentinel: 안 넘기면 유지. 예전엔 항상 덮어써서 알림 카운트 응답 하나가
      // 목록 로드 실패 메시지를 지웠다.
      error: identical(error, _unset) ? this.error : error as String?,
      dateFilter: dateFilter ?? this.dateFilter,
      // sentinel: 명시적으로 null 을 넘기면 필터 해제됨 (기존 ?? 패턴은 null 을 ignore 했음)
      placeTypeFilter: identical(placeTypeFilter, _unset)
          ? this.placeTypeFilter
          : placeTypeFilter as String?,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

const Object _unset = Object();

class HomeNotifier extends StateNotifier<HomeState> {
  final HomeRepository _repository;

  HomeNotifier(this._repository) : super(const HomeState());

  int? _selectedAgeMonth;

  // 필터가 바뀌면 증가 — 뒤늦게 도착한 loadMore 응답을 버리는 토큰.
  int _loadSeq = 0;

  // 지금 목록을 만든 조건 — loadMore 는 '현재 필터'가 아니라 이 값으로 이어야
  // 페이지1과 페이지2의 조건이 어긋나지 않는다(로딩 중 칩을 눌러 필터만 바뀐 경우).
  ({String? from, String? to}) _appliedRange = (from: null, to: null);
  String? _appliedPlaceType;
  int? _appliedAgeMonth;

  Future<void> loadRooms({bool refresh = false}) async {
    if (state.isLoading) return;

    _loadSeq++;

    state = state.copyWith(
      isLoading: true,
      error: null,
      rooms: refresh ? [] : state.rooms,
      nextCursor: refresh ? null : state.nextCursor,
      // 새로 고치면 진행 중이던 '더 불러오기'는 무의미하다 — 스피너가 남고
      // 다음 페이징이 막히지 않도록 여기서 내린다(늦게 온 응답은 seq 로 버림).
      isLoadingMore: refresh ? false : state.isLoadingMore,
    );

    try {
      final range = _dateRange();
      _appliedRange = range;
      _appliedPlaceType = state.placeTypeFilter;
      _appliedAgeMonth = _selectedAgeMonth;

      final result = await _repository.getRooms(
        dateFrom: range.from,
        dateTo: range.to,
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
    if (state.isLoading ||
        state.isLoadingMore ||
        !state.hasMore ||
        state.nextCursor == null) {
      return;
    }

    state = state.copyWith(isLoadingMore: true);

    try {
      final seq = _loadSeq;

      final result = await _repository.getRooms(
        cursor: state.nextCursor,
        dateFrom: _appliedRange.from,
        dateTo: _appliedRange.to,
        placeType: _appliedPlaceType,
        ageMonth: _appliedAgeMonth,
      );

      // 응답을 기다리는 사이 필터가 바뀌었으면 이전 조건의 결과는 붙이지 않는다.
      // 상태는 건드리지 않는다 — isLoadingMore 는 이미 뒤에 시작된 loadMore 의 것이다.
      if (seq != _loadSeq) return;

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

  /// 아이 선택이 바뀔 때만 개월수 필터를 갱신한다.
  /// null 이면 '전체' — 개월수 조건 없이 다시 불러온다.
  void setAgeMonth(int? ageMonth) {
    _selectedAgeMonth = ageMonth;
    loadRooms(refresh: true);
  }

  Future<void> loadUnreadCount() async {
    final count = await _repository.getUnreadNotificationCount();
    state = state.copyWith(unreadCount: count);
  }

  /// 현재 날짜 필터의 조회 기간 — loadRooms/loadMore 가 같은 값을 쓴다.
  ({String? from, String? to}) _dateRange() {
    final now = DateTime.now();
    switch (state.dateFilter) {
      case DateFilter.today:
        return (from: _formatDate(now), to: _formatDate(now));
      case DateFilter.tomorrow:
        final tomorrow = now.add(const Duration(days: 1));
        return (from: _formatDate(tomorrow), to: _formatDate(tomorrow));
      case DateFilter.thisWeek:
        return (
          from: _formatDate(now),
          to: _formatDate(now.add(const Duration(days: 7))),
        );
      case DateFilter.all:
        return (from: _formatDate(now), to: null);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>((ref) {
  final repository = ref.watch(homeRepositoryProvider);
  return HomeNotifier(repository);
});
