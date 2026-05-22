import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/error/error_reporter.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../widgets/design/accent_blobs.dart';
import '../../auth/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final onboardingComplete = await SecureStorage.isOnboardingComplete();
    final token = await SecureStorage.getAccessToken();
    final refresh = await SecureStorage.getRefreshToken();

    // 진단 — 자동 로그인 실패 추적용. 서버 app_error_log 에 기록된다.
    unawaited(ErrorReporter.instance.report(
      '[splash-diag] onboarding=$onboardingComplete '
      'access=${token == null ? "NULL" : "len${token.length}"} '
      'refresh=${refresh == null ? "NULL" : "len${refresh.length}"}',
      screenName: 'splash-diag',
    ));

    if (!onboardingComplete) {
      if (mounted) context.go('/onboarding');
      return;
    }

    if (token == null) {
      if (mounted) context.go('/login');
      return;
    }

    // Try to get user profile
    try {
      await ref.read(authProvider.notifier).checkAuth();
    } catch (e) {
      unawaited(ErrorReporter.instance.report(
        '[splash-diag] checkAuth threw: $e',
        screenName: 'splash-diag',
      ));
      if (mounted) context.go('/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      switch (next.status) {
        case AuthStatus.authenticated:
          context.go('/home');
          break;
        case AuthStatus.unauthenticated:
          context.go('/login');
          break;
        case AuthStatus.phoneVerification:
          context.go('/phone-verification');
          break;
        case AuthStatus.profileSetup:
          context.go('/profile-setup');
          break;
        case AuthStatus.childSetup:
          context.go('/child-setup');
          break;
        default:
          break;
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AccentBlobsBackground(
        strong: true,
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/icon/logo.png',
                    height: 160,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 20),
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        AppColors.primaryTextGradient.createShader(bounds),
                    child: Text(
                      '같이크자',
                      style: AppTextStyles.display.copyWith(
                        color: Colors.white,
                        fontSize: 34,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '우리 아이 또래 친구를 만나요',
                    style: AppTextStyles.body1.copyWith(color: AppColors.ink500),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
