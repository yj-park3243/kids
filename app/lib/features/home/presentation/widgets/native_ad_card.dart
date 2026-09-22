import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/version/version_check_service.dart';

/// 홈 방 목록 피드에 끼워 넣는 네이티브 광고 카드.
/// 로딩 중이거나 로드에 실패하면 공간을 차지하지 않는다.
class NativeAdCard extends StatefulWidget {
  const NativeAdCard({super.key});

  @override
  State<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<NativeAdCard>
    with AutomaticKeepAliveClientMixin {
  NativeAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    // 서버에서 광고 OFF면 로드하지 않는다 (build 에서 SizedBox.shrink 반환).
    if (!VersionCheckService.showAd) return;
    _ad = NativeAd(
      adUnitId: AppConstants.nativeAdUnitId,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        mainBackgroundColor: AppColors.surface,
        cornerRadius: AppRadius.md,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: AppColors.ink,
        ),
        primaryTextStyle: NativeTemplateTextStyle(textColor: AppColors.ink),
        secondaryTextStyle: NativeTemplateTextStyle(textColor: AppColors.ink2),
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
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
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    // 흰 면 + 1px 헤어라인. 목록의 다른 행과 헷갈리지 않게 '광고' 라벨을 단다.
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.rMd,
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text('광고', style: AppTextStyles.caption),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 90, maxHeight: 120),
            child: AdWidget(ad: ad),
          ),
        ],
      ),
    );
  }
}
