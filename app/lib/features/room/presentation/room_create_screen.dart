import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_error.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/validators.dart';
import '../../../models/room.dart';
import '../../../models/user.dart';
import '../../../providers/selected_child_provider.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/common_button.dart';
import '../../../widgets/common_input.dart';
import '../../../widgets/address_search_sheet.dart';
import '../../../widgets/cupertino_picker_sheet.dart';
import '../../../widgets/location_picker_sheet.dart';
import '../../../widgets/top_toast.dart';
import '../../../widgets/design/design_chip.dart';
import '../../../widgets/design/notebook.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/providers/dashboard_provider.dart';
import '../providers/room_detail_provider.dart';
import 'widgets/required_items_picker.dart';

class RoomCreateScreen extends ConsumerStatefulWidget {
  /// 값이 있으면 수정 모드 — 기존 방 값을 채우고 저장 시 PATCH.
  final Room? editRoom;
  const RoomCreateScreen({super.key, this.editRoom});

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
  double? _latitude;
  double? _longitude;
  String _placeType = 'PLAYGROUND';
  int _ageMin = 0;
  int _ageMax = 36;
  int _maxMembers = 5;
  String _joinType = 'FREE';
  int _step = 0; // 멀티스텝 현재 단계 (0~3)
  bool _isFree = true;
  final List<String> _tags = [];
  bool _isLoading = false;
  Child? _selectedChild;

  // 신규 카테고리/준비물
  String _genderFilter = 'ALL'; // 'ALL' | 'MOM_ONLY' | 'DAD_ONLY'
  bool _singleParentOnly = false;
  bool _parentAgeMatch = false;
  static const bool _showParentAgeMatch = false;
  final List<String> _requiredItems = [];

