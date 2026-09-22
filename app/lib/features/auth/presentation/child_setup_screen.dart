import '../../../widgets/top_toast.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/child_traits_selector.dart';
import '../../../widgets/common_button.dart';
import '../../../widgets/common_input.dart';
import '../../../widgets/cupertino_picker_sheet.dart';
import '../../../widgets/design/avatar.dart';
import '../../../widgets/design/design_chip.dart';
import '../../../widgets/design/notebook.dart';
import '../../../widgets/picker_field.dart';
import '../providers/auth_provider.dart';

class ChildSetupScreen extends ConsumerStatefulWidget {
  const ChildSetupScreen({super.key, this.popOnDone = false});

  /// true 면 가입 흐름이 아니라 마이페이지 진입 — 추가 완료 후 pop.
  final bool popOnDone;

  @override
  ConsumerState<ChildSetupScreen> createState() => _ChildSetupScreenState();
}

class _ChildSetupScreenState extends ConsumerState<ChildSetupScreen> {
  // 이번에 추가한(아직 서버 미등록) 아이들. 빈 상태로 시작하고
  // '아이 추가' 멀티스텝을 마칠 때마다 한 명씩 채워진다.
  final List<_ChildData> _children = [];
  bool _isLoading = false;

  /// '아이 추가' → 3단계 플로우(기본정보 → 낮잠 → 인증)를 풀스크린으로 띄우고,
  /// 완료되면 결과를 목록에 추가한다.
  Future<void> _openAddFlow() async {
    final result = await Navigator.of(context).push<_ChildData>(
      MaterialPageRoute(builder: (_) => const _ChildAddFlow()),
    );
    if (result != null) setState(() => _children.add(result));
  }

  void _removeChild(int index) => setState(() => _children.removeAt(index));

  Future<void> _submit() async {
    if (_children.isEmpty) return; // 버튼 비활성 상태라 보통 도달 안 함
    setState(() => _isLoading = true);
    try {
      // 원본을 복사해 순회하되, 성공한 자녀는 즉시 _children 에서 제거한다.
      // 중간에 실패해 사용자가 재시도해도 이미 등록된 자녀가 중복 전송되지 않게.
      for (final child in [..._children]) {
        await ref.read(authProvider.notifier).addChild(
              nickname: child.nicknameController.text.trim(),
              birthYear: child.birthYear!,
              birthMonth: child.birthMonth!,
              gender: child.gender,
              photoUrl: null, // 아이 프로필 사진은 사용하지 않음
              napTime: child.napTime,
              temperamentTags: const [], // 기질은 등록 후 마이페이지에서 추가
            );
        _children.remove(child);
      }
      if (widget.popOnDone) {
        if (mounted) {
          showTopToast(context, '아이를 추가했습니다', backgroundColor: AppColors.ok);
          context.pop();
        }
      } else {
        await ref.read(authProvider.notifier).completeChildSetup();
      }
    } catch (e) {
      if (mounted) {
        showTopToast(context, '아이 정보 등록에 실패했습니다',
            backgroundColor: AppColors.bad);
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.popOnDone) {
      ref.listen<AuthState>(authProvider, (previous, next) {
        if (next.status == AuthStatus.authenticated) {
          context.go('/home');
        }
      });
    }

    final existing = widget.popOnDone
        ? (ref.watch(authProvider).user?.children ?? const [])
        : const [];
    final canSubmit = _children.isNotEmpty || existing.isNotEmpty;

    return Scaffold(
      appBar: CustomAppBar(
        title: widget.popOnDone ? '아이 추가' : '아이 정보 등록',
        showBack: widget.popOnDone,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!widget.popOnDone) ...[
                      const _StepHeader(step: 2, total: 2),
                      const SizedBox(height: 22),
                      Text('아이 정보를 알려주세요', style: AppTextStyles.display),
                      const SizedBox(height: 6),
                      Text('또래 친구를 찾기 위해 필요해요',
                          style: AppTextStyles.body2),
                      const SizedBox(height: 26),
                    ],

                    // 이미 서버에 등록된 아이 (마이페이지에서 추가 진입 시)
                    if (existing.isNotEmpty) ...[
                      Text('이미 등록된 아이', style: AppTextStyles.sectionHead),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final c in existing) _ExistingChildPill(child: c),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],

                    // 이번에 추가한 아이
                    if (_children.isNotEmpty) ...[
                      Text('추가한 아이', style: AppTextStyles.sectionHead),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final e in _children.asMap().entries)
                            _AddedChildPill(
                              data: e.value,
                              onRemove: () => _removeChild(e.key),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ＋ 아이 추가 (멀티스텝)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        height: 44,
                        child: DashedBox(
                          radius: 22,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          onTap: _openAddFlow,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add_rounded,
                                  size: 18, color: AppColors.ink2),
                              const SizedBox(width: 6),
                              Text('아이 추가하기', style: AppTextStyles.body1Bold),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 하단 — 아이가 한 명 이상일 때만 활성화.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: PrimaryButton(
                text: widget.popOnDone ? '완료' : '시작하기',
                isLoading: _isLoading,
                onPressed: canSubmit ? _submit : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 가입 온보딩 스텝 표시 — 손글씨 숫자 + 얇은 잉크 진행바.
class _StepHeader extends StatelessWidget {
  final int step;
  final int total;

  const _StepHeader({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('$step', style: AppTextStyles.handLg),
            Text(
              ' / $total',
              style: AppTextStyles.handLg.copyWith(color: AppColors.ink3),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: step / total,
            minHeight: 4,
            backgroundColor: AppColors.fill,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.ink),
          ),
        ),
      ],
    );
  }
}

/// 추가할 아이 한 명의 입력 데이터(서버 등록 전 임시 보관).
class _ChildData {
  final TextEditingController nicknameController = TextEditingController();
  int? birthYear;
  int? birthMonth;
  String? gender;
  String? napTime; // child_traits_selector NapTimeSelector key
}

/// 아이 알약 칩의 공통 껍데기 — 아바타 28 + 이름 + 개월수 + 오른쪽 액션.
class _ChildPill extends StatelessWidget {
  final String name;
  final String age;
  final String? imageUrl;
  final AvatarTone tone;
  final Widget trailing;
  final VoidCallback? onTap;

  const _ChildPill({
    required this.name,
    required this.age,
    required this.tone,
    required this.trailing,
    this.imageUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.line2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InitialAvatar(
              label: name.isNotEmpty ? name.characters.first : '아',
              size: 28,
              tone: tone,
              imageUrl: imageUrl,
            ),
            const SizedBox(width: 8),
            Text(name.isEmpty ? '아이' : name, style: AppTextStyles.body1Bold),
            if (age.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                age,
                style: AppTextStyles.handLg.copyWith(color: AppColors.skyInk),
              ),
            ],
            const SizedBox(width: 4),
            trailing,
          ],
        ),
      ),
    );
  }
}

