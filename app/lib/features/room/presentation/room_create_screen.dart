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
import '../../../widgets/address_search_sheet.dart';
import '../../../widgets/cupertino_picker_sheet.dart';
import '../../../widgets/design/pink_blobs.dart';
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
  final _costController = TextEditingController();
  final _costDescController = TextEditingController();
  final _tagController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _regionSido;
  String? _regionSigungu;
  String? _regionDong;
  String? _fullAddress;
  String _placeType = 'PLAYGROUND';
  int _ageMin = 0;
  int _ageMax = 36;
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
    setState(() {
      _selectedChild = child;
      _ageMin = max(0, ageMonths - 3);
      _ageMax = min(84, ageMonths + 3);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _costController.dispose();
    _costDescController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final date = await showCupertinoDateSheet(
      context,
      initial: _selectedDate ?? now.add(const Duration(days: 1)),
      first: DateTime(now.year, now.month, now.day),
      last: now.add(const Duration(days: 60)),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _selectTime(bool isStart) async {
    if (!isStart && _startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('시작 시간을 먼저 선택해 주세요'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    final initial = isStart
        ? (_startTime ?? const TimeOfDay(hour: 14, minute: 0))
        : (_endTime ?? _addHour(_startTime!));
    final time = await showCupertinoTimeSheet(
      context,
      initial: initial,
      title: isStart ? '시작 시간' : '종료 시간',
      minimum: isStart ? null : _startTime,
    );
    if (time != null) {
      setState(() {
        if (isStart) {
          _startTime = time;
          // 시작시간이 변경되면 종료시간이 더 이른 경우 초기화
          if (_endTime != null && _toMinutes(_endTime!) <= _toMinutes(time)) {
            _endTime = null;
          }
        } else {
          _endTime = time;
        }
      });
    }
  }

  static TimeOfDay _addHour(TimeOfDay t) {
    final m = (t.hour * 60 + t.minute + 60).clamp(0, 23 * 60 + 50);
    return TimeOfDay(hour: m ~/ 60, minute: m % 60);
  }

  static int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _selectAddress() async {
    final result = await showAddressSearchSheet(context);
    if (result == null) return;
    setState(() {
      _regionSido = result.sido;
      _regionSigungu = result.sigungu;
      _regionDong = result.dong;
      _fullAddress = result.fullAddress;
    });
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
        'ageMonthMin': _ageMin,
        'ageMonthMax': _ageMax,
        'placeType': _placeType,
        if (_fullAddress != null && _fullAddress!.isNotEmpty)
          'placeAddress': _fullAddress,
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
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: '모임 만들기'),
      extendBodyBehindAppBar: true,
      body: PinkBlobsBackground(
        child: SafeArea(
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

              // Region — 주소 검색 (Daum 우편번호)
              Text('지역 / 장소 주소', style: AppTextStyles.body2Bold),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _selectAddress,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: AppColors.textHint, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _regionSido == null
                            ? Text(
                                '주소 검색',
                                style: AppTextStyles.body2.copyWith(color: AppColors.textHint),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$_regionSido $_regionSigungu $_regionDong'.trim(),
                                    style: AppTextStyles.body1Bold,
                                  ),
                                  if (_fullAddress != null && _fullAddress!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      _fullAddress!,
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
                    ],
                  ),
                ),
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
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _AgePickerCard(
                      label: '시작',
                      months: _ageMin,
                      onTap: () async {
                        final v = await showCupertinoMonthsSheet(
                          context,
                          initial: _ageMin,
                          title: '시작 개월수',
                        );
                        if (v == null) return;
                        setState(() {
                          _ageMin = v;
                          if (_ageMax < _ageMin) _ageMax = _ageMin;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.textHint),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AgePickerCard(
                      label: '끝',
                      months: _ageMax,
                      onTap: () async {
                        final v = await showCupertinoMonthsSheet(
                          context,
                          initial: _ageMax,
                          minimum: _ageMin,
                          title: '끝 개월수',
                        );
                        if (v == null) return;
                        setState(() => _ageMax = v);
                      },
                    ),
                  ),
                ],
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

class _AgePickerCard extends StatelessWidget {
  const _AgePickerCard({
    required this.label,
    required this.months,
    required this.onTap,
  });

  final String label;
  final int months;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$months개월',
                  style: AppTextStyles.body1Bold.copyWith(color: AppColors.primary),
                ),
                const Icon(Icons.unfold_more_rounded, size: 18, color: AppColors.textHint),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
