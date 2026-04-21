import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../widgets/design/avatar.dart';
import '../../../widgets/design/baby_avatar.dart';
import '../../../widgets/design/design_chip.dart';
import '../../../widgets/design/glass_card.dart';
import '../../../widgets/design/pink_blobs.dart';
import '../../auth/providers/auth_provider.dart';

class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PinkBlobsBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('마이페이지', style: AppTextStyles.screenTitle),
                const SizedBox(height: 20),

                // Profile glass pink card
                GlassCard(
                  tone: GlassTone.pink,
                  radius: 24,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          InitialAvatar(
                            label: user?.nickname ?? '?',
                            size: 64,
                            tone: AvatarTone.pink,
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
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_rounded,
                                        size: 12, color: AppColors.ink500),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${user?.regionSigungu ?? ''} ${user?.regionDong ?? ''}',
                                      style: AppTextStyles.caption,
                                    ),
                                  ],
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
                                  color: AppColors.pink700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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
                        const SizedBox(height: 12),
                        ...user.children!.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final child = entry.value;
                          final age = child.ageMonths ??
                              AppDateUtils.calculateAgeMonths(
                                  child.birthYear, child.birthMonth);
                          return Padding(
                            padding: EdgeInsets.only(
                              top: idx == 0 ? 0 : 10,
                            ),
                            child: Row(
                              children: [
                                BabyAvatar(
                                  size: 40,
                                  tone: child.gender == 'MALE'
                                      ? BabyAvatarTone.blue
                                      : BabyAvatarTone.pink,
                                ),
                                const SizedBox(width: 12),
                                Text(child.nickname,
                                    style: AppTextStyles.body1Bold),
                                const SizedBox(width: 8),
                                Text(
                                  AppDateUtils.formatAgeMonths(age),
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.pink700,
                                  ),
                                ),
                                if (child.gender != null) ...[
                                  const SizedBox(width: 8),
                                  DesignChip(
                                    label:
                                        child.gender == 'MALE' ? '남아' : '여아',
                                    tone: child.gender == 'MALE'
                                        ? ChipTone.lilac
                                        : ChipTone.pinkGhost,
                                    height: 22,
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
                    icon: Icons.event_note_rounded,
                    label: '내 모임',
                    onTap: () => context.push('/my-rooms'),
                  ),
                  _MenuItem(
                    icon: Icons.edit_rounded,
                    label: '프로필 수정',
                    onTap: () => context.push('/profile-edit'),
                  ),
                  _MenuItem(
                    icon: Icons.notifications_none_rounded,
                    label: '알림 설정',
                    onTap: () {},
                  ),
                ]),
                const SizedBox(height: 14),

                _menuSection([
                  _MenuItem(
                    icon: Icons.help_outline_rounded,
                    label: '도움말',
                    onTap: () {},
                  ),
                  _MenuItem(
                    icon: Icons.description_outlined,
                    label: '이용약관',
                    onTap: () {},
                  ),
                  _MenuItem(
                    icon: Icons.privacy_tip_outlined,
                    label: '개인정보처리방침',
                    onTap: () {},
                  ),
                ]),
                const SizedBox(height: 14),

                _menuSection([
                  _MenuItem(
                    icon: Icons.logout_rounded,
                    label: '로그아웃',
                    color: AppColors.pink500,
                    onTap: () => _logout(context, ref),
                  ),
                  _MenuItem(
                    icon: Icons.delete_outline_rounded,
                    label: '회원탈퇴',
                    color: AppColors.error,
                    onTap: () => _deleteAccount(context, ref),
                  ),
                ]),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('로그아웃'),
        content: const Text('정말로 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('로그아웃',
                style: TextStyle(color: AppColors.pink500)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
      if (context.mounted) context.go('/login');
    }
  }

  void _deleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('회원탈퇴'),
        content: const Text(
          '정말로 탈퇴하시겠습니까?\n탈퇴 후 30일간 데이터가 보관되며, 이후 완전히 삭제됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('탈퇴', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(authRepositoryProvider).deleteAccount(null);
        ref.read(authProvider.notifier).setUnauthenticated();
        if (context.mounted) context.go('/login');
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('탈퇴 처리에 실패했습니다'),
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
