import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/room.dart';
import '../../room/providers/room_detail_provider.dart';

const _seoulCity = NLatLng(37.5665, 126.9780);

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  NaverMapController? _controller;
  MapPin? _selectedPin;
  List<MapCluster> _clusters = [];
  List<MapPin> _pins = [];
  bool _isLoading = false;
  String _mode = 'CLUSTER';

  Future<void> _loadMapDataForCurrentRegion() async {
    final controller = _controller;
    if (controller == null) return;

    setState(() => _isLoading = true);
    try {
      final region = await controller.getContentBounds();
      final cameraPosition = await controller.getCameraPosition();
      final zoom = cameraPosition.zoom.round();

      final data = await ref.read(roomRepositoryProvider).getMapRooms(
            swLat: region.southWest.latitude,
            swLng: region.southWest.longitude,
            neLat: region.northEast.latitude,
            neLng: region.northEast.longitude,
            zoomLevel: zoom,
          );

      final mode = data['mode'] ?? 'CLUSTER';
      if (mode == 'CLUSTER') {
        _clusters = (data['clusters'] as List<dynamic>?)
                ?.map((e) => MapCluster.fromJson(e))
                .toList() ??
            [];
        _pins = [];
        _mode = 'CLUSTER';
      } else {
        _pins = (data['pins'] as List<dynamic>?)
                ?.map((e) => MapPin.fromJson(e))
                .toList() ??
            [];
        _clusters = [];
        _mode = 'PIN';
      }
      await _renderOverlays();
    } catch (_) {
      // 서버 미응답/네트워크 에러 시 빈 화면 유지
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _renderOverlays() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.clearOverlays();

    if (_mode == 'CLUSTER') {
      for (final c in _clusters) {
        final marker = NMarker(
          id: 'cluster-${c.regionDong}',
          position: NLatLng(c.latitude, c.longitude),
          caption: NOverlayCaption(text: '${c.regionDong} ${c.count}'),
        );
        await controller.addOverlay(marker);
      }
    } else {
      for (final p in _pins) {
        final marker = NMarker(
          id: 'pin-${p.id}',
          position: NLatLng(p.latitude, p.longitude),
          caption: NOverlayCaption(text: p.title),
        );
        marker.setOnTapListener((NMarker overlay) {
          setState(() => _selectedPin = p);
        });
        await controller.addOverlay(marker);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          NaverMap(
            options: const NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: _seoulCity,
                zoom: 12,
              ),
              mapType: NMapType.basic,
              locationButtonEnable: true,
            ),
            onMapReady: (controller) async {
              _controller = controller;
              await _loadMapDataForCurrentRegion();
            },
            onCameraIdle: () {
              _loadMapDataForCurrentRegion();
            },
            onMapTapped: (_, __) {
              if (_selectedPin != null) {
                setState(() => _selectedPin = null);
              }
            },
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded,
                      color: AppColors.textHint, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _mode == 'CLUSTER'
                        ? '동 단위 (${_clusters.length})'
                        : '핀 (${_pins.length})',
                    style: AppTextStyles.body2
                        .copyWith(color: AppColors.textHint),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '필터',
                      style: AppTextStyles.captionBold
                          .copyWith(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isLoading)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              right: 24,
              child: const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              ),
            ),

          if (_selectedPin != null)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => context.push('/rooms/${_selectedPin!.id}'),
                child: _PinCard(pin: _selectedPin!),
              ),
            ),
        ],
      ),
    );
  }
}

class _PinCard extends StatelessWidget {
  final MapPin pin;

  const _PinCard({required this.pin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(pin.title, style: AppTextStyles.body1Bold),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                AppDateUtils.formatDateTime(pin.date, pin.startTime),
                style: AppTextStyles.caption,
              ),
              const Spacer(),
              Text(
                '${pin.ageMonthMin}~${pin.ageMonthMax}개월',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.secondary),
              ),
              const SizedBox(width: 12),
              Text(
                '${pin.currentMembers}/${pin.maxMembers}명',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
