import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../widgets/common_button.dart';
import '../../../widgets/design/notebook.dart';

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
      title: '우리 아이 또래 친구를',
      keyword: '만나요',
      subtitle: '비슷한 개월수의 아이를 키우는\n부모님들과 쉽게 연결돼요',
      icon: Icons.child_care_rounded,
      tint: AppColors.sky,
      tintInk: AppColors.skyInk,
    ),
    _OnboardingPage(
      title: '동네에서 가까운 모임을',
      keyword: '찾아요',
      subtitle: '우리 동네에서 열리는\n다양한 육아 모임에 참여해 보세요',
      icon: Icons.place_rounded,
      tint: AppColors.hi,
      tintInk: AppColors.hiInk,
    ),
    _OnboardingPage(
      title: '안전하고 즐거운',
      keyword: '육아 모임',
      subtitle: '본인 인증된 부모님들과\n안심하고 모임을 즐겨요',
      icon: Icons.verified_user_rounded,
      tint: AppColors.sage,
      tintInk: AppColors.sageInk,
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
      body: SafeArea(
        child: Column(
          children: [
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
                effect: const ExpandingDotsEffect(
                  activeDotColor: AppColors.ink,
                  dotColor: AppColors.line2,
                  dotHeight: 6,
                  dotWidth: 6,
                  spacing: 6,
                  expansionFactor: 3,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: PrimaryButton(
                text: _currentPage == _pages.length - 1 ? '시작하기' : '다음',
                onPressed: _onNext,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: TextButton(
                onPressed: _completeOnboarding,
                child: Text(
                  '건너뛰기',
                  style: AppTextStyles.body2.copyWith(color: AppColors.ink3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final String title;

  /// 제목 마지막 줄 — 형광펜으로 한 곳만 강조한다.
  final String keyword;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final Color tintInk;

  const _OnboardingPage({
    required this.title,
    required this.keyword,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.tintInk,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(34),
            ),
            child: Icon(icon, size: 58, color: tintInk),
          ),
          const SizedBox(height: 44),
          Text(
            title,
            style: AppTextStyles.greeting,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Highlight(
            child: Text(keyword, style: AppTextStyles.greeting),
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            style: AppTextStyles.paragraph,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
