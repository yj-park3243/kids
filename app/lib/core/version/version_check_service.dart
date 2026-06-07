import 'dart:async';
import 'dart:io' show Platform;

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/api_constants.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../location/location_service.dart';
import '../network/api_client.dart';

class VersionCheckService {
  VersionCheckService._();

  static bool _shown = false;

  /// 서버 부트스트랩 응답 — 가입 시 KCP 본인인증 우회 여부(앱 심사 모드).
  /// 서버 응답 전/실패 시엔 false (안전하게 인증 진행).
  static bool bypassPhoneVerification = false;

  /// 광고 노출 여부. 서버 응답 전/없으면 true (기존 동작 = 광고 켜짐).
  static bool showAd = true;

  /// 첫 프레임 이후 호출. 강제/선택 업데이트가 필요하면 다이얼로그/오버레이를 띄움.
  static Future<void> check(BuildContext context) async {
    if (_shown) return;

    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version.isEmpty ? '0.0.0' : info.version;
      final platform = Platform.isIOS ? 'IOS' : 'ANDROID';

      // 위치 권한이 이미 허용된 경우에만 좌표를 실어 보낸다 (시작 시 권한 팝업 X).
      final coords = await _resolveCoords();

      final response = await ApiClient.instance.get(
        ApiConstants.appVersion,
        queryParameters: {
          'platform': platform,
          'appVersion': current,
          if (coords != null) 'lat': coords.$1.toString(),
          if (coords != null) 'lng': coords.$2.toString(),
        },
      );
      final data = (response.data is Map && response.data['data'] != null)
          ? response.data['data'] as Map
          : response.data as Map;

      final minVersion = (data['minVersion'] as String?) ?? '0.0.0';
      final latestVersion = (data['latestVersion'] as String?) ?? current;
      final forceUpdate = (data['forceUpdate'] as bool?) ?? false;
      final updateMessage = data['updateMessage'] as String?;
      final storeUrl = data['storeUrl'] as String?;
      // 서버에 필드가 없으면(옛 서버) 안전하게 false — 인증 진행.
      bypassPhoneVerification =
          (data['bypassPhoneVerification'] as bool?) ?? false;
      // 서버에 없으면(옛 서버) 광고 켜둠 — 기존 동작 유지.
      showAd = (data['showAd'] as bool?) ?? true;

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

  /// 위치 권한이 이미 허용돼 있으면 (위도, 경도) 반환, 아니면 null.
  /// 시작 시 권한 팝업을 띄우지 않기 위해 권한 요청은 하지 않는다.
  static Future<(double, double)?> _resolveCoords() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm != LocationPermission.always &&
          perm != LocationPermission.whileInUse) {
        return null;
      }
      final pos = await LocationService.instance.getCurrentPosition();
      if (pos == null) return null;
      return (pos.latitude, pos.longitude);
    } catch (_) {
      return null;
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
    AwesomeDialog(
      context: context,
      dialogType: DialogType.info,
      animType: AnimType.scale,
      title: '업데이트 안내',
      desc: message ?? '새 버전이 있어요. 더 나은 경험을 위해 업데이트해 주세요.',
      btnCancelText: '나중에',
      btnOkText: '업데이트',
      btnCancelOnPress: () {},
      btnOkOnPress: () => _openStore(storeUrl),
    ).show();
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
