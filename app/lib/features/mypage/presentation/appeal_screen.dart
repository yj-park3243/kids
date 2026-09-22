import '../../../widgets/top_toast.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/common_button.dart';
import '../../../widgets/design/notebook.dart';
import '../../auth/providers/auth_provider.dart';

/// 계정 정지(SUSPENDED) 안내 + 정지 해제 증거 사진 제출.
class AppealScreen extends ConsumerStatefulWidget {
  const AppealScreen({super.key});

  @override
  ConsumerState<AppealScreen> createState() => _AppealScreenState();
}

class _AppealScreenState extends ConsumerState<AppealScreen> {
  String? _photoPath;
  bool _submitting = false;

  Future<void> _pick() async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      imageQuality: 85,
    );
    if (img != null) setState(() => _photoPath = img.path);
  }

  void _toast(String msg, {bool error = false}) {
    showTopToast(context, msg, backgroundColor: error ? AppColors.error : AppColors.success);
  }

  Future<void> _submit() async {
    if (_photoPath == null) {
      _toast('증거 사진을 등록해 주세요', error: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final url = await repo.uploadImage(_photoPath!);
      await repo.submitAppeal(url);
      if (mounted) {
        _toast('증거 사진이 제출되었습니다. 검토 후 정지가 해제됩니다.');
        context.pop();
      }
    } catch (_) {
      if (mounted) _toast('제출에 실패했습니다. 잠시 후 다시 시도해 주세요.', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: const CustomAppBar(title: '계정 정지 안내'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bad.withValues(alpha: 0.08),
                  borderRadius: AppRadius.rMd,
                  border:
                      Border.all(color: AppColors.bad.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.gpp_bad_rounded,
                        color: AppColors.bad, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '아이 사진 검수 결과 계정 이용이 정지되었습니다.\n'
                        '정지 상태에서는 모임 생성·참여가 제한됩니다.',
                        style: AppTextStyles.body2.copyWith(
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              Text('정지 해제 요청', style: AppTextStyles.sectionHead),
              const SizedBox(height: 6),
              Text(
                '본인 아이임을 확인할 수 있는 사진(출생증명서, 최근 사진 등)을 '
                '추가로 제출해 주세요. 운영자 검토 후 정지가 해제됩니다.',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 12),
              if (_photoPath != null)
                GestureDetector(
                  onTap: _pick,
                  child: ClipRRect(
                    borderRadius: AppRadius.rMd,
                    child: Image.file(
                      File(_photoPath!),
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                DashedBox(
                  radius: AppRadius.md,
                  padding: EdgeInsets.zero,
                  onTap: _pick,
                  child: SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_a_photo_rounded,
                            color: AppColors.ink3, size: 32),
                        const SizedBox(height: 8),
                        Text('증거 사진 등록', style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 30),
              PrimaryButton(
                text: '제출하기',
                isLoading: _submitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
