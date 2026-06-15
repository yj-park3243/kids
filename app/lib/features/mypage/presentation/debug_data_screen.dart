import '../../../widgets/top_toast.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/storage/secure_storage.dart';
import '../../auth/providers/auth_provider.dart';

/// 마이페이지 버전 영역을 20회 탭하면 진입하는 디버그 데이터 뷰어.
/// 현재 앱이 보유한 사용자/토큰/환경/광고 식별자 등을 한 화면에 펼친다.
/// 광고 한 개를 함께 노출한다.
class DebugDataScreen extends ConsumerStatefulWidget {
  const DebugDataScreen({super.key});

  @override
  ConsumerState<DebugDataScreen> createState() => _DebugDataScreenState();
}

class _DebugDataScreenState extends ConsumerState<DebugDataScreen> {
  PackageInfo? _packageInfo;
  String? _accessToken;
  String? _refreshToken;
  bool _onboardingComplete = false;

  NativeAd? _ad;
  bool _adLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _loadAd();
  }

  Future<void> _loadAll() async {
    final info = await PackageInfo.fromPlatform();
    final at = await SecureStorage.getAccessToken();
    final rt = await SecureStorage.getRefreshToken();
    final ob = await SecureStorage.isOnboardingComplete();
    if (!mounted) return;
    setState(() {
      _packageInfo = info;
      _accessToken = at;
      _refreshToken = rt;
      _onboardingComplete = ob;
    });
  }

  void _loadAd() {
    _ad = NativeAd(
      adUnitId: AppConstants.nativeAdUnitId,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        mainBackgroundColor: Colors.white,
        cornerRadius: 16,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: AppColors.primary,
        ),
        primaryTextStyle: NativeTemplateTextStyle(textColor: AppColors.ink700),
        secondaryTextStyle:
            NativeTemplateTextStyle(textColor: AppColors.ink500),
      ),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _adLoaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) setState(() => _ad = null);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final info = _packageInfo;

    final appRows = <_KV>[
      _KV('appName', info?.appName ?? '-'),
      _KV('packageName', info?.packageName ?? '-'),
      _KV('version', info?.version ?? '-'),
      _KV('buildNumber', info?.buildNumber ?? '-'),
      _KV('platform', Platform.operatingSystem),
      _KV('osVersion', Platform.operatingSystemVersion),
    ];

    final envRows = <_KV>[
      _KV('apiUrl', ApiConstants.apiUrl),
      _KV('baseUrl', ApiConstants.baseUrl),
      _KV('chatWsUrl', ApiConstants.chatWsUrl),
      _KV('nativeAdUnitId', AppConstants.nativeAdUnitId),
      _KV('naverMapClientId', AppConstants.naverMapClientId),
      _KV('kakaoNativeAppKey', _maskKey(AppConstants.kakaoNativeAppKey)),
    ];

    final authRows = <_KV>[
      _KV('authStatus', authState.status.name),
      _KV('onboardingComplete', _onboardingComplete.toString()),
      _KV('accessToken', _maskToken(_accessToken)),
      _KV('refreshToken', _maskToken(_refreshToken)),
    ];

    final userRows = <_KV>[
      _KV('id', user?.id ?? '-'),
      _KV('nickname', user?.nickname ?? '-'),
      _KV('email', user?.email ?? '-'),
      _KV('status', user?.status ?? '-'),
      _KV('mannerScore', user?.mannerScore.toString() ?? '-'),
      _KV('noShowLevel', user?.noShowLevel ?? '-'),
      _KV('regionSigungu', user?.regionSigungu ?? '-'),
      _KV('parentGender', user?.parentGender ?? '-'),
      _KV('authProvider', user?.authProvider ?? '-'),
      _KV('profileImageUrl', user?.profileImageUrl ?? '-'),
      _KV('childrenCount', (user?.children?.length ?? 0).toString()),
    ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('디버그 데이터'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink900,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _section('앱', appRows),
          _section('환경', envRows),
          _section('인증', authRows),
          _section('현재 사용자', userRows),
          if (user?.children != null && user!.children!.isNotEmpty)
            _childrenSection(user.children!),
          const SizedBox(height: 16),
          _adBlock(),
          const SizedBox(height: 16),
          _rawJsonBlock(user),
        ],
      ),
    );
  }

  Widget _section(String title, List<_KV> rows) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.body1Bold),
          const SizedBox(height: 8),
          ...rows.map(_kvRow),
        ],
      ),
    );
  }

  Widget _kvRow(_KV kv) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        onLongPress: () => _copy(kv.v),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(
                kv.k,
                style: AppTextStyles.caption.copyWith(color: AppColors.ink500),
              ),
            ),
            Expanded(
              child: SelectableText(
                kv.v,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.ink900,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _childrenSection(List children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('등록된 아이 (${children.length})',
              style: AppTextStyles.body1Bold),
          const SizedBox(height: 8),
          ...children.asMap().entries.map((e) {
            final c = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('#${e.key + 1}',
                      style: AppTextStyles.captionBold
                          .copyWith(color: AppColors.primary700)),
                  _kvRow(_KV('id', c.id ?? '-')),
                  _kvRow(_KV('nickname', c.nickname ?? '-')),
                  _kvRow(_KV('gender', c.gender ?? '-')),
                  _kvRow(_KV('birthYear', c.birthYear?.toString() ?? '-')),
                  _kvRow(_KV('birthMonth', c.birthMonth?.toString() ?? '-')),
                  _kvRow(_KV('ageMonths', c.ageMonths?.toString() ?? '-')),
                  _kvRow(_KV('photoUrl', c.photoUrl ?? '-')),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _adBlock() {
    final ad = _ad;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('광고', style: AppTextStyles.body1Bold),
          const SizedBox(height: 8),
          if (ad == null || !_adLoaded)
            Container(
              height: 90,
              alignment: Alignment.center,
              child: Text(
                ad == null ? '광고 로드 실패' : '광고 로딩 중...',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.ink500),
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(minHeight: 90, maxHeight: 120),
                child: AdWidget(ad: ad),
              ),
            ),
        ],
      ),
    );
  }

  Widget _rawJsonBlock(dynamic user) {
    String body = '-';
    try {
      if (user != null) {
        body = const JsonEncoder.withIndent('  ').convert(user.toJson());
      }
    } catch (_) {
      body = user?.toString() ?? '-';
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111418),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('User JSON',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
              const Spacer(),
              InkWell(
                onTap: () => _copy(body),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.copy_rounded,
                      size: 16, color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            body,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontFamily: 'monospace',
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  void _copy(String value) {
    Clipboard.setData(ClipboardData(text: value));
    showTopToast(context, '복사했습니다');
  }

  String _maskToken(String? t) {
    if (t == null || t.isEmpty) return '-';
    if (t.length <= 16) return t;
    return '${t.substring(0, 8)}...${t.substring(t.length - 8)} (len=${t.length})';
  }

  String _maskKey(String k) {
    if (k.isEmpty) return '-';
    if (k.startsWith('TODO_')) return k;
    if (k.length <= 8) return k;
    return '${k.substring(0, 4)}...${k.substring(k.length - 4)}';
  }
}

class _KV {
  final String k;
  final String v;
  _KV(this.k, this.v);
}
