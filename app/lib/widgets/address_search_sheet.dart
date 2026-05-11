import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';

/// Daum 우편번호 검색 결과.
class AddressResult {
  AddressResult({
    required this.sido,
    required this.sigungu,
    required this.dong,
    required this.roadAddress,
    required this.jibunAddress,
    required this.buildingName,
    required this.zonecode,
  });

  final String sido;
  final String sigungu;
  final String dong;
  final String roadAddress;
  final String jibunAddress;
  final String buildingName;
  final String zonecode;

  /// 도로명(있으면) + 건물명. 사용자에게 보여줄 가장 자세한 주소.
  String get fullAddress {
    final base = roadAddress.isNotEmpty ? roadAddress : jibunAddress;
    if (buildingName.isEmpty) return base;
    return '$base ($buildingName)';
  }
}

/// 하단 모달로 Daum 우편번호 위젯을 띄우고 결과를 반환.
Future<AddressResult?> showAddressSearchSheet(BuildContext context) {
  return showModalBottomSheet<AddressResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _AddressSearchSheet(),
  );
}

class _AddressSearchSheet extends StatefulWidget {
  const _AddressSearchSheet();

  @override
  State<_AddressSearchSheet> createState() => _AddressSearchSheetState();
}

class _AddressSearchSheetState extends State<_AddressSearchSheet> {
  WebViewController? _controller;
  bool _loading = true;

  // JS 채널 이름. daum 라이브러리의 식별자와 충돌하지 않게 prefix.
  static const _channel = 'KidsPostcode';

  static const _html = '''
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
  <style>
    html, body { margin: 0; padding: 0; height: 100%; background: #fff; }
    #layer { width: 100%; height: 100%; }
  </style>
</head>
<body>
  <div id="layer"></div>
  <script src="https://t1.daumcdn.net/mapjsapi/bundle/postcode/prod/postcode.v2.js"></script>
  <script>
    function postBack(payload) {
      try {
        window.KidsPostcode.postMessage(JSON.stringify(payload));
      } catch (e) {
        // 채널 미등록 등으로 실패하면 무시 (가시 진단을 위해 alert 대신 console)
        console.error('postBack failed', e);
      }
    }
    function start() {
      if (!window.daum || !window.daum.Postcode) {
        setTimeout(start, 100);
        return;
      }
      new daum.Postcode({
        width: '100%',
        height: '100%',
        oncomplete: function(data) {
          postBack({
            sido: data.sido || '',
            sigungu: data.sigungu || '',
            dong: data.bname || data.bname1 || '',
            roadAddress: data.roadAddress || '',
            jibunAddress: data.jibunAddress || data.autoJibunAddress || '',
            buildingName: data.buildingName || '',
            zonecode: data.zonecode || ''
          });
        },
        onclose: function(state) {
          if (state === 'FORCE_CLOSE') postBack({ closed: true });
        }
      }).embed(document.getElementById('layer'));
    }
    start();
  </script>
</body>
</html>
''';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final controller = WebViewController();
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setBackgroundColor(AppColors.surface);
    await controller.addJavaScriptChannel(
      _channel,
      onMessageReceived: _onMessage,
    );
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ),
    );
    // baseUrl 을 명시해야 https 외부 스크립트(t1.daumcdn.net) 로딩이 안정적.
    // about:blank 컨텍스트에서는 cross-origin 정책으로 막히는 경우가 있음.
    await controller.loadHtmlString(
      _html,
      baseUrl: 'https://postcode.map.daum.net',
    );

    if (mounted) setState(() => _controller = controller);
  }

  void _onMessage(JavaScriptMessage msg) {
    final data = jsonDecode(msg.message) as Map<String, dynamic>;
    if (data['closed'] == true) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final result = AddressResult(
      sido: (data['sido'] as String?) ?? '',
      sigungu: (data['sigungu'] as String?) ?? '',
      dong: (data['dong'] as String?) ?? '',
      roadAddress: (data['roadAddress'] as String?) ?? '',
      jibunAddress: (data['jibunAddress'] as String?) ?? '',
      buildingName: (data['buildingName'] as String?) ?? '',
      zonecode: (data['zonecode'] as String?) ?? '',
    );
    if (mounted) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  Expanded(
                    child: Center(
                      child: Text('주소 검색', style: AppTextStyles.body1Bold),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: Stack(
                children: [
                  if (_controller != null)
                    WebViewWidget(controller: _controller!),
                  if (_loading)
                    const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
