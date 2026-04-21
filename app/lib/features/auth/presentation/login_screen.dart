import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../widgets/common_button.dart';
import '../../../widgets/design/baby_avatar.dart';
import '../../../widgets/design/pink_blobs.dart';
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
      backgroundColor: Colors.transparent,
      body: PinkBlobsBackground(
        strong: true,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                // Hero avatars
                SizedBox(
                  height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: 30,
                        top: 30,
                        child: Transform.rotate(
                          angle: -0.15,
                          child: const BabyAvatar(
                            size: 78,
                            tone: BabyAvatarTone.cream,
                          ),
                        ),
                      ),
                      const BabyAvatar(size: 110, tone: BabyAvatarTone.pink),
                      Positioned(
                        right: 30,
                        top: 20,
                        child: Transform.rotate(
                          angle: 0.15,
                          child: const BabyAvatar(
                            size: 84,
                            tone: BabyAvatarTone.mint,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppColors.pinkTextGradient.createShader(bounds),
                  child: Text(
                    '같이크자',
                    style: AppTextStyles.display.copyWith(
                      color: Colors.white,
                      fontSize: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '우리 아이 또래 친구를 동네에서 만나요',
                  style: AppTextStyles.body1.copyWith(color: AppColors.ink500),
                ),
                const Spacer(flex: 3),
                SocialLoginButton(
                  text: '카카오로 시작하기',
                  backgroundColor: AppColors.kakao,
                  textColor: AppColors.kakaoText,
                  iconWidget: const Text(
                    'K',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  onPressed: () => _showComingSoon(context, '카카오 로그인'),
                ),
                const SizedBox(height: 10),
                SocialLoginButton(
                  text: 'Apple로 시작하기',
                  backgroundColor: AppColors.apple,
                  textColor: Colors.white,
                  icon: Icons.apple,
                  onPressed: () => _showComingSoon(context, 'Apple 로그인'),
                ),
                const SizedBox(height: 10),
                SocialLoginButton(
                  text: 'Google로 시작하기',
                  backgroundColor: AppColors.google,
                  textColor: AppColors.ink900,
                  borderColor: AppColors.googleBorder,
                  iconWidget: const Text(
                    'G',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4285F4),
                    ),
                  ),
                  onPressed: () => _showComingSoon(context, 'Google 로그인'),
                ),
                const SizedBox(height: 10),
                SocialLoginButton(
                  text: '이메일로 시작하기',
                  backgroundColor: Colors.white,
                  textColor: AppColors.ink900,
                  borderColor: AppColors.pink200,
                  icon: Icons.email_outlined,
                  onPressed: () => context.push('/email-login'),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '아직 계정이 없으신가요? ',
                      style: AppTextStyles.body2.copyWith(color: AppColors.ink500),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/email-register'),
                      child: Text(
                        '회원가입',
                        style: AppTextStyles.body2Bold.copyWith(
                          color: AppColors.pink500,
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
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature 기능은 준비 중입니다'),
        backgroundColor: AppColors.pink700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
