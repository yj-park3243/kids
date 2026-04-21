import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../widgets/common_button.dart';
import '../../../widgets/design/baby_avatar.dart';
import '../../../widgets/design/pink_blobs.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  final _pages = const [
    _OnboardingPage(
      tone: BabyAvatarTone.pink,
      title: '우리 아이 또래 친구를\n만나요',
      subtitle: '비슷한 개월수의 아이를 키우는\n부모님들과 쉽게 연결돼요',
    ),
    _OnboardingPage(
      tone: BabyAvatarTone.lilac,
      title: '동네에서 가까운\n모임을 찾아요',
      subtitle: '우리 동네에서 열리는\n다양한 육아 모임에 참여해 보세요',
    ),
    _OnboardingPage(
      tone: BabyAvatarTone.mint,
      title: '안전하고 즐거운\n육아 모임',
      subtitle: '본인 인증된 부모님들과\n안심하고 모임을 즐겨요',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    await SecureStorage.setOnboardingComplete();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PinkBlobsBackground(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: Text(
                    '건너뛰기',
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.ink500,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemBuilder: (context, index) => _pages[index],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: SmoothPageIndicator(
                  controller: _pageController,
                  count: _pages.length,
                  effect: ExpandingDotsEffect(
                    activeDotColor: AppColors.pink500,
                    dotColor: AppColors.pink500.withValues(alpha: 0.2),
                    dotHeight: 8,
                    dotWidth: 8,
                    expansionFactor: 3,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: PrimaryButton(
                  text: _currentPage == _pages.length - 1 ? '시작하기' : '다음',
                  onPressed: _onNext,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final BabyAvatarTone tone;
  final String title;
  final String subtitle;

  const _OnboardingPage({
    required this.tone,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 30,
                  top: 20,
                  child: Transform.rotate(
                    angle: -0.1,
                    child: BabyAvatar(size: 80, tone: BabyAvatarTone.cream),
                  ),
                ),
                BabyAvatar(size: 120, tone: tone),
                Positioned(
                  right: 20,
                  top: 30,
                  child: Transform.rotate(
                    angle: 0.1,
                    child: const BabyAvatar(size: 70, tone: BabyAvatarTone.lilac),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          Text(
            title,
            style: AppTextStyles.display.copyWith(fontSize: 28),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            style: AppTextStyles.body1.copyWith(
              color: AppColors.ink500,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
