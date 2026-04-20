import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/common_button.dart';
import '../../../widgets/common_input.dart';
import '../../../widgets/region_picker.dart';
import '../providers/auth_provider.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  String? _selectedSido;
  String? _selectedSigungu;
  String? _selectedDong;
  String? _profileImagePath;
  bool _isCheckingNickname = false;
  bool? _isNicknameAvailable;
  bool _isLoading = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              title: Text('카메라로 촬영', style: AppTextStyles.body1),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: Text('앨범에서 선택', style: AppTextStyles.body1),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source != null) {
      final image = await picker.pickImage(source: source, maxWidth: 512, imageQuality: 80);
      if (image != null) {
        setState(() => _profileImagePath = image.path);
      }
    }
  }

  Future<void> _checkNickname() async {
    final nickname = _nicknameController.text.trim();
    if (Validators.nickname(nickname) != null) return;

    setState(() => _isCheckingNickname = true);
    try {
      final available = await ref.read(authRepositoryProvider).checkNickname(nickname);
      setState(() {
        _isNicknameAvailable = available;
        _isCheckingNickname = false;
      });
    } catch (e) {
      setState(() {
        _isNicknameAvailable = false;
        _isCheckingNickname = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSido == null || _selectedSigungu == null || _selectedDong == null) {
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

    String? imageUrl;
    if (_profileImagePath != null) {
      try {
        imageUrl = await ref.read(authRepositoryProvider).uploadImage(_profileImagePath!);
      } catch (e) {
        // Continue without image
      }
    }

    await ref.read(authProvider.notifier).completeProfile(
          nickname: _nicknameController.text.trim(),
          regionSido: _selectedSido!,
          regionSigungu: _selectedSigungu!,
          regionDong: _selectedDong!,
          profileImageUrl: imageUrl,
        );

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.childSetup) {
        context.go('/child-setup');
      } else if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: '프로필 설정', showBack: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('프로필을 설정해 주세요', style: AppTextStyles.heading2),
                const SizedBox(height: 8),
                Text(
                  '다른 부모님들에게 보여질 정보입니다',
                  style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 32),

                // Profile Image
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.surfaceVariant,
                          backgroundImage: _profileImagePath != null
                              ? FileImage(File(_profileImagePath!))
                              : null,
                          child: _profileImagePath == null
                              ? const Icon(Icons.person_rounded, size: 50, color: AppColors.textHint)
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
                            child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Nickname
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: CommonInput(
                        label: '닉네임',
                        hint: '2~10자로 입력',
                        controller: _nicknameController,
                        validator: Validators.nickname,
                        onChanged: (_) => setState(() => _isNicknameAvailable = null),
                        maxLength: 10,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 30),
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isCheckingNickname ? null : _checkNickname,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isCheckingNickname
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('중복확인'),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isNicknameAvailable == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '사용 가능한 닉네임입니다',
                      style: AppTextStyles.caption.copyWith(color: AppColors.success),
                    ),
                  ),
                if (_isNicknameAvailable == false)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '이미 사용 중인 닉네임입니다',
                      style: AppTextStyles.caption.copyWith(color: AppColors.error),
                    ),
                  ),

                const SizedBox(height: 24),

                // Region
                RegionPicker(
                  onSelected: (sido, sigungu, dong) {
                    setState(() {
                      _selectedSido = sido;
                      _selectedSigungu = sigungu;
                      _selectedDong = dong;
                    });
                  },
                ),

                const SizedBox(height: 40),

                PrimaryButton(
                  text: '다음',
                  isLoading: _isLoading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
