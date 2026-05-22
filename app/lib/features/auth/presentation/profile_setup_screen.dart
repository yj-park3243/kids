import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/common_button.dart';
import '../../../widgets/common_input.dart';
import '../providers/auth_provider.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  String? _profileImagePath;
  bool _isCheckingNickname = false;
  bool? _isNicknameAvailable;
  bool _isGeneratingNickname = false;
  bool _isLoading = false;

  // 부모 유형 — 'MOM' | 'DAD'. 가입 후 변경 불가.
  String? _parentGender;
  String? _parentGenderError;

  // 한부모 가정 여부. 가입 후 변경 불가.
  bool _isSingleParent = false;

  // 육아 친화 단어 풀 — 따뜻하고 부드러운 톤
  static const _adjectives = [
    // 분위기
    '따뜻한', '포근한', '다정한', '상냥한', '온화한', '부드러운', '살가운', '살랑살랑', '도란도란', '소곤소곤',
    // 귀여움
    '동글동글', '말랑말랑', '몽글몽글', '보들보들', '말캉말캉', '폭신폭신', '오동통한', '쫀득한', '뽀송뽀송', '토실토실',
    // 빛/색감
    '반짝이는', '빛나는', '눈부신', '환한', '맑은', '투명한', '산뜻한', '싱그러운', '청량한', '화사한',
    // 자연
    '봄날의', '햇살가득', '꽃피는', '바람결', '구름같은', '별빛같은', '달빛같은', '이슬맺힌', '새벽의', '노을빛',
    // 정겨움
    '사랑스러운', '귀여운', '깜찍한', '앙증맞은', '천진한', '해맑은', '순수한', '소중한', '예쁜', '곱디고운',
    // 상태
    '행복한', '평온한', '느긋한', '여유로운', '편안한', '즐거운', '신나는', '두근두근', '설레는', '포실포실',
  ];

  static const _nouns = [
    // 동물 — 귀여운 톤
    '곰인형', '토끼', '햄스터', '병아리', '오리', '강아지', '고양이', '판다', '코알라', '다람쥐',
    '아기곰', '아기사슴', '아기여우', '꼬마펭귄', '아기수달', '북극곰', '카피바라', '레서판다', '미어캣', '알파카',
    // 자연/사물 — 따뜻한 톤
    '구름', '별빛', '달빛', '햇살', '바람', '이슬', '꽃잎', '단풍', '눈꽃', '무지개',
    // 베이커리/디저트
    '마카롱', '쿠키', '머핀', '도넛', '와플', '푸딩', '솜사탕', '딸기', '복숭아', '체리',
    // 육아 관련
    '엄마', '아빠', '부모', '가족', '아기천사', '꼬마', '꼬망이', '둥이', '꿈나무', '새싹',
    // 사물
    '담요', '쿠션', '비누방울', '풍선', '편지', '선물', '리본', '하트', '별사탕', '솜뭉치',
  ];

  @override
  void initState() {
    super.initState();
    _generateRandomNickname();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  /// 자동 닉네임 생성 — 형용사+명사 결합, 중복이면 숫자 붙여 회피
  Future<void> _generateRandomNickname() async {
    if (_isGeneratingNickname) return;
    setState(() {
      _isGeneratingNickname = true;
      _isNicknameAvailable = null;
    });

    final rng = Random();
    final adj = _adjectives[rng.nextInt(_adjectives.length)];
    final noun = _nouns[rng.nextInt(_nouns.length)];
    var candidate = '$adj$noun';

    final repo = ref.read(authRepositoryProvider);
    for (var i = 0; i < 10; i++) {
      try {
        final available = await repo.checkNickname(candidate);
        if (available) break;
        candidate = '$adj$noun${i + 1}';
      } catch (_) {
        break;
      }
    }

    if (!mounted) return;
    setState(() {
      _nicknameController.text = candidate;
      _isGeneratingNickname = false;
      _isNicknameAvailable = true;
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              title: Text('카메라로 촬영', style: AppTextStyles.body1),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: Text('앨범에서 선택', style: AppTextStyles.body1),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source != null) {
      final image = await picker.pickImage(source: source, maxWidth: 512, imageQuality: 80);
      if (image != null) {
        setState(() => _profileImagePath = image.path);
      }
    }
  }

  Future<void> _checkNickname() async {
    final nickname = _nicknameController.text.trim();
    if (Validators.nickname(nickname) != null) return;

    setState(() => _isCheckingNickname = true);
    try {
      final available = await ref.read(authRepositoryProvider).checkNickname(nickname);
      setState(() {
        _isNicknameAvailable = available;
        _isCheckingNickname = false;
      });
    } catch (e) {
      setState(() {
        _isNicknameAvailable = false;
        _isCheckingNickname = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // parentGender 필수
    if (_parentGender == null) {
      setState(() => _parentGenderError = '부모 유형을 선택해 주세요');
      return;
    }

    setState(() {
      _parentGenderError = null;
      _isLoading = true;
    });

    String? imageUrl;
    if (_profileImagePath != null) {
      try {
        imageUrl = await ref.read(authRepositoryProvider).uploadImage(_profileImagePath!);
      } catch (e) {
        // Continue without image
      }
    }

    await ref.read(authProvider.notifier).completeProfile(
          nickname: _nicknameController.text.trim(),
          profileImageUrl: imageUrl,
          parentGender: _parentGender,
          isSingleParent: _isSingleParent,
        );

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.childSetup) {
        context.go('/child-setup');
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
      appBar: const CustomAppBar(title: '프로필 설정', showBack: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('프로필을 설정해 주세요', style: AppTextStyles.heading2),
                const SizedBox(height: 8),
                Text(
                  '다른 부모님들에게 보여질 정보입니다',
                  style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 32),

                // Profile Image
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.surfaceVariant,
                          backgroundImage: _profileImagePath != null
                              ? FileImage(File(_profileImagePath!))
                              : null,
                          child: _profileImagePath == null
                              ? const Icon(Icons.person_rounded, size: 50, color: AppColors.textHint)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Nickname
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: CommonInput(
                        label: '닉네임',
                        hint: '2~10자로 입력',
                        controller: _nicknameController,
                        validator: Validators.nickname,
                        onChanged: (_) => setState(() => _isNicknameAvailable = null),
                        maxLength: 10,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 30),
                      child: SizedBox(
                        height: 52,
                        width: 52,
                        child: ElevatedButton(
                          onPressed: _isGeneratingNickname ? null : _generateRandomNickname,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.surfaceVariant,
                            foregroundColor: AppColors.primary,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isGeneratingNickname
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: AppColors.primary,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded, size: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 30),
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isCheckingNickname ? null : _checkNickname,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isCheckingNickname
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('중복확인'),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isNicknameAvailable == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '사용 가능한 닉네임입니다',
                      style: AppTextStyles.caption.copyWith(color: AppColors.success),
                    ),
                  ),
                if (_isNicknameAvailable == false)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '이미 사용 중인 닉네임입니다',
                      style: AppTextStyles.caption.copyWith(color: AppColors.error),
                    ),
                  ),

                const SizedBox(height: 28),

                // 부모 유형 (필수, 가입 후 변경 불가)
                Text('부모 유형', style: AppTextStyles.body2Bold),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _ParentGenderOption(
                        emoji: '👩',
                        label: '엄마',
                        selected: _parentGender == 'MOM',
                        onTap: () => setState(() {
                          _parentGender = 'MOM';
                          _parentGenderError = null;
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ParentGenderOption(
                        emoji: '👨',
                        label: '아빠',
                        selected: _parentGender == 'DAD',
                        onTap: () => setState(() {
                          _parentGender = 'DAD';
                          _parentGenderError = null;
                        }),
                      ),
                    ),
                  ],
                ),
                if (_parentGenderError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _parentGenderError!,
                      style: AppTextStyles.caption.copyWith(color: AppColors.error),
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  '한 번 선택하면 변경할 수 없어요. 운영자 문의 시에만 정정 가능합니다.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),

                const SizedBox(height: 24),

                // 한부모 가정 (필수, 가입 후 변경 불가, default off)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('한부모 가정', style: AppTextStyles.body1Bold),
                      ),
                      Switch.adaptive(
                        value: _isSingleParent,
                        activeThumbColor: AppColors.primary,
                        onChanged: (v) => setState(() => _isSingleParent = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '한부모 가정 전용 모임에 참여할 수 있어요. 가입 후 변경 불가.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),

                const SizedBox(height: 40),

                PrimaryButton(
                  text: '다음',
                  isLoading: _isLoading,
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

/// 부모 유형 선택 카드. 핑크 글래스 톤.
class _ParentGenderOption extends StatelessWidget {
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ParentGenderOption({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary50 : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.body1Bold.copyWith(
                color: selected ? AppColors.primary700 : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
