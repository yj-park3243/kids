import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../widgets/common_button.dart';
import '../../../widgets/design/accent_blobs.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated) {
        context.go('/home');
      } else if (next.status == AuthStatus.phoneVerification) {
        context.go('/phone-verification');
      } else if (next.status == AuthStatus.profileSetup) {
        context.go('/profile-setup');
      } else if (next.status == AuthStatus.childSetup) {
        context.go('/child-setup');
      } else if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AccentBlobsBackground(
        strong: true,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Image.asset(
                  'assets/icon/logo.png',
                  height: 180,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppColors.primaryTextGradient.createShader(bounds),
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
                  text: 'Apple로 시작하기',
                  backgroundColor: AppColors.apple,
                  textColor: Colors.white,
                  icon: Icons.apple,
                  onPressed: () => _signInWithApple(context, ref),
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
                  onPressed: () => _signInWithGoogle(context, ref),
                ),
                const SizedBox(height: 10),
                SocialLoginButton(
                  key: const Key('btn-start-email'),
                  text: '이메일로 시작하기',
                  backgroundColor: Colors.white,
                  textColor: AppColors.ink900,
                  borderColor: AppColors.primary200,
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
      ),
    );
  }

  Future<void> _signInWithApple(BuildContext context, WidgetRef ref) async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final idToken = credential.identityToken;
      if (!context.mounted) return;
      if (idToken == null) {
        _showError(context, 'Apple 인증 토큰을 받지 못했습니다.');
        return;
      }
      await ref.read(authProvider.notifier).socialLogin(
            provider: 'APPLE',
            accessToken: credential.authorizationCode,
            idToken: idToken,
          );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return;
      if (!context.mounted) return;
      _showError(context, 'Apple 로그인에 실패했습니다.');
    } catch (_) {
      if (!context.mounted) return;
      _showError(context, 'Apple 로그인 중 오류가 발생했습니다.');
    }
  }

  Future<void> _signInWithGoogle(BuildContext context, WidgetRef ref) async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return; // 사용자 취소
      final auth = await googleUser.authentication;
      final idToken = auth.idToken;
      if (!context.mounted) return;
      if (idToken == null) {
        _showError(context, 'Google 인증 토큰을 받지 못했습니다.');
        return;
      }
      await ref.read(authProvider.notifier).socialLogin(
            provider: 'GOOGLE',
            accessToken: auth.accessToken ?? '',
            idToken: idToken,
          );
    } catch (_) {
      if (!context.mounted) return;
      _showError(context, 'Google 로그인 중 오류가 발생했습니다.');
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
