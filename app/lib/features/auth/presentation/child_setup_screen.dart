import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/common_button.dart';
import '../../../widgets/common_input.dart';
import '../../../widgets/design/avatar.dart';
import '../providers/auth_provider.dart';

class ChildSetupScreen extends ConsumerStatefulWidget {
  const ChildSetupScreen({super.key, this.popOnDone = false});

  /// true 면 가입 흐름이 아니라 마이페이지 진입 — 추가 완료 후 pop.
  final bool popOnDone;

  @override
  ConsumerState<ChildSetupScreen> createState() => _ChildSetupScreenState();
}

class _ChildSetupScreenState extends ConsumerState<ChildSetupScreen> {
  final List<_ChildData> _children = [_ChildData()];
  bool _isLoading = false;

  void _addChild() {
    if (_children.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('아이는 최대 5명까지 등록할 수 있습니다'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    setState(() => _children.add(_ChildData()));
  }

  void _removeChild(int index) {
    if (_children.length <= 1) return;
    setState(() => _children.removeAt(index));
  }

  Future<void> _submit() async {
    // Validate all children
    for (var i = 0; i < _children.length; i++) {
      if (_children[i].nicknameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${i + 1}번째 아이의 이름을 입력해 주세요'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }
      if (_children[i].birthYear == null || _children[i].birthMonth == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${i + 1}번째 아이의 생년월을 선택해 주세요'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }
      if (_children[i].profilePhotoPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${i + 1}번째 아이의 프로필 사진을 등록해 주세요'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }
      if (_children[i].verificationPhotoPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${i + 1}번째 아이의 인증 사진을 등록해 주세요'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      for (final child in _children) {
        final repo = ref.read(authRepositoryProvider);
        final profileUrl = await repo.uploadImage(child.profilePhotoPath!);
        final verificationUrl =
            await repo.uploadImage(child.verificationPhotoPath!);
        await ref.read(authProvider.notifier).addChild(
              nickname: child.nicknameController.text.trim(),
              birthYear: child.birthYear!,
              birthMonth: child.birthMonth!,
              gender: child.gender,
              photoUrl: profileUrl,
              verificationPhotoUrl: verificationUrl,
            );
      }
      if (widget.popOnDone) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('아이를 추가했습니다'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.pop();
        }
      } else {
        await ref.read(authProvider.notifier).completeChildSetup();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('아이 정보 등록에 실패했습니다'),
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
    if (!widget.popOnDone) {
      ref.listen<AuthState>(authProvider, (previous, next) {
        if (next.status == AuthStatus.authenticated) {
          context.go('/home');
        }
      });
    }

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
                    if (widget.popOnDone) ...[
                      // 이미 등록된 아이들 — 컨텍스트로만 표시 (read-only).
                      Builder(builder: (_) {
                        final existing =
                            ref.watch(authProvider).user?.children ?? [];
                        if (existing.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('이미 등록된 아이', style: AppTextStyles.heading2),
                            const SizedBox(height: 8),
                            Text(
                              '아래에 추가할 아이 정보를 입력해 주세요',
                              style: AppTextStyles.body2.copyWith(
                                  color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 16),
                            ...existing.map((c) => _ExistingChildTile(child: c)),
                            const SizedBox(height: 24),
                            Text('추가할 아이', style: AppTextStyles.heading2),
                            const SizedBox(height: 16),
                          ],
                        );
                      }),
                    ] else ...[
                      Text('아이 정보를 알려주세요', style: AppTextStyles.heading2),
                      const SizedBox(height: 8),
                      Text(
                        '또래 친구를 찾기 위해 필요해요',
                        style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 24),
                    ],

                    ..._children.asMap().entries.map((entry) {
                      final index = entry.key;
                      final child = entry.value;
                      return _ChildCard(
                        key: ValueKey(child),
                        index: index,
                        data: child,
                        canRemove: _children.length > 1,
                        onRemove: () => _removeChild(index),
                      );
                    }),

                    const SizedBox(height: 16),

                    // Add child button
                    GestureDetector(
                      onTap: _addChild,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            style: BorderStyle.solid,
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

            // Submit button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: PrimaryButton(
                text: '완료',
                isLoading: _isLoading,
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChildData {
  final TextEditingController nicknameController = TextEditingController();
  int? birthYear;
  int? birthMonth;
  String? gender;
  String? profilePhotoPath; // 프로필 사진 — 공개 노출용 로컬 경로
  String? verificationPhotoPath; // 인증 사진 — 출생증명서/키즈노트 캡쳐 등, 어드민 검수용
}

class _ChildCard extends StatefulWidget {
  final int index;
  final _ChildData data;
  final bool canRemove;
  final VoidCallback onRemove;

  const _ChildCard({
    super.key,
    required this.index,
    required this.data,
    required this.canRemove,
    required this.onRemove,
  });

  @override
  State<_ChildCard> createState() => _ChildCardState();
}

class _ChildCardState extends State<_ChildCard> {
  Future<String?> _pickImage() async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      imageQuality: 85,
    );
    return img?.path;
  }

  Future<void> _pickProfilePhoto() async {
    final path = await _pickImage();
    if (path != null) {
      setState(() => widget.data.profilePhotoPath = path);
    }
  }

  Future<void> _pickVerificationPhoto() async {
    final path = await _pickImage();
    if (path != null) {
      setState(() => widget.data.verificationPhotoPath = path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final index = widget.index;
    final canRemove = widget.canRemove;
    final onRemove = widget.onRemove;
    void onChanged() => setState(() {});

    final currentYear = DateTime.now().year;
    final ageMonths = data.birthYear != null && data.birthMonth != null
        ? AppDateUtils.calculateAgeMonths(data.birthYear!, data.birthMonth!)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: AppTextStyles.body2Bold.copyWith(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('아이 ${index + 1}', style: AppTextStyles.body1Bold),
              if (ageMonths != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    AppDateUtils.formatAgeMonths(ageMonths),
                    style: AppTextStyles.caption.copyWith(color: AppColors.secondary),
                  ),
                ),
              ],
              const Spacer(),
              if (canRemove)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: AppColors.textHint,
                  onPressed: onRemove,
                ),
            ],
          ),
          const SizedBox(height: 16),

          // 프로필 사진 — 공개 노출 (마이페이지/방 등).
          Text('프로필 사진', style: AppTextStyles.body2Bold),
          const SizedBox(height: 6),
          Text(
            '마이페이지·방에서 다른 부모에게 보이는 사진이에요.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: 8),
          _PhotoSlot(
            path: data.profilePhotoPath,
            onTap: _pickProfilePhoto,
            placeholderIcon: Icons.add_a_photo_rounded,
            placeholderLabel: '프로필 사진 등록',
          ),
          const SizedBox(height: 16),

          // 인증 사진 — 어드민 검수용, 비공개.
          Text('인증 사진', style: AppTextStyles.body2Bold),
          const SizedBox(height: 6),
          Text(
            '운영자만 확인합니다. 아래 중 하나를 올려주세요.\n'
            '• 출생증명서\n'
            '• 키즈노트 아이 정보 화면 캡쳐 (아이 이름·생년월 + 사진)\n'
            '• 기타 자녀임을 확인할 수 있는 공식 서류',
            style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: 8),
          _PhotoSlot(
            path: data.verificationPhotoPath,
            onTap: _pickVerificationPhoto,
            placeholderIcon: Icons.verified_user_outlined,
            placeholderLabel: '인증 사진 등록',
          ),
          const SizedBox(height: 16),

          // Nickname
          CommonInput(
            label: '아이 이름',
            hint: '아이 이름',
            controller: data.nicknameController,
            maxLength: 10,
          ),
          const SizedBox(height: 16),

          // Birth Year & Month
          Text('생년월', style: AppTextStyles.body2Bold),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      hint: Text('연도', style: AppTextStyles.body1.copyWith(color: AppColors.textHint)),
                      value: data.birthYear,
                      items: List.generate(8, (i) => currentYear - i)
                          .map((year) => DropdownMenuItem(
                                value: year,
                                child: Text('$year년', style: AppTextStyles.body1),
                              ))
                          .toList(),
                      onChanged: (value) {
                        data.birthYear = value;
                        onChanged();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      hint: Text('월', style: AppTextStyles.body1.copyWith(color: AppColors.textHint)),
                      value: data.birthMonth,
                      items: List.generate(12, (i) => i + 1)
                          .map((month) => DropdownMenuItem(
                                value: month,
                                child: Text('$month월', style: AppTextStyles.body1),
                              ))
                          .toList(),
                      onChanged: (value) {
                        data.birthMonth = value;
                        onChanged();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Gender
          Text('성별', style: AppTextStyles.body2Bold),
          const SizedBox(height: 8),
          Row(
            children: [
              _GenderChip(
                label: '남아',
                isSelected: data.gender == 'MALE',
                onTap: () {
                  data.gender = data.gender == 'MALE' ? null : 'MALE';
                  onChanged();
                },
              ),
              const SizedBox(width: 8),
              _GenderChip(
                label: '여아',
                isSelected: data.gender == 'FEMALE',
                onTap: () {
                  data.gender = data.gender == 'FEMALE' ? null : 'FEMALE';
                  onChanged();
                },
              ),
            ],
          ),
        ],
      ),
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
                  Icon(placeholderIcon,
                      color: AppColors.textHint, size: 28),
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

/// 이미 등록된 아이를 read-only로 보여주는 작은 타일 — popOnDone 모드 컨텍스트용.
class _ExistingChildTile extends StatelessWidget {
  final dynamic child; // models/user.dart의 Child — import 순환 피하려 동적 처리.
  const _ExistingChildTile({required this.child});

  @override
  Widget build(BuildContext context) {
    final age = (child.ageMonths as int?) ??
        AppDateUtils.calculateAgeMonths(
            child.birthYear as int, child.birthMonth as int);
    return Container(
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
            tone: child.gender == 'MALE' ? AvatarTone.lilac : AvatarTone.primary,
            imageUrl: child.photoUrl as String?,
          ),
          const SizedBox(width: 12),
          Text(child.nickname as String, style: AppTextStyles.body1Bold),
          const SizedBox(width: 8),
          Text(
            AppDateUtils.formatAgeMonths(age),
            style: AppTextStyles.caption.copyWith(color: AppColors.primary700),
          ),
        ],
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderChip({
    required this.label,
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
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.body2.copyWith(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