/// 이번 화면에서 추가해 아직 서버에 보내지 않은 아이 — ✕ 로 취소.
class _AddedChildPill extends StatelessWidget {
  final _ChildData data;
  final VoidCallback onRemove;
  const _AddedChildPill({required this.data, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final name = data.nicknameController.text.trim();
    final age = (data.birthYear != null && data.birthMonth != null)
        ? AppDateUtils.formatAgeMonths(
            AppDateUtils.calculateAgeMonths(data.birthYear!, data.birthMonth!))
        : '';
    return _ChildPill(
      name: name,
      age: age,
      tone: data.gender == 'MALE' ? AvatarTone.lilac : AvatarTone.primary,
      trailing: GestureDetector(
        onTap: onRemove,
        behavior: HitTestBehavior.opaque,
        child: const Padding(
          padding: EdgeInsets.all(2),
          child: Icon(Icons.close_rounded, size: 17, color: AppColors.ink3),
        ),
      ),
    );
  }
}

/// 이미 등록된 아이 — 탭하면 수정 화면으로.
class _ExistingChildPill extends StatelessWidget {
  final dynamic child; // models/user.dart의 Child — import 순환 피하려 동적 처리.
  const _ExistingChildPill({required this.child});

  @override
  Widget build(BuildContext context) {
    final age = (child.ageMonths as int?) ??
        AppDateUtils.calculateAgeMonths(
            child.birthYear as int, child.birthMonth as int);
    return _ChildPill(
      name: child.nickname as String,
      age: AppDateUtils.formatAgeMonths(age),
      imageUrl: child.photoUrl as String?,
      tone: child.gender == 'MALE' ? AvatarTone.lilac : AvatarTone.primary,
      onTap: () => context.push('/children/${child.id}/edit'),
      trailing: const Icon(Icons.chevron_right_rounded,
          size: 18, color: AppColors.line2),
    );
  }
}

/// 아이 추가 멀티스텝 — 1) 기본정보 2) 낮잠. 완료 시 _ChildData 반환.
/// (인증 사진 단계는 온보딩 이탈 지점이라 제거 — 2026-09)
class _ChildAddFlow extends StatefulWidget {
  const _ChildAddFlow();

