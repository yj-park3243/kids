import '../../../widgets/top_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/common_button.dart';
import '../../../widgets/common_input.dart';
import '../data/support_repository.dart';

class InquiryScreen extends ConsumerStatefulWidget {
  const InquiryScreen({super.key});

  @override
  ConsumerState<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends ConsumerState<InquiryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref.read(supportRepositoryProvider).createInquiry(
            subject: _subjectController.text.trim(),
            message: _messageController.text.trim(),
          );
      if (!mounted) return;
      showTopToast(context, '문의가 접수되었습니다. 빠른 시일 내에 답변드리겠습니다.');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      showTopToast(context, '문의 전송에 실패했습니다. 잠시 후 다시 시도해주세요.', backgroundColor: AppColors.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: '1:1 문의'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '무엇이 궁금하신가요?',
                  style: AppTextStyles.heading2,
                ),
                const SizedBox(height: 8),
                Text(
                  '문의 주시면 빠른 시일 내에 답변드리겠습니다.',
                  style: AppTextStyles.body2
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 28),
                CommonInput(
                  label: '제목',
                  hint: '예: 로그인이 안 돼요',
                  controller: _subjectController,
                  maxLength: 200,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '제목을 입력해주세요' : null,
                ),
                const SizedBox(height: 20),
                CommonInput(
                  label: '내용',
                  hint: '문의 내용을 자세히 작성해주세요',
                  controller: _messageController,
                  maxLines: 8,
                  maxLength: 5000,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '내용을 입력해주세요' : null,
                ),
                const SizedBox(height: 32),
                PrimaryButton(
                  text: '문의 보내기',
                  isLoading: _submitting,
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
