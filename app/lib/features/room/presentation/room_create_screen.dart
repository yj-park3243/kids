import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/validators.dart';
import '../../../models/user.dart';
import '../../../providers/selected_child_provider.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/common_button.dart';
import '../../../widgets/common_input.dart';
import '../../../widgets/region_picker.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/room_detail_provider.dart';

class RoomCreateScreen extends ConsumerStatefulWidget {
  const RoomCreateScreen({super.key});

  @override
  ConsumerState<RoomCreateScreen> createState() => _RoomCreateScreenState();
}

class _RoomCreateScreenState extends ConsumerState<RoomCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _placeNameController = TextEditingController();
  final _placeAddressController = TextEditingController();
  final _costController = TextEditingController();
  final _costDescController = TextEditingController();
  final _tagController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _regionSido;
  String? _regionSigungu;
  String? _regionDong;
  String _placeType = 'PLAYGROUND';
  RangeValues _ageRange = const RangeValues(0, 36);
  int _maxMembers = 5;
  String _joinType = 'FREE';
  bool _isFree = true;
  final List<String> _tags = [];
  bool _isLoading = false;
  Child? _selectedChild;

  @override
  void initState() {
    super.initState();
    // 글로벌 선택된 아이로 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final child = ref.read(selectedChildProvider);
      if (child != null) {
        _applyChildAgeRange(child);
      }
    });
  }

  /// 선택된 아이의 개월수 기준으로 범위 자동 설정 (±3개월)
  void _applyChildAgeRange(Child child) {
    final ageMonths = AppDateUtils.calculateAgeMonths(child.birthYear, child.birthMonth);
    final minAge = max(0, ageMonths - 3).toDouble();
    final maxAge = min(84, ageMonths + 3).toDouble();
    setState(() {
      _selectedChild = child;
      _ageRange = RangeValues(minAge, maxAge);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _placeNameController.dispose();
    _placeAddressController.dispose();
    _costController.dispose();
    _costDescController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _selectTime(bool isStart) async {
    final time = await showTimePicker(
      context: context,
      initialTime: isStart
          ? const TimeOfDay(hour: 14, minute: 0)
          : const TimeOfDay(hour: 16, minute: 0),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (time != null) {
      setState(() {
        if (isStart) {
          _startTime = time;
        } else {
          _endTime = time;
        }
      });
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isEmpty || _tags.length >= 5 || tag.length > 10 || _tags.contains(tag)) return;
    setState(() {
      _tags.add(tag);
      _tagController.clear();
    });
  }

  Widget _buildChildSelector() {
    final children = ref.watch(authProvider).user?.children ?? [];
    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('어떤 아이의 모임인가요?', style: AppTextStyles.body2Bold),
        const SizedBox(height: 4),
        Text(
          '아이를 선택하면 개월수 범위가 자동 설정됩니다',
          style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: children.map((child) {
            final ageMonths = AppDateUtils.calculateAgeMonths(
                child.birthYear, child.birthMonth);
            final isSelected = _selectedChild?.id == child.id;

            return GestureDetector(
              onTap: () => _applyChildAgeRange(child),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.secondary.withValues(alpha: 0.12)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.secondary : AppColors.divider,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.child_care_rounded,
                      size: 18,
                      color: isSelected
                          ? AppColors.secondary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      child.nickname,
                      style: AppTextStyles.body2.copyWith(
                        color: isSelected
                            ? AppColors.secondary
                            : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.secondary.withValues(alpha: 0.15)
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        AppDateUtils.formatAgeMonths(ageMonths),
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11,
                          color: isSelected
                              ? AppColors.secondary
                              : AppColors.textHint,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null || _startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('날짜와 시작 시간을 선택해 주세요'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    if (_regionSido == null || _regionSigungu == null || _regionDong == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('지역을 선택해 주세요'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final roomData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'regionSido': _regionSido,
        'regionSigungu': _regionSigungu,
        'regionDong': _regionDong,
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
        'startTime':
            '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}',
        if (_endTime != null)
          'endTime':
              '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}',
        'ageMonthMin': _ageRange.start.round(),
        'ageMonthMax': _ageRange.end.round(),
        'placeType': _placeType,
        'placeName': _placeNameController.text.isNotEmpty
            ? _placeNameController.text.trim()
            : null,
        'placeAddress': _placeAddressController.text.isNotEmpty
            ? _placeAddressController.text.trim()
            : null,
        'maxMembers': _maxMembers,
        'joinType': _joinType,
        'cost': _isFree ? 0 : int.tryParse(_costController.text) ?? 0,
        'costDescription':
            _costDescController.text.isNotEmpty ? _costDescController.text.trim() : null,
        'tags': _tags,
      };

      final room = await ref.read(roomRepositoryProvider).createRoom(roomData);
      if (mounted) {
        context.pop();
        context.push('/rooms/${room.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('방 생성에 실패했습니다'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: '모임 만들기'),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // 아이 선택
              _buildChildSelector(),
              const SizedBox(height: 20),

              // Title
              CommonInput(
                label: '제목',
                hint: '모임 제목을 입력하세요',
                controller: _titleController,
                validator: Validators.roomTitle,
                maxLength: 30,
              ),
              const SizedBox(height: 20),

              // Description
              CommonInput(
                label: '설명',
                hint: '모임에 대한 설명을 입력하세요',
                controller: _descriptionController,
                validator: Validators.roomDescription,
                maxLines: 4,
                maxLength: 500,
              ),
              const SizedBox(height: 20),

              // Date
              Text('날짜', style: AppTextStyles.body2Bold),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        _selectedDate != null
                            ? DateFormat('yyyy년 M월 d일 (E)', 'ko')
                                .format(_selectedDate!)
                            : '날짜를 선택하세요',
                        style: AppTextStyles.body1.copyWith(
                          color: _selectedDate != null
                              ? AppColors.textPrimary
                              : AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Time
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('시작 시간', style: AppTextStyles.body2Bold),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _selectTime(true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Text(
                              _startTime?.format(context) ?? '선택',
                              style: AppTextStyles.body1.copyWith(
                                color: _startTime != null
                                    ? AppColors.textPrimary
                                    : AppColors.textHint,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('종료 시간', style: AppTextStyles.body2Bold),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _selectTime(false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Text(
                              _endTime?.format(context) ?? '선택 (선택)',
                              style: AppTextStyles.body1.copyWith(
                                color: _endTime != null
                                    ? AppColors.textPrimary
                                    : AppColors.textHint,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Region
              RegionPicker(
                onSelected: (sido, sigungu, dong) {
                  setState(() {
                    _regionSido = sido;
                    _regionSigungu = sigungu;
                    _regionDong = dong;
                  });
                },
              ),
              const SizedBox(height: 20),

              // Place Type
              Text('장소 유형', style: AppTextStyles.body2Bold),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppConstants.placeTypes.entries
                    .map((e) => _PlaceTypeChip(
                          type: e.key,
                          label: e.value,
                          isSelected: _placeType == e.key,
                          onTap: () => setState(() => _placeType = e.key),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),

              // Place name & address
              CommonInput(
                label: '장소명 (선택)',
                hint: '예: 역삼 어린이공원',
                controller: _placeNameController,
              ),
              const SizedBox(height: 12),
              CommonInput(
                label: '상세 주소 (선택)',
                hint: '예: 서울 강남구 역삼동 123',
                controller: _placeAddressController,
              ),
              const SizedBox(height: 20),

              // Age range
              Row(
                children: [
                  Text('대상 개월수', style: AppTextStyles.body2Bold),
                  if (_selectedChild != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_selectedChild!.nickname} 기준',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${_ageRange.start.round()}개월 ~ ${_ageRange.end.round()}개월',
                style: AppTextStyles.body2.copyWith(color: AppColors.primary),
              ),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: AppColors.primary.withValues(alpha: 0.2),
                  thumbColor: AppColors.primary,
                  overlayColor: AppColors.primary.withValues(alpha: 0.1),
                ),
                child: RangeSlider(
                values: _ageRange,
                min: 0,
                max: 84,
                divisions: 84,
                labels: RangeLabels(
                  '${_ageRange.start.round()}개월',
                  '${_ageRange.end.round()}개월',
                ),
                onChanged: (values) => setState(() => _ageRange = values),
              ),
              ),
              const SizedBox(height: 20),

              // Max members
              Text('최대 인원', style: AppTextStyles.body2Bold),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: _maxMembers > 2
                        ? () => setState(() => _maxMembers--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                    color: AppColors.primary,
                  ),
                  Container(
                    width: 60,
                    alignment: Alignment.center,
                    child: Text(
                      '$_maxMembers명',
                      style: AppTextStyles.heading3,
                    ),
                  ),
                  IconButton(
                    onPressed: _maxMembers < 10
                        ? () => setState(() => _maxMembers++)
                        : null,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    color: AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Join type
              Text('입장 방식', style: AppTextStyles.body2Bold),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _OptionChip(
                      label: '자유 입장',
                      subtitle: '누구나 바로 참여',
                      isSelected: _joinType == 'FREE',
                      onTap: () => setState(() => _joinType = 'FREE'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _OptionChip(
                      label: '승인 필요',
                      subtitle: '방장 수락 후 참여',
                      isSelected: _joinType == 'APPROVAL',
                      onTap: () => setState(() => _joinType = 'APPROVAL'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Cost
              Row(
                children: [
                  Text('비용', style: AppTextStyles.body2Bold),
                  const Spacer(),
                  Text('무료', style: AppTextStyles.body2),
                  Switch(
                    value: _isFree,
                    activeTrackColor: AppColors.primary,
                    onChanged: (value) => setState(() => _isFree = value),
                  ),
                ],
              ),
              if (!_isFree) ...[
                const SizedBox(height: 8),
                CommonInput(
                  hint: '금액 (원)',
                  controller: _costController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                CommonInput(
                  hint: '비용 설명 (예: 키즈카페 입장료 더치페이)',
                  controller: _costDescController,
                ),
              ],
              const SizedBox(height: 20),

              // Tags
              Text('태그 (최대 5개)', style: AppTextStyles.body2Bold),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: CommonInput(
                      hint: '태그 입력 후 추가',
                      controller: _tagController,
                      maxLength: 10,
                      onSubmitted: (_) => _addTag(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _addTag,
                    icon:
                        const Icon(Icons.add_circle_rounded, color: AppColors.primary),
                    iconSize: 36,
                  ),
                ],
              ),
              if (_tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tags
                      .map((tag) => Chip(
                            label: Text('#$tag', style: AppTextStyles.tag),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            deleteIconColor: AppColors.primary,
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.08),
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            onDeleted: () =>
                                setState(() => _tags.remove(tag)),
                          ))
                      .toList(),
                ),
              ],

              const SizedBox(height: 40),

              PrimaryButton(
                text: '모임 만들기',
                isLoading: _isLoading,
                icon: Icons.celebration_rounded,
                onPressed: _submit,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceTypeChip extends StatelessWidget {
  final String type;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlaceTypeChip({
    required this.type,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconCode = AppConstants.placeTypeIcons[type] ?? 0xe55f;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              IconData(iconCode, fontFamily: 'MaterialIcons'),
              size: 18,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.body2.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionChip({
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: AppTextStyles.body2Bold.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                color: isSelected ? AppColors.primary : AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
