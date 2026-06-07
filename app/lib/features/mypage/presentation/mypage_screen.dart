import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/child_traits.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/user.dart';
import '../../../widgets/design/avatar.dart';
import '../../../widgets/design/baby_avatar.dart';
import '../../../widgets/design/design_chip.dart';
import '../../../widgets/design/glass_card.dart';
import '../../../widgets/design/accent_blobs.dart';
import '../../auth/providers/auth_provider.dart';
import '../../review/presentation/widgets/growth_grade.dart';

class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AccentBlobsBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('마이페이지', style: AppTextStyles.screenTitle),
                const SizedBox(height: 20),

                // 계정 정지 배너 — SUSPENDED 계정만 노출.
                if (user?.status == 'SUSPENDED') ...[
                  GestureDetector(
                    onTap: () => context.push('/appeal'),
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.gpp_bad_rounded,
                              color: AppColors.error, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '계정이 정지되었습니다. 탭하여 정지 해제를 요청하세요.',
                              style: AppTextStyles.body2.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: AppColors.error),
                        ],
                      ),
                    ),
                  ),
                ],

                // Profile glass card
                GlassCard(
                  tone: GlassTone.white,
                  radius: 24,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          InitialAvatar(
                            label: user?.nickname ?? '?',
                            size: 64,
                            tone: AvatarTone.primary,
                            ring: true,
                            imageUrl: user?.profileImageUrl,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  user?.nickname ?? '사용자',
                                  style: AppTextStyles.cardTitle.copyWith(fontSize: 17),
                                ),
                                const SizedBox(height: 6),
                                DesignChip(
                                  label: '#KIDS-${_familyHash(user?.id)}',
                                  tone: ChipTone.outline,
                                  height: 22,
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.push('/profile-edit'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: AppColors.glassBorder,
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                '편집',
                                style: AppTextStyles.chip.copyWith(
                                  color: AppColors.primary700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (user != null) ...[
                        const SizedBox(height: 14),
                        _GrowthRow(
                          score: user.mannerScore,
                          noShowLevel: user.noShowLevel,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Children
                if (user?.children != null && user!.children!.isNotEmpty)
                  GlassCard(
                    radius: 22,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('등록된 아이', style: AppTextStyles.body1Bold),
                        const SizedBox(height: 4),
                        Text(
                          '사진은 탭으로 빠르게 교체, 그 외는 편집을 눌러주세요',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.ink500),
                        ),
                        const SizedBox(height: 12),
                        ...user.children!.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final child = entry.value;
                          final age = child.ageMonths ??
                              AppDateUtils.calculateAgeMonths(
                                  child.birthYear, child.birthMonth);
                          final napLabel = napTimeLabel(child.napTime);
                          final tagLabels = child.temperamentTags
                              .map(temperamentTagLabel)
                              .whereType<String>()
                              .toList();
                          final hasTraits =
                              napLabel != null || tagLabels.isNotEmpty;
                          return Padding(
                            padding: EdgeInsets.only(
                              top: idx == 0 ? 0 : 14,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => _editChildPhoto(
                                          context, ref, child),
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          BabyAvatar(
                                            size: 40,
                                            tone: child.gender == 'MALE'
                                                ? BabyAvatarTone.lilac
                                                : BabyAvatarTone.primary,
                                            imageUrl: child.photoUrl,
                                          ),
                                          Positioned(
                                            right: -2,
                                            bottom: -2,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.all(3),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                    color: Colors.white,
                                                    width: 1.5),
                                              ),
                                              child: const Icon(
                                                Icons.camera_alt_rounded,
                                                size: 10,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Text(child.nickname,
                                              style:
                                                  AppTextStyles.body1Bold),
                                          Text(
                                            AppDateUtils.formatAgeMonths(age),
                                            style: AppTextStyles.caption
                                                .copyWith(
                                              color: AppColors.primary700,
                                            ),
                                          ),
                                          if (child.gender != null)
                                            DesignChip(
                                              label: child.gender == 'MALE'
                                                  ? '남아'
                                                  : '여아',
                                              tone: child.gender == 'MALE'
                                                  ? ChipTone.lilac
                                                  : ChipTone.primaryGhost,
                                              height: 22,
                                            ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => context.push(
                                          '/children/${child.id}/edit'),
                                      child: Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.7),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                            color: AppColors.glassBorder,
                                            width: 0.5,
                                          ),
                                        ),
                                        child: Text(
                                          '편집',
                                          style: AppTextStyles.chip.copyWith(
                                            color: AppColors.primary700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (hasTraits) ...[
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(left: 52),
                                    child: Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        if (napLabel != null)
                                          DesignChip(
                                            label: '낮잠 · $napLabel',
                                            tone: ChipTone.outline,
                                            height: 22,
                                          ),
                                        for (final t in tagLabels)
                                          DesignChip(
                                            label: t,
                                            tone: ChipTone.primaryGhost,
                                            height: 22,
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),

                _menuSection([
                  _MenuItem(
                    icon: Icons.edit_rounded,
                    label: '프로필 수정',
                    onTap: () => context.push('/profile-edit'),
                  ),
                  _MenuItem(
                    icon: Icons.child_care_rounded,
                    label: '아이 추가',
                    onTap: () => context.push('/child-add'),
                  ),
                  _MenuItem(
                    icon: Icons.notifications_none_rounded,
                    label: '알림 설정',
                    onTap: () => context.push('/notification-settings'),
                  ),
                  // TODO: register route /blocked-users → BlockedUsersScreen
                  _MenuItem(
                    icon: Icons.block_rounded,
                    label: '차단한 유저',
                    onTap: () => context.push('/blocked-users'),
                  ),
                ]),
                const SizedBox(height: 14),

                _menuSection([
                  _MenuItem(
                    icon: Icons.campaign_outlined,
                    label: '공지사항',
                    onTap: () => context.push('/notices'),
                  ),
                  _MenuItem(
                    icon: Icons.mail_outline_rounded,
                    label: '1:1 문의',
                    onTap: () => context.push('/inquiry'),
                  ),
                  _MenuItem(
                    icon: Icons.description_outlined,
                    label: '이용약관',
                    onTap: () => _openExternalUrl(
                        'https://growtogether.kr/terms'),
                  ),
                  _MenuItem(
                    icon: Icons.privacy_tip_outlined,
                    label: '개인정보처리방침',
                    onTap: () => _openExternalUrl(
                        'https://growtogether.kr/privacy'),
                  ),
                ]),
                const SizedBox(height: 14),

                _menuSection([
                  _MenuItem(
                    icon: Icons.logout_rounded,
                    label: '로그아웃',
                    color: AppColors.primary,
                    onTap: () => _logout(context, ref),
                  ),
                  _MenuItem(
                    icon: Icons.delete_outline_rounded,
                    label: '회원탈퇴',
                    color: AppColors.error,
                    onTap: () => _deleteAccount(context, ref),
                  ),
                ]),
                const SizedBox(height: 18),
                const _VersionFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuSection(List<_MenuItem> items) {
    return GlassCard(
      radius: 20,
      padding: EdgeInsets.zero,
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Column(
            children: [
              InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.vertical(
                  top: index == 0 ? const Radius.circular(20) : Radius.zero,
                  bottom: index == items.length - 1
                      ? const Radius.circular(20)
                      : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 15),
                  child: Row(
                    children: [
                      Icon(item.icon,
                          size: 20, color: item.color ?? AppColors.ink700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.label,
                          style: AppTextStyles.body1.copyWith(
                            color: item.color ?? AppColors.ink900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          size: 20, color: AppColors.ink300),
                    ],
                  ),
                ),
              ),
              if (index < items.length - 1)
                const Divider(
                    height: 1, color: AppColors.divider, indent: 48, endIndent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _logout(BuildContext context, WidgetRef ref) async {
    var ok = false;
    await AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.scale,
      title: '로그아웃',
      desc: '정말로 로그아웃 하시겠습니까?',
      btnCancelText: '취소',
      btnOkText: '로그아웃',
      btnCancelOnPress: () {},
      btnOkOnPress: () => ok = true,
    ).show();
    if (ok) {
      await ref.read(authProvider.notifier).logout();
      if (context.mounted) context.go('/login');
    }
  }

  void _deleteAccount(BuildContext context, WidgetRef ref) async {
    var ok = false;
    await AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      animType: AnimType.scale,
      title: '회원탈퇴',
      desc:
          '정말로 탈퇴하시겠습니까?\n탈퇴 후 30일간 데이터가 보관되며, 이후 완전히 삭제됩니다.',
      btnCancelText: '취소',
      btnOkText: '탈퇴',
      btnOkColor: AppColors.error,
      btnCancelOnPress: () {},
      btnOkOnPress: () => ok = true,
    ).show();
    if (ok) {
      try {
        await ref.read(authRepositoryProvider).deleteAccount(null);
        ref.read(authProvider.notifier).setUnauthenticated();
        if (context.mounted) context.go('/login');
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_deleteErrorMessage(e)),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          );
        }
      }
    }
  }

  /// 등록된 아이의 프로필 사진을 갤러리에서 다시 골라 교체한다.
  void _editChildPhoto(
      BuildContext context, WidgetRef ref, Child child) async {
    final messenger = ScaffoldMessenger.of(context);
    final img = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      imageQuality: 85,
    );
    if (img == null) return;

    try {
      final photoUrl =
          await ref.read(authRepositoryProvider).uploadImage(img.path);
      await ref.read(authProvider.notifier).updateChild(
            childId: child.id,
            photoUrl: photoUrl,
          );
      messenger.showSnackBar(
        const SnackBar(
          content: Text('아이 사진을 변경했습니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('사진 변경에 실패했습니다'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }
}

/// 탈퇴 실패 시 서버가 내려준 사유 메시지를 추출한다.
/// (예: '진행 중인 모임이 있어 탈퇴할 수 없습니다')
String _deleteErrorMessage(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map) {
      final error = data['error'];
      if (error is Map && error['message'] is String) {
        return error['message'] as String;
      }
      if (data['message'] is String) return data['message'] as String;
    }
  }
  return '탈퇴 처리에 실패했습니다';
}

String _familyHash(String? id) {
  if (id == null || id.isEmpty) return '0000';
  final h = id.hashCode.abs().toRadixString(16).toUpperCase();
  return h.length >= 4 ? h.substring(0, 4) : h.padLeft(4, '0');
}

class _MenuItem {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  _MenuItem({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });
}

/// 마이페이지 하단 버전/빌드 번호 표시.
/// 20회 탭하면 디버그 데이터 뷰어로 진입한다.
class _VersionFooter extends StatefulWidget {
  const _VersionFooter();

  @override
  State<_VersionFooter> createState() => _VersionFooterState();
}

class _VersionFooterState extends State<_VersionFooter> {
  static const int _unlockTapCount = 20;
  PackageInfo? _info;
  int _tapCount = 0;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((v) {
      if (!mounted) return;
      setState(() => _info = v);
    });
  }

  void _onTap() {
    _tapCount += 1;
    if (_tapCount >= _unlockTapCount) {
      _tapCount = 0;
      context.push('/debug-data');
      return;
    }
    final remain = _unlockTapCount - _tapCount;
    // 후반부에만 카운트다운을 노출 — 호기심을 자극하되 평소엔 조용히.
    if (remain <= 5) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('$remain번 더'),
            duration: const Duration(milliseconds: 600),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final label = info == null
        ? '버전 정보 로딩 중...'
        : '${AppConstants.appName}  v${info.version} (build ${info.buildNumber})';
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(color: AppColors.ink500),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

Future<void> _openExternalUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// 쑥쑥 등급 + 노쇼 레벨 한 줄.
class _GrowthRow extends StatelessWidget {
  final double score;
  final String? noShowLevel;

  const _GrowthRow({required this.score, this.noShowLevel});

  @override
  Widget build(BuildContext context) {
    final info = GrowthGradeInfo.fromScore(score);
    return Row(
      children: [
        Text(info.emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 4),
        Text(
          '쑥쑥 ${info.label}',
          style: AppTextStyles.captionBold.copyWith(color: info.color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: info.progressToNext,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.6),
              valueColor: AlwaysStoppedAnimation<Color>(info.color),
            ),
          ),
        ),
        if (_noShowLabel(noShowLevel) != null) ...[
          const SizedBox(width: 8),
          Text(
            _noShowLabel(noShowLevel)!,
            style: AppTextStyles.caption.copyWith(color: AppColors.ink500),
          ),
        ],
      ],
    );
  }

  static String? _noShowLabel(String? level) {
    switch (level) {
      case 'OCCASIONAL':
        return '노쇼 가끔';
      case 'FREQUENT':
        return '노쇼 잦음';
      default:
        return null;
    }
  }
}
