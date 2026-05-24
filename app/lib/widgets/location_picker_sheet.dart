import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';
import 'common_button.dart';

/// 사용자가 지도에서 핀으로 선택한 위치.
class PickedLocation {
  PickedLocation({required this.lat, required this.lng, required this.label});
  final double lat;
  final double lng;
  final String label;
}

/// 풀스크린 모달로 NaverMap 을 띄우고, 카메라 중심을 고정 핀으로 잡아 좌표를 보정.
/// 방 생성 시 주소 검색 후 정확 위치 지정, 채팅에서 위치 전송 둘 다 재사용.
Future<PickedLocation?> showLocationPickerSheet(
  BuildContext context, {
  required double initialLat,
  required double initialLng,
  String title = '위치 선택',
  String label = '',
}) {
  return Navigator.of(context, rootNavigator: true).push<PickedLocation>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _LocationPickerScreen(
        initialLat: initialLat,
        initialLng: initialLng,
        title: title,
        initialLabel: label,
      ),
    ),
  );
}

class _LocationPickerScreen extends StatefulWidget {
  const _LocationPickerScreen({
    required this.initialLat,
    required this.initialLng,
    required this.title,
    required this.initialLabel,
  });

  final double initialLat;
  final double initialLng;
  final String title;
  final String initialLabel;

  @override
  State<_LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<_LocationPickerScreen> {
  late double _lat = widget.initialLat;
  late double _lng = widget.initialLng;
  NaverMapController? _controller;
  late final TextEditingController _labelController =
      TextEditingController(text: widget.initialLabel);

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _syncCenter() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    final pos = await ctrl.getCameraPosition();
    if (!mounted) return;
    setState(() {
      _lat = pos.target.latitude;
      _lng = pos.target.longitude;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.title, style: AppTextStyles.sectionHead),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.ink900),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              '지도를 움직여 정확한 위치에 핀을 맞춰주세요',
              style: AppTextStyles.caption,
            ),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                NaverMap(
                  options: NaverMapViewOptions(
                    initialCameraPosition: NCameraPosition(
                      target: NLatLng(widget.initialLat, widget.initialLng),
                      zoom: 16,
                    ),
                    logoClickEnable: false,
                  ),
                  onMapReady: (controller) => _controller = controller,
                  // 카메라가 멈출 때마다 중심 좌표를 _lat/_lng 에 동기화.
                  onCameraIdle: _syncCenter,
                ),
                // 중앙 고정 핀.
                IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Icon(
                      Icons.location_on,
                      size: 44,
                      color: AppColors.primary,
                      shadows: const [
                        Shadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  TextField(
                    controller: _labelController,
                    style: AppTextStyles.body1,
                    decoration: InputDecoration(
                      hintText: '장소 이름 (예: ○○ 놀이터 정문)',
                      hintStyle:
                          AppTextStyles.body1.copyWith(color: AppColors.ink300),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    text: '이 위치로 선택',
                    onPressed: () {
                      Navigator.of(context).pop(
                        PickedLocation(
                          lat: _lat,
                          lng: _lng,
                          label: _labelController.text.trim(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
