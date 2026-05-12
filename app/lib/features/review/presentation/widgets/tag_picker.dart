import 'package:flutter/material.dart';
import '../../../../widgets/design/design_chip.dart';

/// 정성 태그 다중 선택 칩.
/// 선택 상태는 외부에서 제어 (controlled).
class TagPicker extends StatelessWidget {
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const TagPicker({
    super.key,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((tag) {
        final isSelected = selected.contains(tag);
        return DesignChip(
          label: tag,
          tone: isSelected ? ChipTone.primarySolid : ChipTone.primaryGhost,
          selected: isSelected,
          onTap: () => onToggle(tag),
          height: 32,
        );
      }).toList(),
    );
  }
}
