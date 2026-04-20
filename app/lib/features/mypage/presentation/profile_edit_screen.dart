import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/common_button.dart';
import '../../../widgets/common_input.dart';
import '../../../widgets/region_picker.dart';
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
  String? _selectedDong;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nicknameController = TextEditingController(text: user?.nickname ?? '');
    _introController = TextEditingController(text: user?.introduction ?? '');
    _selectedSido = user?.regionSido;
    _selectedSigungu = user?.regionSigungu;
    _selectedDong = user?.regionDong;
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

                RegionPicker(
                  initialSido: _selectedSido,
                  initialSigungu: _selectedSigungu,
                  initialDong: _selectedDong,
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
}