  @override
  State<_ChildAddFlow> createState() => _ChildAddFlowState();
}

class _ChildAddFlowState extends State<_ChildAddFlow> {
  final _data = _ChildData();
  int _step = 0; // 0: 기본정보, 1: 낮잠

  void _onNext() {
    if (_step == 0) {
      if (_data.nicknameController.text.trim().isEmpty) {
        showTopToast(context, '아이 이름을 입력해 주세요', backgroundColor: AppColors.bad);
        return;
      }
      if (_data.birthYear == null || _data.birthMonth == null) {
        showTopToast(context, '생년월을 선택해 주세요', backgroundColor: AppColors.bad);
        return;
      }
      if (_data.gender == null) {
        showTopToast(context, '성별을 선택해 주세요', backgroundColor: AppColors.bad);
        return;
      }
      setState(() => _step = 1);
    } else {
      // 낮잠은 선택사항 — 검증 없이 완료.
      Navigator.of(context).pop(_data);
    }
  }

  void _onBack() {
    if (_step > 0) {
      setState(() => _step -= 1);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        titleWidget: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('아이 추가 ', style: AppTextStyles.screenTitle),
            Text(
              '${_step + 1}/2',
              style: AppTextStyles.handLg.copyWith(color: AppColors.ink2),
            ),
          ],
        ),
        onBack: _onBack,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: _step == 0
                    ? _StepBasic(data: _data, onChanged: () => setState(() {}))
                    : _StepNap(data: _data, onChanged: () => setState(() {})),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: PrimaryButton(
                text: _step < 1 ? '다음' : '완료',
                onPressed: _onNext,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 1단계 — 이름 / 성별 / 생년월.
class _StepBasic extends StatelessWidget {
  final _ChildData data;
  final VoidCallback onChanged;
  const _StepBasic({required this.data, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('아이의 기본 정보', style: AppTextStyles.display),
        const SizedBox(height: 6),
        Text('이름·성별·생년월을 알려주세요', style: AppTextStyles.body2),
        const SizedBox(height: 28),

        CommonInput(
          label: '아이 이름',
          hint: '아이 이름',
          controller: data.nicknameController,
          maxLength: 10,
        ),
        const SizedBox(height: 16),

        Text('성별', style: AppTextStyles.body2Bold),
        const SizedBox(height: 8),
        Row(
          children: [
            FilterChipButton(
              label: '남아',
              selected: data.gender == 'MALE',
              onTap: () {
                data.gender = data.gender == 'MALE' ? null : 'MALE';
                onChanged();
              },
            ),
            const SizedBox(width: 8),
            FilterChipButton(
              label: '여아',
              selected: data.gender == 'FEMALE',
              onTap: () {
                data.gender = data.gender == 'FEMALE' ? null : 'FEMALE';
                onChanged();
              },
            ),
          ],
        ),
        const SizedBox(height: 20),

        Text('생년월', style: AppTextStyles.body2Bold),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: PickerField(
                label: '연도',
                value: data.birthYear != null ? '${data.birthYear}년' : null,
                hint: '연도 선택',
                onTap: () async {
                  final years = List.generate(8, (i) => currentYear - i);
                  final v = await showWheelSheet<int>(
                    context,
                    title: '연도 선택',
                    options: years,
                    initial: data.birthYear ?? years.first,
                    format: (y) => '$y년',
                  );
                  if (v == null) return;
                  data.birthYear = v;
                  onChanged();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PickerField(
                label: '월',
                value: data.birthMonth != null ? '${data.birthMonth}월' : null,
                hint: '월 선택',
                onTap: () async {
                  final months = List.generate(12, (i) => i + 1);
                  final v = await showWheelSheet<int>(
                    context,
                    title: '월 선택',
                    options: months,
                    initial: data.birthMonth ?? 1,
                    format: (m) => '$m월',
                  );
                  if (v == null) return;
                  data.birthMonth = v;
                  onChanged();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 2단계 — 낮잠 성향(선택).
class _StepNap extends StatelessWidget {
  final _ChildData data;
  final VoidCallback onChanged;
  const _StepNap({required this.data, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('낮잠 성향', style: AppTextStyles.display),
        const SizedBox(height: 6),
        Text('비슷한 생활 패턴의 또래를 찾는 데 써요 (선택)',
            style: AppTextStyles.body2),
        const SizedBox(height: 28),
        NapTimeSelector(
          selectedKey: data.napTime,
          onChanged: (key) {
            data.napTime = key;
            onChanged();
          },
        ),
      ],
    );
  }
}
