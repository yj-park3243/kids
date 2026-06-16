import '../../../widgets/top_toast.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/child_traits_selector.dart';
import '../../../widgets/common_button.dart';
import '../../../widgets/common_input.dart';
import '../../../widgets/cupertino_picker_sheet.dart';
import '../../../widgets/design/avatar.dart';
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
      for (final child in _children) {
        final repo = ref.read(authRepositoryProvider);
        final verificationUrl =
            await repo.uploadImage(child.verificationPhotoPath!);
        await ref.read(authProvider.notifier).addChild(
              nickname: child.nicknameController.text.trim(),
              birthYear: child.birthYear!,
              birthMonth: child.birthMonth!,
              gender: child.gender,
              photoUrl: null, // 아이 프로필 사진은 사용하지 않음
              verificationPhotoUrl: verificationUrl,
              napTime: child.napTime,
              temperamentTags: const [], // 기질은 등록 후 마이페이지에서 추가
            );
      }
      if (widget.popOnDone) {
        if (mounted) {
          showTopToast(context, '아이를 추가했습니다');
          context.pop();
        }
      } else {
        await ref.read(authProvider.notifier).completeChildSetup();
      }
    } catch (e) {
      if (mounted) {
        showTopToast(context, '아이 정보 등록에 실패했습니다',
            backgroundColor: AppColors.error);
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
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: widget.popOnDone ? '아이 추가' : '아이 정보 등록',
        showBack: widget.popOnDone,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!widget.popOnDone) ...[
                      Text('아이 정보를 알려주세요', style: AppTextStyles.heading2),
                      const SizedBox(height: 8),
                      Text(
                        '또래 친구를 찾기 위해 필요해요',
                        style: AppTextStyles.body2
                            .copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // 이미 서버에 등록된 아이 (마이페이지에서 추가 진입 시)
                    if (existing.isNotEmpty) ...[
                      Text('이미 등록된 아이', style: AppTextStyles.heading2),
                      const SizedBox(height: 12),
                      ...existing.map((c) => _ExistingChildTile(child: c)),
                      const SizedBox(height: 24),
                    ],

                    // 이번에 추가한 아이 (간단 카드)
                    if (_children.isNotEmpty) ...[
                      Text('추가한 아이', style: AppTextStyles.heading2),
                      const SizedBox(height: 12),
                      ..._children.asMap().entries.map(
                            (e) => _AddedChildTile(
                              data: e.value,
                              onRemove: () => _removeChild(e.key),
                            ),
                          ),
                      const SizedBox(height: 12),
                    ],

                    // + 아이 추가 (멀티스텝)
                    GestureDetector(
                      onTap: _openAddFlow,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_circle_outline_rounded,
                                color: AppColors.primary.withValues(alpha: 0.7)),
                            const SizedBox(width: 8),
                            Text(
                              '아이 추가',
                              style: AppTextStyles.body1.copyWith(
                                color: AppColors.primary.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 하단 — 아이가 한 명 이상일 때만 활성화.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: PrimaryButton(
                text: widget.popOnDone ? '완료' : '다음',
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

/// 추가할 아이 한 명의 입력 데이터(서버 등록 전 임시 보관).
class _ChildData {
  final TextEditingController nicknameController = TextEditingController();
  int? birthYear;
  int? birthMonth;
  String? gender;
  String? napTime; // child_traits_selector NapTimeSelector key
  String? verificationPhotoPath; // 인증 사진(출생증명서/키즈노트 등), 어드민 검수용
}

/// 추가 완료된 아이를 메인 목록에 보여주는 간단 카드.
class _AddedChildTile extends StatelessWidget {
  final _ChildData data;
  final VoidCallback onRemove;
  const _AddedChildTile({required this.data, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final name = data.nicknameController.text.trim();
    final age = (data.birthYear != null && data.birthMonth != null)
        ? AppDateUtils.formatAgeMonths(
            AppDateUtils.calculateAgeMonths(data.birthYear!, data.birthMonth!))
        : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          InitialAvatar(
            label: name.isNotEmpty ? name.substring(0, 1) : '아',
            size: 36,
            tone:
                data.gender == 'MALE' ? AvatarTone.lilac : AvatarTone.primary,
          ),
          const SizedBox(width: 12),
          Text(name.isEmpty ? '아이' : name, style: AppTextStyles.body1Bold),
          if (age.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(age,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.primary700)),
          ],
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            color: AppColors.textHint,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// 아이 추가 멀티스텝 — 1) 기본정보 2) 낮잠 3) 인증사진. 완료 시 _ChildData 반환.
class _ChildAddFlow extends StatefulWidget {
  const _ChildAddFlow();

  @override
  State<_ChildAddFlow> createState() => _ChildAddFlowState();
}

class _ChildAddFlowState extends State<_ChildAddFlow> {
  final _data = _ChildData();
  int _step = 0; // 0: 기본정보, 1: 낮잠, 2: 인증

  Future<void> _pickVerification() async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      imageQuality: 85,
    );
    if (img != null) setState(() => _data.verificationPhotoPath = img.path);
  }

  void _onNext() {
    if (_step == 0) {
      if (_data.nicknameController.text.trim().isEmpty) {
        showTopToast(context, '아이 이름을 입력해 주세요',
            backgroundColor: AppColors.error);
        return;
      }
      if (_data.birthYear == null || _data.birthMonth == null) {
        showTopToast(context, '생년월을 선택해 주세요', backgroundColor: AppColors.error);
        return;
      }
      if (_data.gender == null) {
        showTopToast(context, '성별을 선택해 주세요', backgroundColor: AppColors.error);
        return;
      }
      setState(() => _step = 1);
    } else if (_step == 1) {
      // 낮잠은 선택사항 — 검증 없이 다음.
      setState(() => _step = 2);
    } else {
      if (_data.verificationPhotoPath == null) {
        showTopToast(context, '인증 사진을 등록해 주세요',
            backgroundColor: AppColors.error);
        return;
      }
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
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: '아이 추가 (${_step + 1}/3)',
        onBack: _onBack,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: switch (_step) {
                  0 => _StepBasic(data: _data, onChanged: () => setState(() {})),
                  1 => _StepNap(data: _data, onChanged: () => setState(() {})),
                  _ => _StepVerification(
                      data: _data, onPick: _pickVerification),
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: PrimaryButton(
                text: _step < 2 ? '다음' : '완료',
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
        Text('아이의 기본 정보', style: AppTextStyles.heading2),
        const SizedBox(height: 6),
        Text('이름·성별·생년월을 알려주세요',
            style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 24),

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
            _GenderChip(
              label: '남아',
              emoji: '👦',
              accent: AppColors.accentSky,
              isSelected: data.gender == 'MALE',
              onTap: () {
                data.gender = data.gender == 'MALE' ? null : 'MALE';
                onChanged();
              },
            ),
            const SizedBox(width: 8),
            _GenderChip(
              label: '여아',
              emoji: '👧',
              accent: AppColors.primary,
              isSelected: data.gender == 'FEMALE',
              onTap: () {
                data.gender = data.gender == 'FEMALE' ? null : 'FEMALE';
                onChanged();
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

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
        Text('낮잠 성향', style: AppTextStyles.heading2),
        const SizedBox(height: 6),
        Text('비슷한 생활 패턴의 또래를 찾는 데 써요 (선택)',
            style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 24),
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

/// 3단계 — 인증 사진(어드민 검수용, 비공개).
class _StepVerification extends StatelessWidget {
  final _ChildData data;
  final VoidCallback onPick;
  const _StepVerification({required this.data, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('인증 사진', style: AppTextStyles.heading2),
        const SizedBox(height: 6),
        Text(
          '운영자만 확인합니다. 아래 중 하나를 올려주세요.\n'
          '• 출생증명서\n'
          '• 키즈노트 아이 정보 화면 캡쳐 (아이 이름·생년월 + 사진)\n'
          '• 기타 자녀임을 확인할 수 있는 공식 서류',
          style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
        ),
        const SizedBox(height: 8),
        Text(
          '🔒 다른 사용자에게는 절대 노출되지 않아요.',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.error,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        _PhotoSlot(
          path: data.verificationPhotoPath,
          onTap: onPick,
          placeholderIcon: Icons.verified_user_outlined,
          placeholderLabel: '인증 사진 등록',
        ),
      ],
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  final String? path;
  final VoidCallback onTap;
  final IconData placeholderIcon;
  final String placeholderLabel;

  const _PhotoSlot({
    required this.path,
    required this.onTap,
    required this.placeholderIcon,
    required this.placeholderLabel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 130,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
          image: path != null
              ? DecorationImage(
                  image: FileImage(File(path!)),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: path != null
            ? null
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(placeholderIcon, color: AppColors.textHint, size: 28),
                  const SizedBox(height: 6),
                  Text(placeholderLabel,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textHint)),
                ],
              ),
      ),
    );
  }
}

/// 이미 등록된 아이를 보여주는 작은 타일 — 탭/톱니바퀴로 수정 화면 진입.
class _ExistingChildTile extends StatelessWidget {
  final dynamic child; // models/user.dart의 Child — import 순환 피하려 동적 처리.
  const _ExistingChildTile({required this.child});

  @override
  Widget build(BuildContext context) {
    final age = (child.ageMonths as int?) ??
        AppDateUtils.calculateAgeMonths(
            child.birthYear as int, child.birthMonth as int);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/children/${child.id}/edit'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            InitialAvatar(
              label: (child.nickname as String).isNotEmpty
                  ? (child.nickname as String).substring(0, 1)
                  : '아',
              size: 36,
              tone:
                  child.gender == 'MALE' ? AvatarTone.lilac : AvatarTone.primary,
              imageUrl: child.photoUrl as String?,
            ),
            const SizedBox(width: 12),
            Text(child.nickname as String, style: AppTextStyles.body1Bold),
            const SizedBox(width: 8),
            Text(
              AppDateUtils.formatAgeMonths(age),
              style: AppTextStyles.caption.copyWith(color: AppColors.primary700),
            ),
            const Spacer(),
            // 톱니바퀴 — 탭하면 아이 정보 수정 화면으로.
            const Icon(Icons.settings_rounded,
                size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  final String label;
  final String? emoji;
  // 선택 시 적용할 액센트 색 — 남아 sky / 여아 pink.
  final Color accent;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderChip({
    required this.label,
    this.emoji,
    required this.accent,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? accent : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) ...[
              Text(emoji!, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppTextStyles.body2.copyWith(
                color: isSelected ? accent : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
