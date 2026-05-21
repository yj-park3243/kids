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
    required this.childAgeMonth,
    required this.onChanged,
  });

  final MapFilter filter;
  final int? childAgeMonth;
  final ValueChanged<MapFilter> onChanged;

  @override
  State<MapFilterPanel> createState() => _MapFilterPanelState();
}

class _MapFilterPanelState extends State<MapFilterPanel> {
  bool _expanded = false;

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
          if (_expanded) ...[
            const Divider(height: 1, color: AppColors.divider),
            _body(),
          ],
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
    final childAge = widget.childAgeMonth;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section('연령', [
            _chip('전체', _f.ageMonth == null,
                () => _emit(_f.copyWith(ageMonth: null))),
            if (childAge != null)
              _chip(
                '우리 아이 ${AppDateUtils.formatAgeMonths(childAge)}',
                _f.ageMonth == childAge,
                () => _emit(_f.copyWith(ageMonth: childAge)),
              ),
          ]),
          _section(
            '날짜',
            MapDateFilter.values
                .map((d) => _chip(d.label, _f.date == d,
                    () => _emit(_f.copyWith(date: d))))
                .toList(),
          ),
          _section(
            '시간',
            MapTimeFilter.values
                .map((t) => _chip(t.label, _f.time == t,
                    () => _emit(_f.copyWith(time: t))))
                .toList(),
          ),
          _section('장소', [
            _chip('전체', _f.placeType == null,
                () => _emit(_f.copyWith(placeType: null))),
            ...AppConstants.placeTypes.entries.map((e) => _chip(
                  e.value,
                  _f.placeType == e.key,
                  () => _emit(_f.copyWith(placeType: e.key)),
                )),
          ]),
          _section('입장 방식', [
            _chip('전체', _f.joinType == null,
                () => _emit(_f.copyWith(joinType: null))),
            _chip('자유 입장', _f.joinType == 'FREE',
                () => _emit(_f.copyWith(joinType: 'FREE'))),
            _chip('승인 필요', _f.joinType == 'APPROVAL',
                () => _emit(_f.copyWith(joinType: 'APPROVAL'))),
          ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _toggle('무료만', _f.freeOnly,
                  () => _emit(_f.copyWith(freeOnly: !_f.freeOnly))),
              _toggle('한부모만', _f.singleParentOnly,
                  () => _emit(
                      _f.copyWith(singleParentOnly: !_f.singleParentOnly))),
              _toggle('번개모임만', _f.flashOnly,
                  () => _emit(_f.copyWith(flashOnly: !_f.flashOnly))),
            ],
          ),
          if (_f.activeCount > 0)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () =>
                    _emit(MapFilter.initial(ageMonth: _f.ageMonth)),
                child: Text(
                  '필터 초기화',
                  style:
                      AppTextStyles.caption.copyWith(color: AppColors.primary),
                ),
              ),
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

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: selected ? AppColors.primary : AppColors.textSecondary,
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
