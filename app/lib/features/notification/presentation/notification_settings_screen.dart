import 'package:flutter/material.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_client.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/top_toast.dart';

/// 푸시 알림 토글 페이지. 서버(GET/PATCH /notifications/settings)에 저장되며,
/// 서버 sendPush 가 카테고리별로 발송을 게이팅한다.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  // 광고·이벤트 알림 수신(notifyAll 에 저장). 모임/채팅 알림은 항상 켜짐.
  bool _ads = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.get(ApiConstants.notificationSettings);
      final data = (res.data as Map?) ?? const {};
      if (!mounted) return;
      setState(() {
        _ads = data['notifyAll'] != false;
        _loading = false;
      });
    } catch (_) {
      // 조회 실패 — 기본값(전부 ON) 유지.
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// 토글 즉시 반영 + 서버 PATCH. 실패하면 이전 값으로 롤백.
  Future<void> _patch(
    String key,
    bool value,
    void Function(bool) apply,
    bool previous,
  ) async {
    setState(() => apply(value));
    try {
      await ApiClient.instance
          .patch(ApiConstants.notificationSettings, data: {key: value});
    } catch (_) {
      if (!mounted) return;
      setState(() => apply(previous));
      showTopToast(context, '설정 변경에 실패했어요. 다시 시도해주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: '알림 설정'),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                children: [
                  _tile(
                    title: '모임·채팅 알림',
                    subtitle: '참여 신청·수락·메시지 등 — 서비스 필수 알림이라 끌 수 없어요',
                    value: true,
                    enabled: false,
                    onChanged: (_) {},
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  _tile(
                    title: '광고·이벤트 알림',
                    subtitle: '새 기능, 이벤트, 혜택 소식',
                    value: _ads,
                    onChanged: (v) =>
                        _patch('notifyAll', v, (x) => _ads = x, _ads),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _tile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screen, vertical: AppSpacing.sm),
        title: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
          child: Text(title, style: AppTextStyles.body1Bold),
        ),
        subtitle: Text(
          subtitle,
          style: AppTextStyles.caption
              .copyWith(color: AppColors.textSecondary, height: 1.5),
        ),
        value: value,
        activeThumbColor: AppColors.primary,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}
