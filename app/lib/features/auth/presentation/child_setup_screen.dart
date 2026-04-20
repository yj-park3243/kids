import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/common_button.dart';
import '../../../widgets/common_input.dart';
import '../providers/auth_provider.dart';

class ChildSetupScreen extends ConsumerStatefulWidget {
  const ChildSetupScreen({super.key});

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
            content: Text('${i + 1}번째 아이의 태명/별명을 입력해 주세요'),
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
    }

    setState(() => _isLoading = true);

    try {
      for (final child in _children) {
        await ref.read(authProvider.notifier).addChild(
              nickname: child.nicknameController.text.trim(),
              birthYear: child.birthYear!,
              birthMonth: child.birthMonth!,
              gender: child.gender,
            );
      }
      await ref.read(authProvider.notifier).completeChildSetup();
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
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated) {
        context.go('/home');
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: '아이 정보 등록', showBack: false),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('아이 정보를 알려주세요', style: AppTextStyles.heading2),
                    const SizedBox(height: 8),
                    Text(
                      '또래 친구를 찾기 위해 필요해요',
                      style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),

                    ..._children.asMap().entries.map((entry) {
                      final index = entry.key;
                      final child = entry.value;
                      return _ChildCard(
                        index: index,
                        data: child,
                        canRemove: _children.length > 1,
                        onRemove: () => _removeChild(index),
                        onChanged: () => setState(() {}),
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
}

class _ChildCard extends StatelessWidget {
  final int index;
  final _ChildData data;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _ChildCard({
    required this.index,
    required this.data,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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

          // Nickname
          CommonInput(
            label: '태명/별명',
            hint: '아이의 태명이나 별명',
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
              const SizedBox(width: 8),
              _GenderChip(
                label: '비공개',
                isSelected: data.gender == null,
                onTap: () {
                  data.gender = null;
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
