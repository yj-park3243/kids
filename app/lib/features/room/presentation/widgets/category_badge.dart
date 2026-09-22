import 'package:flutter/material.dart';
import '../../../../widgets/design/design_chip.dart';

/// 방 카테고리 배지. genderFilter / singleParentOnly 조합으로 라벨 표시.
/// ALL + false 조합은 빈 위젯 반환.
class CategoryBadge extends StatelessWidget {
  final String genderFilter; // 'ALL' | 'MOM_ONLY' | 'DAD_ONLY'
  final bool singleParentOnly;

  const CategoryBadge({
    super.key,
    required this.genderFilter,
    required this.singleParentOnly,
  });

  String? get _label {
    if (genderFilter == 'ALL' && !singleParentOnly) return null;
    if (genderFilter == 'MOM_ONLY' && !singleParentOnly) return '엄마만';
    if (genderFilter == 'DAD_ONLY' && !singleParentOnly) return '아빠만';
    if (genderFilter == 'ALL' && singleParentOnly) return '싱글맘·싱글대디';
    if (genderFilter == 'MOM_ONLY' && singleParentOnly) return '싱글맘';
    if (genderFilter == 'DAD_ONLY' && singleParentOnly) return '싱글대디';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final label = _label;
    if (label == null) return const SizedBox.shrink();

    // 성별·한부모는 '그 밖의 속성' — 회색 pill. (docs/09_UI_수첩안.md)
    return Pill(label: label, tone: PillTone.muted);
  }
}