  @override
  void initState() {
    super.initState();
    final r = widget.editRoom;
    if (r != null) {
      _prefillFromRoom(r);
      return;
    }
    // 글로벌 선택된 아이로 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final child = ref.read(selectedChildProvider);
      if (child != null) {
        _applyChildAgeRange(child);
      }
    });
  }

  /// 수정 모드 — 기존 방 값으로 폼을 채운다.
  void _prefillFromRoom(Room r) {
    _titleController.text = r.title;
    _descriptionController.text = r.description ?? '';
    _selectedDate = DateTime.tryParse(r.date);
    _startTime = _parseTime(r.startTime);
    _endTime = r.endTime != null ? _parseTime(r.endTime!) : null;
    _regionSido = r.regionSido;
    _regionSigungu = r.regionSigungu;
    _regionDong = r.regionDong;
    _fullAddress = r.placeAddress;
    _latitude = r.latitude;
    _longitude = r.longitude;
    _placeType = r.placeType;
    _ageMin = r.ageMonthMin;
    _ageMax = r.ageMonthMax;
    _maxMembers = r.maxMembers;
    _joinType = r.joinType;
    _isFree = r.cost == 0;
    if (r.cost > 0) _costController.text = r.cost.toString();
    _costDescController.text = r.costDescription ?? '';
    _genderFilter = r.genderFilter;
    _singleParentOnly = r.singleParentOnly;
    _parentAgeMatch = r.parentAgeMatch;
    _tags.addAll(r.tags);
    _requiredItems.addAll(r.requiredItems);
  }

  static TimeOfDay? _parseTime(String s) {
    final parts = s.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  /// 최대 인원 하한 — 수정 모드에선 이미 참여 중인 인원 아래로 줄일 수 없다(서버가 400).
  int get _minMembers => max(2, widget.editRoom?.currentMembers ?? 2);

  /// 선택된 아이의 개월수 기준으로 범위 자동 설정 (±6개월)
  void _applyChildAgeRange(Child child) {
    final ageMonths = AppDateUtils.calculateAgeMonths(child.birthYear, child.birthMonth);
    setState(() {
      _selectedChild = child;
      _ageMin = max(0, ageMonths - 6);
      _ageMax = min(84, ageMonths + 6);
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
    if (date != null) {
      setState(() {
        _selectedDate = date;
        // 오늘로 바뀌었는데 이미 고른 시작시간이 과거면 초기화 — 다시 고르게.
        if (_startTime != null && _isToday(date) && _isPastTime(_startTime!)) {
          _startTime = null;
          _endTime = null;
        }
      });
    }
  }

  Future<void> _selectTime(bool isStart) async {
    if (!isStart && _startTime == null) {
      showTopToast(context, '시작 시간을 먼저 선택해 주세요');
      return;
    }
    final initial = isStart
        ? (_startTime ?? const TimeOfDay(hour: 14, minute: 0))
        : (_endTime ?? _addHour(_startTime!));

    // 오늘 모임이면 시작 시간은 현재 시각 이후만 선택 가능.
    TimeOfDay? minStart;
    if (isStart && _selectedDate != null && _isToday(_selectedDate!)) {
      final now = DateTime.now();
      minStart = TimeOfDay(hour: now.hour, minute: now.minute);
    }

    final time = await showCupertinoTimeSheet(
      context,
      initial: initial,
      title: isStart ? '시작 시간' : '종료 시간',
      minimum: isStart ? minStart : _startTime,
    );
    if (time != null) {
      // 피커가 minimum 을 무시할 가능성 대비 — 오늘 과거시간이면 거부.
      if (isStart &&
          minStart != null &&
          _toMinutes(time) < _toMinutes(minStart)) {
        if (!mounted) return;
        showTopToast(context, '지난 시간은 선택할 수 없어요');
        return;
      }
      var clearedEnd = false;
      setState(() {
        if (isStart) {
          _startTime = time;
          // 시작시간이 변경되면 종료시간이 더 이른 경우 초기화
          if (_endTime != null && _toMinutes(_endTime!) <= _toMinutes(time)) {
            _endTime = null;
            clearedEnd = true;
          }
        } else {
          _endTime = time;
        }
      });
      // 조용히 지우면 안 된다 — 수정 모드는 비운 종료 시간을 그대로 저장한다.
      if (clearedEnd && mounted) {
        showTopToast(context, '시작 시간이 바뀌어 종료 시간을 다시 선택해 주세요');
      }
    }
  }

  static bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  bool _isPastTime(TimeOfDay t) {
    final n = DateTime.now();
    return _toMinutes(t) < n.hour * 60 + n.minute;
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
      _latitude = null;
      _longitude = null;
    });
    // 모임이 지도에 핀으로 찍히도록 좌표를 미리 확보한다 (도로명 우선).
    final query = result.roadAddress.isNotEmpty
        ? result.roadAddress
        : result.jibunAddress;
    double? lat;
    double? lng;
    if (query.isNotEmpty) {
      try {
        final geo = await ref.read(roomRepositoryProvider).geocode(query);
        lat = geo.lat;
        lng = geo.lng;
      } catch (_) {
        // 지오코딩 실패해도 방 생성은 진행 — 서버가 placeAddress 로 재시도.
      }
    }
    if (!mounted) return;
    // 지도에서 정확한 위치로 핀 보정 — 좌표가 없으면 서울시청을 기본 중심.
    final picked = await showLocationPickerSheet(
      context,
      initialLat: lat ?? 37.5665,
      initialLng: lng ?? 126.978,
      title: '정확한 위치 지정',
      label: result.fullAddress,
    );
    if (!mounted) return;
    setState(() {
      if (picked != null) {
        _latitude = picked.lat;
        _longitude = picked.lng;
        if (picked.label.isNotEmpty && picked.label != result.fullAddress) {
          _fullAddress = picked.label;
        }
      } else if (lat != null && lng != null) {
        // 사용자가 보정 취소 — 지오코딩 좌표라도 살림.
        _latitude = lat;
        _longitude = lng;
      }
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
        Text('어떤 아이의 모임인가요?', style: AppTextStyles.captionBold),
        const SizedBox(height: 4),
        Text(
          '아이를 선택하면 개월수 범위가 자동 설정됩니다',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: children.map((child) {
            final ageMonths = AppDateUtils.calculateAgeMonths(
                child.birthYear, child.birthMonth);
            return FilterChipButton(
              label:
                  '${child.nickname} ${AppDateUtils.formatAgeMonths(ageMonths)}',
              selected: _selectedChild?.id == child.id,
              onTap: () => _applyChildAgeRange(child),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCategorySection() {
    final me = ref.watch(authProvider).user;
    final canSingleParent = me?.isSingleParent == true;
    final canParentAge = me?.isPhoneVerified == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('참여 성별', style: AppTextStyles.captionBold),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChipButton(
              label: '전체',
              selected: _genderFilter == 'ALL',
              onTap: () => setState(() => _genderFilter = 'ALL'),
            ),
            // 본인 성별과 반대 옵션은 숨김 — 아빠는 '엄마만', 엄마는 '아빠만' 선택 불가.
            if (me?.parentGender != 'DAD')
              FilterChipButton(
                label: '엄마만',
                selected: _genderFilter == 'MOM_ONLY',
                onTap: () => setState(() => _genderFilter = 'MOM_ONLY'),
              ),
            if (me?.parentGender != 'MOM')
              FilterChipButton(
                label: '아빠만',
                selected: _genderFilter == 'DAD_ONLY',
                onTap: () => setState(() => _genderFilter = 'DAD_ONLY'),
              ),
          ],
        ),
        // 한부모 전용 방 옵션 — 한부모 가정 계정에만 노출.
        if (canSingleParent) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                // 방장 성별과 무관하게 한부모 전체가 대상이다.
                child: Text('싱글맘·싱글대디만 참여', style: AppTextStyles.body1),
              ),
              Switch(
                value: _singleParentOnly,
                activeTrackColor: AppColors.ink,
                onChanged: (v) => setState(() => _singleParentOnly = v),
              ),
            ],
          ),
        ],
        // 부모 또래 전용 방 옵션 — 2026-09 일단 숨김(로직·필드는 유지). 다시 켜려면 플래그만.
        if (_showParentAgeMatch && canParentAge) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text('부모 또래만 참여 (±5세)', style: AppTextStyles.body1),
              ),
              Switch(
                value: _parentAgeMatch,
                activeTrackColor: AppColors.ink,
                onChanged: (v) => setState(() => _parentAgeMatch = v),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// 수정 모드 — 서버 UpdateRoomDto 가 받는 필드만 단일 스크롤 폼으로 보여준다.
  Widget _buildEditForm() {
    // ListView 는 화면 밖 필드를 언마운트해 Form.validate 가 건너뛴다 —
    // 폼이 짧으니 전부 살려두는 SingleChildScrollView 를 쓴다.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildEditNotice(),
          const SizedBox(height: 20),
          _buildTitleField(),
          const SizedBox(height: 20),
          _buildDescriptionField(),
          const SizedBox(height: 20),
          _buildTimeSection(),
          const SizedBox(height: 20),
          _buildMaxMembersSection(),
          const SizedBox(height: 20),
          _buildCostSection(),
          const SizedBox(height: 20),
          _buildTagsSection(),
        ],
      ),
    );
  }

  /// 수정할 수 없는 항목 안내 — 날짜·장소·모집 조건은 서버가 받지 않는다.
  Widget _buildEditNotice() {
    return DashedBox(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.ink3),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '날짜·지역·대상 개월수·참여 조건·준비물·입장 방식은 수정할 수 없어요.\n제목·설명·시간·최대 인원·비용·태그만 바꿀 수 있어요.',
              style: AppTextStyles.caption,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField() {
    return CommonInput(
      key: const Key('input-room-title'),
      label: '제목 (5자 이상)',
      hint: '모임 제목을 입력하세요',
      controller: _titleController,
      validator: Validators.roomTitle,
      maxLength: 30,
    );
  }

  Widget _buildDescriptionField() {
    return CommonInput(
      key: const Key('input-room-description'),
      label: '설명 (선택)',
      hint: '어떤 모임인지 적어 주세요',
      controller: _descriptionController,
      validator: Validators.roomDescription,
      maxLines: 4,
      maxLength: 500,
    );
  }

  Widget _buildTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('시간', style: AppTextStyles.captionBold),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _TimePickerCard(
                key: const Key('btn-room-start-time'),
                label: '시작',
                time: _startTime,
                placeholder: '시작 시간',
                onTap: () => _selectTime(true),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded,
                size: 18, color: AppColors.ink3),
            const SizedBox(width: 8),
            Expanded(
              child: _TimePickerCard(
                label: '종료 (선택)',
                time: _endTime,
                placeholder: '종료 시간',
                onTap: () => _selectTime(false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMaxMembersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('최대 인원', style: AppTextStyles.captionBold),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              onPressed: _maxMembers > _minMembers
                  ? () => setState(() => _maxMembers--)
                  : null,
              icon: const Icon(Icons.remove_circle_outline_rounded),
              color: AppColors.ink,
              disabledColor: AppColors.ink3,
            ),
            SizedBox(
              width: 64,
              child: Center(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$_maxMembers',
                        style: AppTextStyles.handLg,
                      ),
                      TextSpan(text: '명', style: AppTextStyles.body1),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: _maxMembers < 10
                  ? () => setState(() => _maxMembers++)
                  : null,
              icon: const Icon(Icons.add_circle_outline_rounded),
              color: AppColors.ink,
              disabledColor: AppColors.ink3,
            ),
          ],
        ),
        // 이미 참여 중인 인원 아래로는 줄일 수 없다 — 서버가 400 을 준다.
        if (_maxMembers <= _minMembers && _minMembers > 2) ...[
          const SizedBox(height: 4),
          Text(
            '이미 $_minMembers명이 참여 중이라 더 줄일 수 없어요',
            style: AppTextStyles.caption,
          ),
        ],
      ],
    );
  }

  Widget _buildCostSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('비용', style: AppTextStyles.captionBold),
            const Spacer(),
            Text('무료', style: AppTextStyles.body2),
            Switch(
              value: _isFree,
              activeTrackColor: AppColors.ink,
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
      ],
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('태그 (최대 5개)', style: AppTextStyles.captionBold),
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
              icon: const Icon(Icons.add_circle_rounded, color: AppColors.ink),
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
                      deleteIconColor: AppColors.ink3,
                      backgroundColor: AppColors.fill,
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                      onDeleted: () => setState(() => _tags.remove(tag)),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  /// 다음 단계로 — 단계별 필수 입력을 검증한 뒤 넘어간다.
  /// 단계별 필수 입력 검사. 문제가 있으면 사유를 돌려준다(없으면 null).
  /// '다음'과 최종 제출이 같은 규칙을 쓴다 — 어느 단계든 조건을 못 채우면 넘어가지 못한다.
  String? _stepProblem(int step) {
    switch (step) {
      case 0:
        return _basicInfoProblem();
      case 1:
        if (_selectedDate == null) return '날짜를 선택해 주세요';
        if (_startTime == null) return '시작 시간을 선택해 주세요';
        if (_endTime != null) {
          final s = _startTime!.hour * 60 + _startTime!.minute;
          final e = _endTime!.hour * 60 + _endTime!.minute;
          if (e <= s) return '종료 시간은 시작 시간보다 늦어야 해요';
        }
        if (widget.editRoom == null &&
            (_regionSido == null || _regionSigungu == null || _regionDong == null)) {
          return '장소를 선택해 주세요';
        }
        return null;
      case 2:
        if (_ageMin > _ageMax) return '개월수 범위를 다시 확인해 주세요';
        if (_maxMembers < 2) return '모집 인원은 2명 이상이어야 해요';
        return null;
      case 3:
        if (!_isFree) {
          final cost = int.tryParse(_costController.text.trim());
          if (cost == null || cost <= 0) return '비용을 입력해 주세요';
        }
        return null;
      default:
        return null;
    }
  }

  /// 다음 단계로 — 이 단계의 필수 입력을 못 채우면 넘어가지 않는다.
  void _onNext() {
    final problem = _stepProblem(_step);
    if (problem != null) {
      showTopToast(context, problem, backgroundColor: AppColors.error);
      return;
    }
    setState(() => _step++);
  }

  /// 1단계 필수 입력(제목·설명) 문제. 없으면 null.
  String? _basicInfoProblem() {
    return Validators.roomTitle(_titleController.text) ??
        Validators.roomDescription(_descriptionController.text);
  }

  Future<void> _submit() async {
    // 모든 단계를 다시 훑어 첫 문제를 찾고, 그 단계로 데려간다 — 마지막 화면에서
    // 버튼이 말없이 안 눌리는 일이 없게.
    for (var step = 0; step < 4; step++) {
      final problem = _stepProblem(step);
      if (problem != null) {
        showTopToast(context, problem, backgroundColor: AppColors.error);
        if (widget.editRoom == null && _step != step) {
          setState(() => _step = step);
        }
        return;
      }
    }
    if (!_formKey.currentState!.validate()) {
      showTopToast(context, '입력 내용을 다시 확인해 주세요', backgroundColor: AppColors.error);
      if (widget.editRoom == null && _step != 0) setState(() => _step = 0);
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
        if (_latitude != null) 'latitude': _latitude,
        if (_longitude != null) 'longitude': _longitude,
        'maxMembers': _maxMembers,
        'joinType': _joinType,
        'cost': _isFree ? 0 : int.tryParse(_costController.text) ?? 0,
        'costDescription':
            _costDescController.text.isNotEmpty ? _costDescController.text.trim() : null,
        'tags': _tags,
        'genderFilter': _genderFilter,
        'singleParentOnly': _singleParentOnly,
        'parentAgeMatch': _parentAgeMatch,
        'requiredItems': _requiredItems,
      };

      final editRoom = widget.editRoom;
      if (editRoom != null) {
        // 수정 — 서버 UpdateRoomDto 허용 필드만 전송.
        await ref.read(roomRepositoryProvider).updateRoom(editRoom.id, {
          'title': roomData['title'],
          'description': roomData['description'],
          'startTime': roomData['startTime'],
          // 종료 시간을 비웠으면 null 로 지운다 — 생략하면 서버가 옛 값을 그대로 둔다.
          'endTime': roomData['endTime'],
          if (roomData['placeAddress'] != null)
            'placeAddress': roomData['placeAddress'],
          'maxMembers': roomData['maxMembers'],
          'cost': roomData['cost'],
          'costDescription': roomData['costDescription'],
          'tags': roomData['tags'],
        });
        if (mounted) {
          // invalidate 하면 상태만 비고 재조회하는 곳이 없어 상세가 빈 로딩
          // 화면에 갇힌다 — 수정 결과가 바로 보이도록 직접 다시 불러온다.
          ref.read(roomDetailProvider(editRoom.id).notifier).loadRoom();
          ref.invalidate(joinedRoomsProvider);
          context.pop();
        }
      } else {
        final room =
            await ref.read(roomRepositoryProvider).createRoom(roomData);
        // 새 방 생성 즉시 홈의 참여 모임 목록을 갱신(빈 상태 → 내 방 표시).
        ref.invalidate(joinedRoomsProvider);
        if (mounted) {
          context.pop();
          context.push('/rooms/${room.id}');
        }
      }
    } catch (e) {
      if (mounted) {
        showTopToast(
          context,
          apiErrorMessage(e,
              fallback: widget.editRoom != null
                  ? '수정에 실패했습니다'
                  : '방 생성에 실패했습니다'),
          backgroundColor: AppColors.error,
        );
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editRoom != null;
    // 수정 모드는 단일 폼이라 항상 마지막 단계처럼 동작한다('수정 완료' 버튼 하나).
    final isLast = isEdit || _step == 3;
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: CustomAppBar(
          title: widget.editRoom != null
              ? '모임 수정'
              : '모임 만들기 (${_step + 1}/4)'),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (!isEdit) _StepIndicator(step: _step, total: 4),
              Expanded(
                child: isEdit
                    ? _buildEditForm()
                    : IndexedStack(
                  index: _step,
                  children: [
                    // ── 1단계: 기본 정보 ──
                    ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
              // 아이 선택
              _buildChildSelector(),
              const SizedBox(height: 20),

              // Gender filter / single-parent / category preview
              _buildCategorySection(),
              const SizedBox(height: 20),

              // Title
              _buildTitleField(),
              const SizedBox(height: 20),

              // Description
              _buildDescriptionField(),
                      ],
                    ),
                    // ── 2단계: 일시·장소 ──
                    ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
              // Date
              Text('날짜', style: AppTextStyles.captionBold),
              const SizedBox(height: 8),
              GestureDetector(
                key: const Key('btn-room-date'),
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 18, color: AppColors.ink3),
                      const SizedBox(width: 8),
                      Text(
                        _selectedDate != null
                            ? DateFormat('yyyy년 M월 d일 (E)', 'ko')
                                .format(_selectedDate!)
                            : '날짜를 선택하세요',
                        style: AppTextStyles.body1.copyWith(
                          color: _selectedDate != null
                              ? AppColors.ink
                              : AppColors.ink3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Time
              _buildTimeSection(),
              const SizedBox(height: 20),

              // Region — 주소 검색 (Daum 우편번호)
              Text('지역 / 장소', style: AppTextStyles.captionBold),
              const SizedBox(height: 8),
              GestureDetector(
                key: const Key('btn-room-address'),
                onTap: _selectAddress,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: AppColors.ink3, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _regionSido == null
                            ? Text('주소 검색', style: AppTextStyles.body1
                                .copyWith(color: AppColors.ink3))
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$_regionSido $_regionSigungu $_regionDong'.trim(),
                                    style: AppTextStyles.body1Bold,
                                  ),
                                  if (_fullAddress != null && _fullAddress!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(_fullAddress!, style: AppTextStyles.caption),
                                  ],
                                ],
                              ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.line2),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Place Type
              Text('장소 유형', style: AppTextStyles.captionBold),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppConstants.placeTypes.entries
                    .map((e) => FilterChipButton(
                          label: e.value,
                          selected: _placeType == e.key,
                          onTap: () => setState(() => _placeType = e.key),
                        ))
                    .toList(),
              ),
                      ],
                    ),
                    // ── 3단계: 모집 조건 ──
                    ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
              // Age range
              Row(
                children: [
                  Text('대상 개월수', style: AppTextStyles.captionBold),
                  if (_selectedChild != null) ...[
                    const SizedBox(width: 8),
                    Pill(
                      label: '${_selectedChild!.nickname} 기준',
                      tone: PillTone.sky,
                      height: 20,
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
                  const Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.ink3),
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
              _buildMaxMembersSection(),
              const SizedBox(height: 20),

              // Join type — 생성 시에만 선택. 수정 시엔 변경 불가라 숨긴다.
              if (widget.editRoom == null) ...[
                Text('입장 방식', style: AppTextStyles.captionBold),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChipButton(
                      label: '자유 입장',
                      selected: _joinType == 'FREE',
                      onTap: () => setState(() => _joinType = 'FREE'),
                    ),
                    FilterChipButton(
                      label: '승인 필요',
                      selected: _joinType == 'APPROVAL',
                      onTap: () => setState(() => _joinType = 'APPROVAL'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _joinType == 'FREE' ? '누구나 바로 참여할 수 있어요' : '방장이 수락해야 참여할 수 있어요',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 20),
              ],
                      ],
                    ),
                    // ── 4단계: 추가 정보 ──
                    ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
              // Cost
              _buildCostSection(),
              const SizedBox(height: 20),

              // Required items
              RequiredItemsPicker(
                value: _requiredItems,
                onChanged: (next) => setState(() {
                  _requiredItems
                    ..clear()
                    ..addAll(next);
                }),
              ),
              const SizedBox(height: 20),

              // Tags
              _buildTagsSection(),
                      ],
                    ),
                  ],
                ),
              ),
              // 하단 — 이전 / 다음 / 완료
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Row(
                  children: [
                    if (_step > 0) ...[
                      Expanded(
                        child: SecondaryButton(
                          text: '이전',
                          onPressed: () => setState(() => _step--),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: _step > 0 ? 2 : 1,
                      child: PrimaryButton(
                        key: const Key('btn-room-create-submit'),
                        text: isLast
                            ? (widget.editRoom != null ? '수정 완료' : '모임 만들기')
                            : '다음',
                        isLoading: _isLoading,
                        onPressed: isLast ? _submit : _onNext,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 스텝 표시 — 손글씨 "1/4" + 얇은 진행바. (docs/09_UI_수첩안.md)
class _StepIndicator extends StatelessWidget {
  final int step;
  final int total;

  const _StepIndicator({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${step + 1}', style: AppTextStyles.handLg),
                TextSpan(
                  text: '/$total',
                  style: AppTextStyles.handLg.copyWith(color: AppColors.ink3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (step + 1) / total,
              minHeight: 4,
              backgroundColor: AppColors.fill,
              valueColor: const AlwaysStoppedAnimation(AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimePickerCard extends StatelessWidget {
  const _TimePickerCard({
    super.key,
    required this.label,
    required this.time,
    required this.placeholder,
    required this.onTap,
  });

  final String label;
  final TimeOfDay? time;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = time != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.caption),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    hasValue ? time!.format(context) : placeholder,
                    style: AppTextStyles.body1Bold.copyWith(
                      color: hasValue ? AppColors.ink : AppColors.ink3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.access_time_rounded,
                  size: 18,
                  color: hasValue ? AppColors.ink : AppColors.ink3,
                ),
              ],
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
          border: Border.all(color: AppColors.line2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.caption),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '$months', style: AppTextStyles.handLg),
                      TextSpan(text: '개월', style: AppTextStyles.body1),
                    ],
                  ),
                ),
                const Icon(Icons.unfold_more_rounded, size: 18, color: AppColors.ink3),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
