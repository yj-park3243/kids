import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../widgets/design/primary_button.dart';
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
  // 서버에 닿지 못했을 때만 켜지는 재시도 UI.
  bool _unreachable = false;

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
    if (!onboardingComplete) {
      if (mounted) context.go('/onboarding');
      return;
    }

    final token = await SecureStorage.getAccessToken();
    if (token == null) {
      if (mounted) context.go('/login');
      return;
    }

    await _checkAuth();
  }

  Future<void> _checkAuth() async {
    if (mounted) setState(() => _unreachable = false);
    // 결과는 build 의 authProvider 리스너가 받아 화면을 옮긴다.
    await ref.read(authProvider.notifier).checkAuth();
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
        case AuthStatus.profileSetup:
          context.go('/profile-setup');
          break;
        case AuthStatus.childSetup:
          context.go('/child-setup');
          break;
        case AuthStatus.unreachable:
          setState(() => _unreachable = true);
          break;
        default:
          break;
      }
    });

    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/icon/logo.png',
                  height: 140,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 18),
                Text('같이크자', style: AppTextStyles.greeting),
                const SizedBox(height: 6),
                Text(
                  '우리 아이 또래 친구를 만나요',
                  style: AppTextStyles.body2,
                ),
                if (_unreachable) ...[
                  const SizedBox(height: 30),
                  Text(
                    '서버에 연결할 수 없어요\n네트워크를 확인하고 다시 시도해 주세요',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body2,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 200,
                    child: GlassButton(
                      text: '다시 시도',
                      onPressed: _checkAuth,
                      height: 46,
                      textColor: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: Text(
                      '다른 계정으로 로그인',
                      style: AppTextStyles.body2.copyWith(color: AppColors.link),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
