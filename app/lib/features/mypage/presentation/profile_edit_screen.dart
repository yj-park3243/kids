import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/common_button.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../widgets/address_search_sheet.dart';
import '../../../widgets/common_input.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nicknameController;
  late TextEditingController _introController;
  String? _profileImagePath;
  String? _selectedSido;
  String? _selectedSigungu;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nicknameController = TextEditingController(text: user?.nickname ?? '');
    _introController = TextEditingController(text: user?.introduction ?? '');
    _selectedSido = user?.regionSido;
    _selectedSigungu = user?.regionSigungu;
  }

  Future<void> _selectAddress() async {
    final result = await showAddressSearchSheet(context);
    if (result == null) return;
    setState(() {
      // 큰 덩어리만 — 시/도 + 시/군/구. dong/도로명/건물명은 저장 안 함.
      _selectedSido = result.sido;
      _selectedSigungu = result.sigungu;
    });
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _introController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 80,
    );
    if (image != null) {
      setState(() => _profileImagePath = image.path);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // TODO: Call update profile API
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('프로필이 수정되었습니다'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('프로필 수정에 실패했습니다'),
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
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: '프로필 수정'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Profile Image
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.surfaceVariant,
                        backgroundImage: _profileImagePath != null
                            ? FileImage(File(_profileImagePath!))
                            : user?.profileImageUrl != null
                                ? NetworkImage(user!.profileImageUrl!)
                                : null,
                        child: _profileImagePath == null && user?.profileImageUrl == null
                            ? const Icon(Icons.person_rounded,
                                size: 50, color: AppColors.textHint)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                CommonInput(
                  label: '닉네임',
                  controller: _nicknameController,
                  validator: Validators.nickname,
                  maxLength: 10,
                ),
                const SizedBox(height: 20),

                CommonInput(
                  label: '자기소개',
                  hint: '간단한 자기소개',
                  controller: _introController,
                  maxLines: 3,
                  maxLength: 200,
                ),
                const SizedBox(height: 20),

                // 부모 정체성 / 한부모 가정 — 읽기 전용. PATCH 본문에 포함하지 않음.
                _LockedField(
                  label: '부모',
                  value: _parentGenderLabel(user?.parentGender),
                  onInfoTap: () => _showLockedInfoDialog(context),
                ),
                const SizedBox(height: 12),
                _LockedField(
                  label: '한부모 가정',
                  value: (user?.isSingleParent ?? false) ? '예' : '아니오',
                  onInfoTap: () => _showLockedInfoDialog(context),
                ),
                const SizedBox(height: 20),

                // 지역 — 주소 검색 (Daum 우편번호). 큰 덩어리(시/도 + 시/군/구)만 저장.
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('지역', style: AppTextStyles.body2Bold),
                ),
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
                          child: _selectedSido == null
                              ? Text(
                                  '주소 검색',
                                  style: AppTextStyles.body2.copyWith(color: AppColors.textHint),
                                )
                              : Text(
                                  '$_selectedSido ${_selectedSigungu ?? ''}'.trim(),
                                  style: AppTextStyles.body1,
                                ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                PrimaryButton(
                  text: '저장',
                  isLoading: _isLoading,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _parentGenderLabel(String? gender) {
    switch (gender) {
      case 'MOM':
        return '👩 엄마';
      case 'DAD':
        return '👨 아빠';
      default:
        return '-';
    }
  }

  static void _showLockedInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('변경 불가 항목'),
        content: const Text('운영자 문의로만 정정 가능합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}

/// 회색 박스 안에 읽기 전용 값 + ⓘ 아이콘 (탭하면 정정 불가 안내).
class _LockedField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onInfoTap;

  const _LockedField({
    required this.label,
    required this.value,
    required this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
          ),
          Text(value, style: AppTextStyles.body1Bold),
          const Spacer(),
          GestureDetector(
            onTap: onInfoTap,
            child: const Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}
