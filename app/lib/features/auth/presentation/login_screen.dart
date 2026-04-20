import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../widgets/common_button.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated) {
        context.go('/home');
      } else if (next.status == AuthStatus.profileSetup) {
        context.go('/profile-setup');
      } else if (next.status == AuthStatus.childSetup) {
        context.go('/child-setup');
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Logo area
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '같이\n크자',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '같이크자',
                style: AppTextStyles.heading1.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '우리 아이 또래 친구를 동네에서 만나요',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),

              const Spacer(flex: 3),

              // Social Login Buttons
              SocialLoginButton(
                text: '카카오로 시작하기',
                backgroundColor: AppColors.kakao,
                textColor: AppColors.kakaoText,
                iconWidget: const Text('K', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                onPressed: () {
                  // TODO: Implement Kakao login
                  _showComingSoon(context, '카카오 로그인');
                },
              ),
              const SizedBox(height: 12),

              SocialLoginButton(
                text: 'Apple로 시작하기',
                backgroundColor: AppColors.apple,
                textColor: Colors.white,
                icon: Icons.apple,
                onPressed: () {
                  _showComingSoon(context, 'Apple 로그인');
                },
              ),
              const SizedBox(height: 12),

              SocialLoginButton(
                text: 'Google로 시작하기',
                backgroundColor: AppColors.google,
                textColor: AppColors.textPrimary,
                borderColor: AppColors.googleBorder,
                iconWidget: const Text('G', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF4285F4))),
                onPressed: () {
                  _showComingSoon(context, 'Google 로그인');
                },
              ),
              const SizedBox(height: 12),

              SocialLoginButton(
                text: '이메일로 시작하기',
                backgroundColor: AppColors.surfaceVariant,
                textColor: AppColors.textPrimary,
                icon: Icons.email_outlined,
                onPressed: () => context.push('/email-login'),
              ),

              const SizedBox(height: 24),

              // Sign up link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '아직 계정이 없으신가요? ',
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/email-register'),
                    child: Text(
                      '회원가입',
                      style: AppTextStyles.body2Bold.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature 기능은 준비 중입니다'),
        backgroundColor: AppColors.textSecondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
