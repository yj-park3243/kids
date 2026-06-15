import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/user.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/child_traits_selector.dart';
import '../../../widgets/common_button.dart';
import '../../../widgets/common_input.dart';
import '../../../widgets/cupertino_picker_sheet.dart';
import '../../../widgets/design/baby_avatar.dart';
import '../../../widgets/picker_field.dart';
import '../../auth/providers/auth_provider.dart';

/// 마이페이지에서 진입하는 단일 아이 편집 화면.
/// 사진/이름/생년월/성별/낮잠/기질을 모두 한 화면에서 수정.
class ChildEditScreen extends ConsumerStatefulWidget {
  final String childId;
  const ChildEditScreen({super.key, required this.childId});

  @override
  ConsumerState<ChildEditScreen> createState() => _ChildEditScreenState();
}

class _ChildEditScreenState extends ConsumerState<ChildEditScreen> {
  late TextEditingController _nicknameController;
  int? _birthYear;
  int? _birthMonth;
  String? _gender;
  String? _napTime;
  final Set<String> _temperamentTags = <String>{};
  String? _newProfilePhotoPath; // 새로 고른 로컬 경로 — 저장 시 업로드.
  String? _currentPhotoUrl; // 기존 서버 사진 URL.
  bool _isLoading = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController();
  }

  void _hydrateOnce(Child child) {
    if (_initialized) return;
    _initialized = true;
    _nicknameController.text = child.nickname;
    _birthYear = child.birthYear;
    _birthMonth = child.birthMonth;
    _gender = child.gender;
    _napTime = child.napTime;
    _temperamentTags.addAll(child.temperamentTags);
    _currentPhotoUrl = child.photoUrl;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      imageQuality: 85,
    );
    if (img != null) setState(() => _newProfilePhotoPath = img.path);
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_nicknameController.text.trim().isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('아이 이름을 입력해 주세요'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    if (_birthYear == null || _birthMonth == null) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('생년월을 선택해 주세요'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    if (_gender == null) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('성별을 선택해 주세요'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      String? uploadedPhotoUrl;
      if (_newProfilePhotoPath != null) {
        uploadedPhotoUrl = await repo.uploadImage(_newProfilePhotoPath!);
      }
      await ref.read(authProvider.notifier).updateChild(
            childId: widget.childId,
            nickname: _nicknameController.text.trim(),
            birthYear: _birthYear,
            birthMonth: _birthMonth,
            gender: _gender,
            photoUrl: uploadedPhotoUrl,
          );
      await ref.read(authProvider.notifier).updateChildTraits(
            childId: widget.childId,
            napTime: _napTime,
            temperamentTags: _temperamentTags.toList(),
          );
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('아이 정보를 수정했습니다'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('아이 정보 수정에 실패했습니다'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final children = ref.watch(authProvider).user?.children ?? const [];
    Child? child;
    for (final c in children) {
      if (c.id == widget.childId) {
        child = c;
        break;
      }
    }

    if (child == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: const CustomAppBar(title: '아이 정보 수정'),
        body: const Center(child: Text('아이 정보를 찾을 수 없습니다.')),
      );
    }

    _hydrateOnce(child);

    final currentYear = DateTime.now().year;
    final ageMonths = _birthYear != null && _birthMonth != null
        ? AppDateUtils.calculateAgeMonths(_birthYear!, _birthMonth!)
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: '아이 정보 수정'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _pickPhoto,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _newProfilePhotoPath != null
                                ? CircleAvatar(
                                    radius: 48,
                                    backgroundImage:
                                        FileImage(File(_newProfilePhotoPath!)),
                                  )
                                : BabyAvatar(
                                    size: 96,
                                    tone: _gender == 'MALE'
                                        ? BabyAvatarTone.lilac
                                        : BabyAvatarTone.primary,
                                    imageUrl: _currentPhotoUrl,
                                  ),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (ageMonths != null) ...[
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          AppDateUtils.formatAgeMonths(ageMonths),
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.primary700),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    CommonInput(
                      label: '아이 이름',
                      hint: '아이 이름',
                      controller: _nicknameController,
                      maxLength: 10,
                    ),
                    const SizedBox(height: 16),

                    Text('생년월', style: AppTextStyles.body2Bold),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _yearDropdown(currentYear)),
                        const SizedBox(width: 12),
                        Expanded(child: _monthDropdown()),
                      ],
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
                          isSelected: _gender == 'MALE',
                          onTap: () => setState(() => _gender = 'MALE'),
                        ),
                        const SizedBox(width: 8),
                        _GenderChip(
                          label: '여아',
                          emoji: '👧',
                          accent: AppColors.primary,
                          isSelected: _gender == 'FEMALE',
                          onTap: () => setState(() => _gender = 'FEMALE'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    NapTimeSelector(
                      selectedKey: _napTime,
                      onChanged: (k) => setState(() => _napTime = k),
                    ),
                    const SizedBox(height: 16),

                    TemperamentTagSelector(
                      selectedKeys: _temperamentTags,
                      onToggle: (k) {
                        setState(() {
                          if (_temperamentTags.contains(k)) {
                            _temperamentTags.remove(k);
                          } else if (_temperamentTags.length < 5) {
                            _temperamentTags.add(k);
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: PrimaryButton(
                text: '저장',
                isLoading: _isLoading,
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _yearDropdown(int currentYear) {
    return PickerField(
      label: '연도',
      value: _birthYear != null ? '$_birthYear년' : null,
      hint: '연도 선택',
      onTap: () async {
        final years = List.generate(8, (i) => currentYear - i);
        final v = await showWheelSheet<int>(
          context,
          title: '연도 선택',
          options: years,
          initial: _birthYear ?? years.first,
          format: (y) => '$y년',
        );
        if (v == null) return;
        setState(() => _birthYear = v);
      },
    );
  }

  Widget _monthDropdown() {
    return PickerField(
      label: '월',
      value: _birthMonth != null ? '$_birthMonth월' : null,
      hint: '월 선택',
      onTap: () async {
        final months = List.generate(12, (i) => i + 1);
        final v = await showWheelSheet<int>(
          context,
          title: '월 선택',
          options: months,
          initial: _birthMonth ?? 1,
          format: (m) => '$m월',
        );
        if (v == null) return;
        setState(() => _birthMonth = v);
      },
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
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.12)
              : AppColors.surface,
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
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
