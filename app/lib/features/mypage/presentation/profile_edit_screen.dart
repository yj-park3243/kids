import '../../../widgets/top_toast.dart';
import 'dart:io';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/utils/validators.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/common_button.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../widgets/common_input.dart';
import '../../../widgets/address_search_sheet.dart';
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
  String? _regionSido;
  String? _regionSigungu;
  String? _regionDong;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nicknameController = TextEditingController(text: user?.nickname ?? '');
    _introController = TextEditingController(text: user?.introduction ?? '');
    _regionSido = user?.regionSido;
    _regionSigungu = user?.regionSigungu;
    _regionDong = user?.regionDong;
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
      final repo = ref.read(authRepositoryProvider);
      // 새로 고른 프로필 사진이 있으면 먼저 업로드 → URL 받아서 PATCH.
      String? uploadedUrl;
      if (_profileImagePath != null) {
        uploadedUrl = await repo.uploadImage(_profileImagePath!);
      }
      await repo.updateProfile(
        nickname: _nicknameController.text.trim(),
        profileImageUrl: uploadedUrl,
        introduction: _introController.text.trim(),
        regionSido: _regionSido,
        regionSigungu: _regionSigungu,
        regionDong: _regionDong,
      );
      // 갱신된 프로필을 로컬 상태에 반영.
      await ref.read(authProvider.notifier).checkAuth();
      if (mounted) {
        showTopToast(
          context,
          '프로필이 수정되었습니다',
          backgroundColor: AppColors.success,
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showTopToast(
          context,
          '프로필 수정에 실패했습니다',
          backgroundColor: AppColors.error,
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: const CustomAppBar(title: '프로필 수정'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Form(
            key: _formKey,
            child: Column(
              // 라벨·캡션이 왼쪽으로 붙게 — 사진만 Center 로 감싼다.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 프로필 사진 — 둥근 네모(아바타와 같은 모양) + 잉크 카메라 배지.
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: AppColors.fill,
                            borderRadius: BorderRadius.circular(36),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: _profileImagePath != null
                              ? Image.file(
                                  File(_profileImagePath!),
                                  fit: BoxFit.cover,
                                )
                              : user?.profileImageUrl != null
                              ? Image.network(
                                  user!.profileImageUrl!,
                                  fit: BoxFit.cover,
                                )
                              : const Icon(
                                  Icons.person_rounded,
                                  size: 44,
                                  color: AppColors.ink3,
                                ),
                        ),
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.ink,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.paper,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 15,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),

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

                // 동네 — 가입 때 건너뛴 사람이 여기서 설정한다. 주변 새 모임 알림 기준.
                Text('우리 동네', style: AppTextStyles.captionBold),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final result = await showAddressSearchSheet(context);
                    if (result != null) {
                      setState(() {
                        _regionSido = result.sido;
                        _regionSigungu = result.sigungu;
                        _regionDong = result.dong;
                      });
                    }
                  },
                  borderRadius: AppRadius.rSm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 15,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.rSm,
                      border: Border.all(color: AppColors.line2),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 20,
                          color: AppColors.ink3,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _regionSido == null
                                ? '동네 검색'
                                : '$_regionSido $_regionSigungu $_regionDong',
                            style: AppTextStyles.body1.copyWith(
                              color: _regionSido == null
                                  ? AppColors.ink3
                                  : AppColors.ink,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: AppColors.line2,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '동네를 설정하면 주변에 새 모임이 생길 때 알림을 받아요.',
                  style: AppTextStyles.caption,
                ),
                // 한부모 가정 — 한부모 가정 계정에만 노출. 읽기 전용.
                if (user?.isSingleParent ?? false) ...[
                  const SizedBox(height: 20),
                  _LockedField(
                    label: user?.parentGender == 'DAD'
                        ? '싱글대디'
                        : user?.parentGender == 'MOM'
                        ? '싱글맘'
                        : '싱글맘·싱글대디',
                    value: '예',
                    onInfoTap: () => _showLockedInfoDialog(context),
                  ),
                ],
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

  static void _showLockedInfoDialog(BuildContext context) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.info,
      animType: AnimType.scale,
      title: '변경 불가 항목',
      desc: '운영자 문의로만 정정 가능합니다.',
      btnOkText: '확인',
      btnOkOnPress: () {},
    ).show();
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.fill,
        borderRadius: AppRadius.rSm,
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: AppColors.ink3,
          ),
          const SizedBox(width: 8),
          Text('$label: ', style: AppTextStyles.body2),
          Text(value, style: AppTextStyles.body1Bold),
          const Spacer(),
          GestureDetector(
            onTap: onInfoTap,
            child: const Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: AppColors.ink3,
            ),
          ),
        ],
      ),
    );
  }
}
