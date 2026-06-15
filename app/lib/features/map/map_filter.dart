// 지도 필터 — 모임을 거의 모든 조건으로 좁힌다.
// 서버 GET /rooms/map 의 쿼리 파라미터로 변환된다.

enum MapDateFilter { all, today, tomorrow, thisWeek }

enum MapTimeFilter { all, morning, afternoon, evening }

extension MapDateFilterLabel on MapDateFilter {
  String get label => switch (this) {
        MapDateFilter.all => '전체',
        MapDateFilter.today => '오늘',
        MapDateFilter.tomorrow => '내일',
        MapDateFilter.thisWeek => '이번 주',
      };
}

extension MapTimeFilterLabel on MapTimeFilter {
  String get label => switch (this) {
        MapTimeFilter.all => '전체',
        MapTimeFilter.morning => '오전',
        MapTimeFilter.afternoon => '오후',
        MapTimeFilter.evening => '저녁',
      };
}

class MapFilter {
  final int? ageMonth; // 연령(개월) — 기본값은 선택된 아이 기준
  final MapDateFilter date;
  final MapTimeFilter time;
  final String? placeType; // null=전체
  final String? joinType; // null=전체, 'FREE' | 'APPROVAL'
  final bool freeOnly;
  final bool singleParentOnly;

  const MapFilter({
    this.ageMonth,
    this.date = MapDateFilter.all,
    this.time = MapTimeFilter.all,
    this.placeType,
    this.joinType,
    this.freeOnly = false,
    this.singleParentOnly = false,
  });

  /// 기본 필터 — 연령만 선택된 아이 개월수로 세팅, 나머지는 전체.
  factory MapFilter.initial({int? ageMonth}) => MapFilter(ageMonth: ageMonth);

  static const Object _keep = Object();

  /// nullable 필드는 _keep 센티넬로 "변경 안 함"과 "null 로 비움"을 구분한다.
  MapFilter copyWith({
    Object? ageMonth = _keep,
    MapDateFilter? date,
    MapTimeFilter? time,
    Object? placeType = _keep,
    Object? joinType = _keep,
    bool? freeOnly,
    bool? singleParentOnly,
  }) {
    return MapFilter(
      ageMonth:
          identical(ageMonth, _keep) ? this.ageMonth : ageMonth as int?,
      date: date ?? this.date,
      time: time ?? this.time,
      placeType:
          identical(placeType, _keep) ? this.placeType : placeType as String?,
      joinType:
          identical(joinType, _keep) ? this.joinType : joinType as String?,
      freeOnly: freeOnly ?? this.freeOnly,
      singleParentOnly: singleParentOnly ?? this.singleParentOnly,
    );
  }

  /// 연령 외 활성 필터 개수 — "필터 (N)" 뱃지에 쓴다.
  int get activeCount {
    var n = 0;
    if (date != MapDateFilter.all) n++;
    if (time != MapTimeFilter.all) n++;
    if (placeType != null) n++;
    if (joinType != null) n++;
    if (freeOnly) n++;
    if (singleParentOnly) n++;
    return n;
  }

  /// 서버 /rooms/map 쿼리 파라미터.
  Map<String, dynamic> toQuery() {
    final q = <String, dynamic>{};
    if (ageMonth != null) q['ageMonth'] = ageMonth;
    final dr = _dateRange();
    if (dr != null) {
      q['dateFrom'] = dr.$1;
      q['dateTo'] = dr.$2;
    }
    final tr = _timeRange();
    if (tr != null) {
      q['startTimeFrom'] = tr.$1;
      q['startTimeTo'] = tr.$2;
    }
    if (placeType != null) q['placeType'] = placeType;
    if (joinType != null) q['joinType'] = joinType;
    if (freeOnly) q['costFree'] = true;
    if (singleParentOnly) q['singleParentOnly'] = true;
    return q;
  }

  (String, String)? _dateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    switch (date) {
      case MapDateFilter.all:
        return null;
      case MapDateFilter.today:
        return (fmt(today), fmt(today));
      case MapDateFilter.tomorrow:
        final t = today.add(const Duration(days: 1));
        return (fmt(t), fmt(t));
      case MapDateFilter.thisWeek:
        // 오늘 ~ 이번 주 일요일 (weekday: 월=1 … 일=7)
        final sun = today.add(Duration(days: DateTime.sunday - today.weekday));
        return (fmt(today), fmt(sun));
    }
  }

  (String, String)? _timeRange() {
    switch (time) {
      case MapTimeFilter.all:
        return null;
      case MapTimeFilter.morning:
        return ('06:00', '11:59');
      case MapTimeFilter.afternoon:
        return ('12:00', '17:59');
      case MapTimeFilter.evening:
        return ('18:00', '23:59');
    }
  }
}
