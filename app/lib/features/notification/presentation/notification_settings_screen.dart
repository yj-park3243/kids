import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../widgets/app_bar.dart';

/// 푸시 알림 토글 페이지. 로컬 환경설정 저장만 함 — 실제 FCM topic
/// subscribe/unsubscribe 는 후속 작업.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  static const _storage = FlutterSecureStorage();
  static const _keyAll = 'noti_all';
  static const _keyRoom = 'noti_room';
  static const _keyChat = 'noti_chat';

  bool _all = true;
  bool _room = true;
  bool _chat = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _storage.read(key: _keyAll),
      _storage.read(key: _keyRoom),
      _storage.read(key: _keyChat),
    ]);
    if (!mounted) return;
    setState(() {
      _all = results[0] != 'false';
      _room = results[1] != 'false';
      _chat = results[2] != 'false';
      _loading = false;
    });
  }

  Future<void> _set(String key, bool v) async {
    await _storage.write(key: key, value: v ? 'true' : 'false');
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
                    title: '앱 알림 받기',
                    subtitle: '꺼두면 아래 알림이 모두 비활성화돼요',
                    value: _all,
                    onChanged: (v) {
                      setState(() => _all = v);
                      _set(_keyAll, v);
                    },
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  _tile(
                    title: '모임 알림',
                    subtitle: '참여 신청, 수락, 일정 변경 등',
                    value: _room,
                    enabled: _all,
                    onChanged: (v) {
                      setState(() => _room = v);
                      _set(_keyRoom, v);
                    },
                  ),
                  _tile(
                    title: '채팅 알림',
                    subtitle: '새 메시지 도착 알림',
                    value: _chat,
                    enabled: _all,
                    onChanged: (v) {
                      setState(() => _chat = v);
                      _set(_keyChat, v);
                    },
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
        value: enabled ? value : false,
        activeThumbColor: AppColors.primary,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}
