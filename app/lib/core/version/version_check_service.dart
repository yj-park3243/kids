import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../network/api_client.dart';

class VersionCheckService {
  VersionCheckService._();

  static bool _shown = false;

  /// 첫 프레임 이후 호출. 강제/선택 업데이트가 필요하면 다이얼로그/오버레이를 띄움.
  static Future<void> check(BuildContext context) async {
    if (_shown) return;

    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version.isEmpty ? '0.0.0' : info.version;
      final platform = Platform.isIOS ? 'IOS' : 'ANDROID';

      final response = await ApiClient.instance.get(
        '/app-version',
        queryParameters: {'platform': platform, 'appVersion': current},
      );
      final data = (response.data is Map && response.data['data'] != null)
          ? response.data['data'] as Map
          : response.data as Map;

      final minVersion = (data['minVersion'] as String?) ?? '0.0.0';
      final latestVersion = (data['latestVersion'] as String?) ?? current;
      final forceUpdate = (data['forceUpdate'] as bool?) ?? false;
      final updateMessage = data['updateMessage'] as String?;
      final storeUrl = data['storeUrl'] as String?;

      if (!context.mounted) return;

      // 1) 최소 버전 미달 또는 서버에서 forceUpdate 플래그 → 차단형 오버레이
      if (_isLower(current, minVersion) || forceUpdate) {
        _shown = true;
        _showForceUpdate(context, message: updateMessage, storeUrl: storeUrl);
        return;
      }

      // 2) 최신 버전 미달 → 선택 업데이트 다이얼로그
      if (_isLower(current, latestVersion)) {
        _shown = true;
        _showOptionalUpdate(context, message: updateMessage, storeUrl: storeUrl);
      }
    } catch (_) {
      // 버전 체크 실패 시 앱 동작을 막지 않음
    }
  }

  /// a < b 이면 true. semver 'x.y.z' 가정.
  static bool _isLower(String a, String b) {
    final ap = _parse(a);
    final bp = _parse(b);
    for (var i = 0; i < 3; i++) {
      if (ap[i] != bp[i]) return ap[i] < bp[i];
    }
    return false;
  }

  static List<int> _parse(String v) {
    final parts = v.split('.');
    return [
      _intOrZero(parts.isNotEmpty ? parts[0] : '0'),
      _intOrZero(parts.length > 1 ? parts[1] : '0'),
      _intOrZero(parts.length > 2 ? parts[2] : '0'),
    ];
  }

  static int _intOrZero(String s) {
    return int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  static Future<void> _openStore(String? storeUrl) async {
    if (storeUrl == null || storeUrl.isEmpty) return;
    final uri = Uri.parse(storeUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static void _showOptionalUpdate(
    BuildContext context, {
    String? message,
    String? storeUrl,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('업데이트 안내', style: AppTextStyles.heading3),
        content: Text(
          message ?? '새 버전이 있어요. 더 나은 경험을 위해 업데이트해 주세요.',
          style: AppTextStyles.body2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('나중에'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _openStore(storeUrl);
            },
            child: const Text('업데이트'),
          ),
        ],
      ),
    );
  }

  static void _showForceUpdate(
    BuildContext context, {
    String? message,
    String? storeUrl,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ForceUpdateOverlay(
        message: message,
        onUpdate: () => _openStore(storeUrl),
      ),
    );
    overlay.insert(entry);
  }
}

class _ForceUpdateOverlay extends StatelessWidget {
  const _ForceUpdateOverlay({required this.message, required this.onUpdate});

  final String? message;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.black.withValues(alpha: 0.85),
        child: SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.system_update_rounded,
                      size: 56, color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text('업데이트 필요', style: AppTextStyles.heading2),
                  const SizedBox(height: 12),
                  Text(
                    message ??
                        '꼭 필요한 업데이트가 있어요.\n스토어에서 최신 버전을 받아주세요.',
                    style: AppTextStyles.body2,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onUpdate,
                      child: const Text('업데이트하러 가기'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
