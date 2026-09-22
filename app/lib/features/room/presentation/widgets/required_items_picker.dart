import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../widgets/design/design_chip.dart';
import '../../../../widgets/top_toast.dart';

const List<String> kSuggestedRequiredItems = [
  '기저귀',
  '물티슈',
  '간식',
  '돗자리',
  '여벌 옷',
  '모자',
  '자외선차단제',
];

const int _kMaxItems = 10;
const int _kMaxItemLength = 20;

/// 준비물 다중 선택 + 커스텀 추가. 최대 10개, 항목당 20자.
class RequiredItemsPicker extends StatefulWidget {
  final List<String> value;
  final ValueChanged<List<String>> onChanged;

  const RequiredItemsPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<RequiredItemsPicker> createState() => _RequiredItemsPickerState();
}

class _RequiredItemsPickerState extends State<RequiredItemsPicker> {
  final TextEditingController _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _toggle(String item) {
    final list = List<String>.from(widget.value);
    if (list.contains(item)) {
      list.remove(item);
    } else {
      if (list.length >= _kMaxItems) {
        _showError('준비물은 최대 $_kMaxItems개까지 추가할 수 있어요');
        return;
      }
      list.add(item);
    }
    widget.onChanged(list);
  }

  void _addCustom() {
    final item = _customController.text.trim();
    if (item.isEmpty) return;
    if (item.length > _kMaxItemLength) {
      _showError('준비물은 $_kMaxItemLength자 이내로 입력해 주세요');
      return;
    }
    if (widget.value.contains(item)) {
      _customController.clear();
      return;
    }
    if (widget.value.length >= _kMaxItems) {
      _showError('준비물은 최대 $_kMaxItems개까지 추가할 수 있어요');
      return;
    }
    widget.onChanged([...widget.value, item]);
    _customController.clear();
  }

  void _showError(String msg) {
    showTopToast(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('준비물', style: AppTextStyles.captionBold),
            const SizedBox(width: 6),
            Text('(선택, 최대 $_kMaxItems개)', style: AppTextStyles.caption),
          ],
        ),
        const SizedBox(height: 10),

        // Suggested
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kSuggestedRequiredItems
              .map((item) => FilterChipButton(
                    label: item,
                    selected: value.contains(item),
                    onTap: () => _toggle(item),
                  ))
              .toList(),
        ),

        const SizedBox(height: 12),

        // Custom add
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customController,
                maxLength: _kMaxItemLength,
                decoration: InputDecoration(
                  hintText: '직접 추가 (예: 비상약)',
                  hintStyle:
                      AppTextStyles.body1.copyWith(color: AppColors.ink3),
                  counterText: '',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.line2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.line2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.ink, width: 1.5),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
                onSubmitted: (_) => _addCustom(),
              ),
            ),
            IconButton(
              onPressed: _addCustom,
              icon: const Icon(Icons.add_circle_rounded, color: AppColors.ink),
              iconSize: 32,
            ),
          ],
        ),

        // Custom-added chips (those not in suggested)
        if (value.any((e) => !kSuggestedRequiredItems.contains(e))) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: value
                .where((e) => !kSuggestedRequiredItems.contains(e))
                .map((item) => Chip(
                      label: Text(item, style: AppTextStyles.tag),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      deleteIconColor: AppColors.ink3,
                      backgroundColor: AppColors.fill,
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                      onDeleted: () {
                        widget.onChanged(
                            value.where((e) => e != item).toList());
                      },
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}
