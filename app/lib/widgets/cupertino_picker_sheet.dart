import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';

/// 하단 시트에 Cupertino 휠 picker 를 띄우고 결과를 반환하는 helper.
///
/// 모달 상단에 '취소 / 타이틀 / 확인' 헤더가 있고, 본문은 caller 가 그리는 picker.
/// 사용자가 휠을 돌리는 동안 [onChanged] 가 호출돼 [_state] 가 갱신되고,
/// '확인' 을 누르면 마지막 값이 반환된다.
Future<T?> showPickerSheet<T>({
  required BuildContext context,
  required String title,
  required T initial,
  required Widget Function(T current, ValueChanged<T> onChanged) builder,
}) {
  T current = initial;
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: SizedBox(
          height: 320,
          child: Column(
            children: [
              // 그립 인디케이터
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 헤더
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text('취소', style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary)),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(title, style: AppTextStyles.body1Bold),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(current),
                      child: Text(
                        '확인',
                        style: AppTextStyles.body2Bold.copyWith(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: builder(current, (v) => current = v),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// 날짜 선택 — CupertinoDatePicker(mode: date).
Future<DateTime?> showCupertinoDateSheet(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
}) {
  return showPickerSheet<DateTime>(
    context: context,
    title: '날짜 선택',
    initial: initial,
    builder: (current, onChanged) => CupertinoDatePicker(
      mode: CupertinoDatePickerMode.date,
      initialDateTime: current,
      minimumDate: first,
      maximumDate: last,
      dateOrder: DatePickerDateOrder.ymd,
      onDateTimeChanged: onChanged,
    ),
  );
}

/// 개월수 선택 휠 picker (0~max). 종료 개월수는 [minimum] 으로 시작 개월수를 받음.
Future<int?> showCupertinoMonthsSheet(
  BuildContext context, {
  required int initial,
  int minimum = 0,
  int maximum = 84,
  String title = '개월수 선택',
}) {
  final start = minimum.clamp(0, maximum);
  final clampedInitial = initial.clamp(start, maximum);
  final controller = FixedExtentScrollController(
    initialItem: clampedInitial - start,
  );
  return showPickerSheet<int>(
    context: context,
    title: title,
    initial: clampedInitial,
    builder: (current, onChanged) => CupertinoPicker(
      scrollController: controller,
      itemExtent: 40,
      onSelectedItemChanged: (i) => onChanged(start + i),
      children: [
        for (var m = start; m <= maximum; m++)
          Center(child: Text('$m개월', style: const TextStyle(fontSize: 18))),
      ],
    ),
  );
}

/// 정수/문자열 등 임의 리스트에서 한 값을 휠로 고르는 시트.
///
/// DropdownButton 대체용. `format` 으로 표시 문자열 커스터마이즈.
/// 예) 연도 선택: `options: [2026, 2025, ...], format: (y) => '$y년'`.
Future<T?> showWheelSheet<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required T? initial,
  required String Function(T) format,
}) {
  if (options.isEmpty) return Future.value(null);
  final initialIndex = (initial != null ? options.indexOf(initial) : -1)
      .clamp(0, options.length - 1);
  final controller = FixedExtentScrollController(initialItem: initialIndex);
  return showPickerSheet<T>(
    context: context,
    title: title,
    initial: options[initialIndex],
    builder: (current, onChanged) => CupertinoPicker(
      scrollController: controller,
      itemExtent: 40,
      onSelectedItemChanged: (i) => onChanged(options[i]),
      children: [
        for (final v in options)
          Center(child: Text(format(v), style: const TextStyle(fontSize: 18))),
      ],
    ),
  );
}

/// 시간 선택 — CupertinoDatePicker(mode: time, use24h:false).
/// [minimum] 이 주어지면 그 시각 이전은 선택할 수 없음 (종료시간 가드용).
Future<TimeOfDay?> showCupertinoTimeSheet(
  BuildContext context, {
  required TimeOfDay initial,
  String title = '시간 선택',
  TimeOfDay? minimum,
}) async {
  final today = DateTime(2000, 1, 1);
  var initialDt = DateTime(today.year, today.month, today.day, initial.hour, initial.minute);
  DateTime? minDt;
  if (minimum != null) {
    minDt = DateTime(today.year, today.month, today.day, minimum.hour, minimum.minute);
    if (initialDt.isBefore(minDt)) initialDt = minDt;
  }

  final picked = await showPickerSheet<DateTime>(
    context: context,
    title: title,
    initial: initialDt,
    builder: (current, onChanged) => CupertinoDatePicker(
      mode: CupertinoDatePickerMode.time,
      initialDateTime: current,
      minimumDate: minDt,
      use24hFormat: false,
      minuteInterval: 10,
      onDateTimeChanged: onChanged,
    ),
  );
  if (picked == null) return null;
  return TimeOfDay(hour: picked.hour, minute: picked.minute);
}
