import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/common_button.dart';
import '../../../widgets/common_input.dart';
import '../providers/auth_provider.dart';

const _termsUrl = 'https://growtogether.kr/terms';
const _privacyUrl = 'https://growtogether.kr/privacy';

class EmailRegisterScreen extends ConsumerStatefulWidget {
  const EmailRegisterScreen({super.key});

  @override
  ConsumerState<EmailRegisterScreen> createState() => _EmailRegisterScreenState();
}

class _EmailRegisterScreenState extends ConsumerState<EmailRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _register() {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) return;
    ref.read(authProvider.notifier).emailRegister(
          _emailController.text.trim(),
          _passwordController.text,
        );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.phoneVerification) {
        context.go('/phone-verification');
      } else if (next.status == AuthStatus.profileSetup) {
        context.go('/profile-setup');
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
      appBar: const CustomAppBar(title: '회원가입'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Text('회원가입', style: AppTextStyles.heading1),
                const SizedBox(height: 8),
                Text(
                  '이메일과 비밀번호를 설정해 주세요',
                  style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 40),

                CommonInput(
                  key: const Key('input-register-email'),
                  label: '이메일',
                  hint: 'example@email.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 20),

                CommonInput(
                  key: const Key('input-register-password'),
                  label: '비밀번호',
                  hint: '8자 이상, 영문+숫자+특수문자',
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  validator: Validators.password,
                  textInputAction: TextInputAction.next,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: AppColors.textHint,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 20),

                CommonInput(
                  key: const Key('input-register-password-confirm'),
                  label: '비밀번호 확인',
                  hint: '비밀번호를 다시 입력하세요',
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return '비밀번호가 일치하지 않습니다';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _register(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: AppColors.textHint,
                    ),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),

                const SizedBox(height: 24),

                // Apple Guideline 1.2: EULA + 무관용 정책 동의.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      key: const Key('checkbox-register-terms'),
                      value: _agreedToTerms,
                      onChanged: (v) =>
                          setState(() => _agreedToTerms = v ?? false),
                      activeColor: AppColors.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: RichText(
                          text: TextSpan(
                            style: AppTextStyles.body2.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                            children: [
                              TextSpan(
                                text: '이용약관',
                                style: AppTextStyles.body2Bold.copyWith(
                                  color: AppColors.primary,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => _openUrl(_termsUrl),
                              ),
                              const TextSpan(text: ' 및 '),
                              TextSpan(
                                text: '개인정보 처리방침',
                                style: AppTextStyles.body2Bold.copyWith(
                                  color: AppColors.primary,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => _openUrl(_privacyUrl),
                              ),
                              const TextSpan(
                                text:
                                    '에 동의합니다. 같이크자는 부적절한 콘텐츠와 사용자에 대해 무관용 정책을 적용합니다.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                PrimaryButton(
                  key: const Key('btn-register-submit'),
                  text: '회원가입',
                  isLoading: authState.status == AuthStatus.loading,
                  isEnabled: _agreedToTerms,
                  onPressed: _register,
                ),

                const SizedBox(height: 20),

                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '이미 계정이 있으신가요? ',
                        style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
                      ),
                      GestureDetector(
                        onTap: () => context.pushReplacement('/email-login'),
                        child: Text(
                          '로그인',
                          style: AppTextStyles.body2Bold.copyWith(color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
