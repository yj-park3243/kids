import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../auth/providers/auth_provider.dart';

class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text('마이페이지', style: AppTextStyles.heading1),
              const SizedBox(height: 24),

              // Profile Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.surfaceVariant,
                      backgroundImage: user?.profileImageUrl != null
                          ? NetworkImage(user!.profileImageUrl!)
                          : null,
                      child: user?.profileImageUrl == null
                          ? const Icon(Icons.person_rounded,
                              size: 40, color: AppColors.textHint)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user?.nickname ?? '사용자',
                      style: AppTextStyles.heading3,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${user?.regionSigungu ?? ''} ${user?.regionDong ?? ''}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Children info
              if (user?.children != null && user!.children!.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('우리 아이', style: AppTextStyles.body1Bold),
                      const SizedBox(height: 12),
                      ...user.children!.map((child) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.child_care_rounded,
                                      size: 20, color: AppColors.accentDark),
                                ),
                                const SizedBox(width: 12),
                                Text(child.nickname,
                                    style: AppTextStyles.body2Bold),
                                const SizedBox(width: 8),
                                Text(
                                  AppDateUtils.formatAgeMonths(
                                      child.ageMonths ??
                                          AppDateUtils.calculateAgeMonths(
                                              child.birthYear,
                                              child.birthMonth)),
                                  style: AppTextStyles.caption
                                      .copyWith(color: AppColors.secondary),
                                ),
                                if (child.gender != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    child.gender == 'MALE' ? '남아' : '여아',
                                    style: AppTextStyles.caption,
                                  ),
                                ],
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Menu items
              _buildMenuSection([
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
              const SizedBox(height: 16),

              _buildMenuSection([
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
              const SizedBox(height: 16),

              _buildMenuSection([
                _MenuItem(
                  icon: Icons.logout_rounded,
                  label: '로그아웃',
                  color: AppColors.textSecondary,
                  onTap: () => _logout(context, ref),
                ),
                _MenuItem(
                  icon: Icons.delete_outline_rounded,
                  label: '회원탈퇴',
                  color: AppColors.error,
                  onTap: () => _deleteAccount(context, ref),
                ),
              ]),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuSection(List<_MenuItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Column(
            children: [
              InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.vertical(
                  top: index == 0 ? const Radius.circular(16) : Radius.zero,
                  bottom: index == items.length - 1
                      ? const Radius.circular(16)
                      : Radius.zero,
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(item.icon,
                          size: 22,
                          color: item.color ?? AppColors.textPrimary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.label,
                          style: AppTextStyles.body2.copyWith(
                            color: item.color ?? AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          size: 20, color: AppColors.textHint),
                    ],
                  ),
                ),
              ),
              if (index < items.length - 1)
                const Divider(
                    height: 1, color: AppColors.divider, indent: 50),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                style: TextStyle(color: AppColors.primary)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            child:
                const Text('탈퇴', style: TextStyle(color: AppColors.error)),
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
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }
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
