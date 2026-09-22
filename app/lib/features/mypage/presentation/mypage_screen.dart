import '../../../widgets/top_toast.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/user.dart';
import '../../../widgets/design/avatar.dart';
import '../../../widgets/design/design_chip.dart';
import '../../../widgets/design/glass_card.dart';
import '../../../widgets/design/notebook.dart';
import '../../../widgets/design/primary_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../../review/presentation/widgets/growth_grade.dart';

class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            // 앱바 — 제목 + 알림.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
              child: Row(
                children: [
                  Expanded(child: Text('마이', style: AppTextStyles.screenTitle)),
                  GlassIconButton(
                    icon: Icons.notifications_none_rounded,
                    iconColor: AppColors.ink,
                    onTap: () => context.push('/notifications'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 계정 정지 배너 — SUSPENDED 계정만 노출.
                    if (user?.status == 'SUSPENDED') ...[
                      _SuspendedBanner(onTap: () => context.push('/appeal')),
                      const SizedBox(height: 14),
                    ],

                    _ProfileHeader(user: user),
                    const SizedBox(height: 4),

                    if (user != null) _GrowthCard(user: user),

                    const SectionHeader(title: '우리 아이'),
                    _ChildrenRow(children: user?.children ?? const []),

                    const SectionHeader(title: '활동'),
                    _MenuGroup(
                      items: [
                        _MenuItem(
                          icon: Icons.favorite_border_rounded,
                          label: '단골 부모',
                          onTap: () => context.push('/follow/following'),
                        ),
                      ],
                    ),

                    const SectionHeader(title: '설정'),
                    _MenuGroup(
                      items: [
                        _MenuItem(
                          icon: Icons.edit_rounded,
                          label: '프로필 수정',
                          onTap: () => context.push('/profile-edit'),
                        ),
                        _MenuItem(
                          icon: Icons.notifications_none_rounded,
                          label: '알림 설정',
                          onTap: () => context.push('/notification-settings'),
                        ),
                        // 인증을 마쳤으면 값만 보여주고 더 갈 곳이 없다.
                        if (user?.isPhoneVerified ?? false)
                          _MenuItem(
                            icon: Icons.lock_outline_rounded,
                            label: '본인 인증',
                            value: '완료',
                            valueColor: AppColors.sageInk,
                          )
                        else
                          _MenuItem(
                            icon: Icons.lock_outline_rounded,
                            label: '본인 인증',
                            value: '필요',
                            onTap: () => context.push('/phone-verification'),
                          ),
                        _MenuItem(
                          icon: Icons.block_rounded,
                          label: '차단한 유저',
                          onTap: () => context.push('/blocked-users'),
                        ),
                      ],
                    ),

                    const SectionHeader(title: '고객센터'),
                    _MenuGroup(
                      items: [
                        _MenuItem(
                          icon: Icons.campaign_outlined,
                          label: '공지사항',
                          onTap: () => context.push('/notices'),
                        ),
                        _MenuItem(
                          icon: Icons.mail_outline_rounded,
                          label: '1:1 문의',
                          onTap: () => context.push('/inquiries'),
                        ),
                        _MenuItem(
                          icon: Icons.description_outlined,
                          label: '이용약관',
                          onTap: () =>
                              _openExternalUrl('https://growtogether.kr/terms'),
                        ),
                        _MenuItem(
                          icon: Icons.privacy_tip_outlined,
                          label: '개인정보처리방침',
                          onTap: () => _openExternalUrl(
                            'https://growtogether.kr/privacy',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    _MenuGroup(
                      items: [
                        _MenuItem(
                          icon: Icons.logout_rounded,
                          label: '로그아웃',
                          color: AppColors.bad,
                          onTap: () => _logout(context, ref),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _VersionFooter(
                      onDeleteAccount: () => _deleteAccount(context, ref),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
      desc: '정말로 탈퇴하시겠습니까?\n탈퇴 후 30일간 데이터가 보관되며, 이후 완전히 삭제됩니다.',
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
          showTopToast(
            context,
            _deleteErrorMessage(e),
            backgroundColor: AppColors.error,
          );
        }
      }
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

Future<void> _openExternalUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// 정지된 계정에만 뜨는 안내 — 탭하면 이의신청 화면으로.
class _SuspendedBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _SuspendedBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bad.withValues(alpha: 0.08),
          borderRadius: AppRadius.rMd,
          border: Border.all(color: AppColors.bad.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.gpp_bad_rounded, color: AppColors.bad, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '계정이 정지되었습니다. 탭하여 정지 해제를 요청하세요.',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.bad,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.bad,
            ),
          ],
        ),
      ),
    );
  }
}

/// 아바타 · 닉네임 · 가족 코드 · 편집.
class _ProfileHeader extends StatelessWidget {
  final User? user;

  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final region = [
      user?.regionSigungu,
      user?.regionDong,
    ].whereType<String>().where((v) => v.isNotEmpty).join(' ');
    final subtitle = region.isEmpty
        ? '#KIDS-${_familyHash(user?.id)}'
        : '#KIDS-${_familyHash(user?.id)} · $region';

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 16),
      child: Row(
        children: [
          InitialAvatar(
            label: user?.nickname ?? '?',
            size: 56,
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
                  style: AppTextStyles.screenTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GlassButton(
            text: '편집',
            compact: true,
            onPressed: () => context.push('/profile-edit'),
          ),
        ],
      ),
    );
  }
}

/// 쑥쑥 등급 카드 — 등급 pill · 다음 단계까지 남은 점수 · 진행바 · 5단계 눈금.
class _GrowthCard extends StatelessWidget {
  final User user;

  const _GrowthCard({required this.user});

  static const _stages = ['새싹', '떡잎', '어린나무', '큰나무', '숲'];

  @override
  Widget build(BuildContext context) {
    final info = GrowthGradeInfo.fromScore(user.mannerScore);
    final stageIndex = GrowthStage.values.indexOf(info.stage);
    final remain = (info.nextThreshold - user.mannerScore).ceil();
    final nextLabel = stageIndex + 1 < _stages.length
        ? _stages[stageIndex + 1]
        : null;

    // 받은 후기 상세는 당분간 닫아 둔다 — 카드는 탭해도 이동하지 않는다.
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Pill(
                label: '${info.emoji} 쑥쑥 ${info.label}',
                // 강등 단계(새싹)는 초록을 빼고 회색으로 — growth_grade 와 같은 규칙.
                tone: info.isDemoted ? PillTone.muted : PillTone.sage,
              ),
              const Spacer(),
              if (nextLabel != null && remain > 0)
                Text.rich(
                  TextSpan(
                    style: AppTextStyles.caption,
                    children: [
                      TextSpan(text: '$nextLabel까지 '),
                      TextSpan(
                        text: '$remain',
                        style: AppTextStyles.hand.copyWith(fontSize: 17),
                      ),
                      const TextSpan(text: '점'),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 8,
              color: AppColors.fill,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: info.progressToNext.clamp(0.0, 1.0),
                child: Container(color: info.color),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < _stages.length; i++)
                Expanded(
                  child: Text(
                    _stages[i],
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10.5,
                      color: i == stageIndex ? info.color : AppColors.ink3,
                      fontWeight: i == stageIndex
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                _noShowLabel(user.noShowLevel),
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _noShowLabel(String? level) {
    switch (level) {
      case 'OCCASIONAL':
        return '노쇼 가끔';
      case 'FREQUENT':
        return '노쇼 잦음';
      default:
        return '노쇼 없음';
    }
  }
}

/// 아이 알약 칩 목록 + '아이 추가' 점선 알약.
class _ChildrenRow extends StatelessWidget {
  final List<Child> children;

  const _ChildrenRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final child in children)
          _ChildPill(
            child: child,
            onTap: () => context.push('/children/${child.id}/edit'),
          ),
        DashedBox(
          radius: 999,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          onTap: () => context.push('/child-add'),
          child: SizedBox(
            height: 40,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, size: 16, color: AppColors.ink2),
                const SizedBox(width: 6),
                Text(
                  '아이 추가',
                  style: AppTextStyles.body2.copyWith(fontSize: 13.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChildPill extends StatelessWidget {
  final Child child;
  final VoidCallback onTap;

  const _ChildPill({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final months =
        child.ageMonths ??
        AppDateUtils.calculateAgeMonths(child.birthYear, child.birthMonth);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 40,
        padding: const EdgeInsets.only(left: 6, right: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InitialAvatar(
              label: child.nickname,
              size: 28,
              tone: InitialAvatar.toneFor(child.id),
              imageUrl: child.photoUrl,
            ),
            const SizedBox(width: 8),
            if (months < 0)
              Text(
                '${child.nickname} 출산예정',
                style: AppTextStyles.body2.copyWith(fontSize: 13.5),
              )
            else
              Text.rich(
                TextSpan(
                  style: AppTextStyles.body2.copyWith(fontSize: 13.5),
                  children: [
                    TextSpan(text: '${child.nickname} '),
                    TextSpan(
                      text: '$months',
                      style: AppTextStyles.handLg.copyWith(
                        color: AppColors.skyInk,
                      ),
                    ),
                    const TextSpan(text: '개월'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String? value;
  final Color? valueColor;
  final Color? color;
  final VoidCallback? onTap;

  _MenuItem({
    required this.icon,
    required this.label,
    this.value,
    this.valueColor,
    this.color,
    this.onTap,
  });
}

/// 메뉴 묶음 — 흰 면 + 헤어라인, 행 사이 1px line.
class _MenuGroup extends StatelessWidget {
  final List<_MenuItem> items;

  const _MenuGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: AppColors.line),
            _row(items[i], first: i == 0, last: i == items.length - 1),
          ],
        ],
      ),
    );
  }

  Widget _row(_MenuItem item, {required bool first, required bool last}) {
    final fg = item.color ?? AppColors.ink;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.vertical(
          top: first ? const Radius.circular(AppRadius.md) : Radius.zero,
          bottom: last ? const Radius.circular(AppRadius.md) : Radius.zero,
        ),
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(item.icon, size: 20, color: item.color ?? AppColors.ink3),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: AppTextStyles.body1.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: fg,
                    ),
                  ),
                ),
                if (item.value != null)
                  Text(
                    item.value!,
                    style: AppTextStyles.caption.copyWith(
                      color: item.valueColor ?? AppColors.ink3,
                    ),
                  ),
                if (item.onTap != null) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.line2,
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

/// 마이페이지 하단 "버전 x.y.z · 회원탈퇴".
/// 버전 쪽을 20회 탭하면 디버그 데이터 뷰어로 진입한다.
class _VersionFooter extends StatefulWidget {
  final VoidCallback onDeleteAccount;

  const _VersionFooter({required this.onDeleteAccount});

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
    // 릴리스 빌드에서는 디버그 데이터 뷰어(토큰 등 노출) 진입을 완전 차단.
    if (kReleaseMode) return;
    _tapCount += 1;
    if (_tapCount >= _unlockTapCount) {
      _tapCount = 0;
      context.push('/debug-data');
      return;
    }
    final remain = _unlockTapCount - _tapCount;
    // 후반부에만 카운트다운을 노출 — 호기심을 자극하되 평소엔 조용히.
    if (remain <= 5) {
      showTopToast(context, '$remain번 더');
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final label = info == null
        ? '버전 정보 로딩 중...'
        : '버전 ${info.version} (${info.buildNumber})';
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Text(label, style: AppTextStyles.caption),
            ),
          ),
          Text('·', style: AppTextStyles.caption),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onDeleteAccount,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Text('회원탈퇴', style: AppTextStyles.caption),
            ),
          ),
        ],
      ),
    );
  }
}
