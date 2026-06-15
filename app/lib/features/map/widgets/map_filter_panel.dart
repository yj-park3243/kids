import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../map_filter.dart';

/// 지도 상단 필터 패널 — 접었다 폈다. 칩을 탭하면 즉시 [onChanged].
class MapFilterPanel extends StatefulWidget {
  const MapFilterPanel({
    super.key,
    required this.filter,
    required this.children,
    required this.onChanged,
    this.isSingleParent = false,
  });

  final MapFilter filter;

  /// 연령 칩에 노출할 내 아이 목록. 등록된 모든 아이가 각자 칩으로 보인다.
  final List<MapFilterChildInfo> children;

  final ValueChanged<MapFilter> onChanged;

  /// 한부모 가정 계정 여부 — 한부모 전용 필터 노출 조건.
  final bool isSingleParent;

  @override
  State<MapFilterPanel> createState() => _MapFilterPanelState();
}

class MapFilterChildInfo {
  final String nickname;
  final int ageMonth;
  const MapFilterChildInfo({required this.nickname, required this.ageMonth});
}

class _MapFilterPanelState extends State<MapFilterPanel> {
  bool _expanded = false;

  // 섹션별 칩 색 — 그룹마다 다른 보조 색으로 단조로움을 덜어준다.
  static const Color _ageColor = AppColors.primary;
  static const Color _dateColor = AppColors.accentCoral;
  static const Color _timeColor = AppColors.accentLavender;
  static const Color _placeColor = AppColors.primaryDark;
  static const Color _joinColor = AppColors.secondaryDark;

  MapFilter get _f => widget.filter;
  void _emit(MapFilter f) => widget.onChanged(f);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(),
          // 헤더 바로 아래 "오늘만 보기" 빠른 토글 — 패널을 펼치지 않아도 보인다.
          // 내부적으로 날짜 필터(MapDateFilter)를 today ↔ all 로 토글한다.
          _quickTodayRow(),
          if (_expanded) ...[
            const Divider(height: 1, color: AppColors.divider),
            _body(),
          ],
        ],
      ),
    );
  }

  Widget _quickTodayRow() {
    final isToday = _f.date == MapDateFilter.today;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          _toggle('오늘만 보기', isToday, () {
            _emit(_f.copyWith(
              date: isToday ? MapDateFilter.all : MapDateFilter.today,
            ));
          }),
        ],
      ),
    );
  }

  Widget _header() {
    final count = _f.activeCount;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.tune_rounded, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('필터', style: AppTextStyles.body2Bold),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
            const Spacer(),
            Text(
              _expanded ? '접기' : '펼치기',
              style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
            ),
            Icon(
              _expanded
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section('연령', [
            _chip('전체', _f.ageMonth == null, _ageColor,
                () => _emit(_f.copyWith(ageMonth: null))),
            for (final c in widget.children)
              _chip(
                '${c.nickname} ${AppDateUtils.formatAgeMonths(c.ageMonth)}',
                _f.ageMonth == c.ageMonth,
                _ageColor,
                () => _emit(_f.copyWith(ageMonth: c.ageMonth)),
              ),
          ]),
          _section(
            '날짜',
            MapDateFilter.values
                .map((d) => _chip(d.label, _f.date == d, _dateColor,
                    () => _emit(_f.copyWith(date: d))))
                .toList(),
          ),
          _section(
            '시간',
            MapTimeFilter.values
                .map((t) => _chip(t.label, _f.time == t, _timeColor,
                    () => _emit(_f.copyWith(time: t))))
                .toList(),
          ),
          _section('장소', [
            _chip('전체', _f.placeType == null, _placeColor,
                () => _emit(_f.copyWith(placeType: null))),
            ...AppConstants.placeTypes.entries.map((e) => _chip(
                  e.value,
                  _f.placeType == e.key,
                  _placeColor,
                  () => _emit(_f.copyWith(placeType: e.key)),
                )),
          ]),
          _section('입장 방식', [
            _chip('전체', _f.joinType == null, _joinColor,
                () => _emit(_f.copyWith(joinType: null))),
            _chip('자유 입장', _f.joinType == 'FREE', _joinColor,
                () => _emit(_f.copyWith(joinType: 'FREE'))),
            _chip('승인 필요', _f.joinType == 'APPROVAL', _joinColor,
                () => _emit(_f.copyWith(joinType: 'APPROVAL'))),
          ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _toggle('무료만', _f.freeOnly,
                  () => _emit(_f.copyWith(freeOnly: !_f.freeOnly))),
              _toggle('또래 부모(±5)', _f.parentAgeMatch,
                  () => _emit(_f.copyWith(parentAgeMatch: !_f.parentAgeMatch))),
              if (widget.isSingleParent)
                _toggle('한부모만', _f.singleParentOnly,
                    () => _emit(
                        _f.copyWith(singleParentOnly: !_f.singleParentOnly))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section(String label, List<Widget> chips) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: chips),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          // 비선택 시에도 섹션 색을 옅게 깔아 그룹을 구분한다.
          color: selected
              ? color.withValues(alpha: 0.16)
              : color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.3),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: selected ? color : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _toggle(String label, bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: on ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: on ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              on ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 15,
              color: on ? Colors.white : AppColors.textHint,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: on ? Colors.white : AppColors.textSecondary,
                fontWeight: on ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
