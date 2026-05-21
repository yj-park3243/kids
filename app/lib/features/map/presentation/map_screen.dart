import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/location/location_service.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/room.dart';
import '../../../providers/selected_child_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../room/providers/room_detail_provider.dart';
import '../map_filter.dart';
import '../widgets/map_filter_panel.dart';

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
  MapFilter _filter = const MapFilter();
  bool _filterInitialized = false;

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
            filters: _filter.toQuery(),
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
        if (!mounted) return;
        final icon = await NOverlayImage.fromWidget(
          widget: _ClusterMarker(cluster: c),
          size: const Size(96, 74),
          context: context,
        );
        final marker = NMarker(
          id: 'cluster-${c.regionDong}',
          position: NLatLng(c.latitude, c.longitude),
          icon: icon,
          size: const Size(96, 74),
          anchor: const NPoint(0.5, 0.5),
        );
        await controller.addOverlay(marker);
      }
    } else {
      for (final p in _pins) {
        if (!mounted) return;
        // 커스텀 핀 — 개월수 + 모집 인원이 한눈에 보이게 위젯을 이미지로.
        final icon = await NOverlayImage.fromWidget(
          widget: _PinMarker(pin: p),
          size: const Size(96, 66),
          context: context,
        );
        final marker = NMarker(
          id: 'pin-${p.id}',
          position: NLatLng(p.latitude, p.longitude),
          icon: icon,
          size: const Size(96, 66),
          anchor: const NPoint(0.5, 1.0),
        );
        marker.setOnTapListener((NMarker overlay) {
          setState(() => _selectedPin = p);
        });
        await controller.addOverlay(marker);
      }
    }
  }

  void _onFilterChanged(MapFilter next) {
    setState(() {
      _filter = next;
      _selectedPin = null;
    });
    _loadMapDataForCurrentRegion();
  }

  @override
  Widget build(BuildContext context) {
    // 최초 1회 — 선택된 아이 개월수를 연령 필터 기본값으로.
    final child = ref.watch(selectedChildProvider);
    if (!_filterInitialized && child != null) {
      _filterInitialized = true;
      final ageMonths = AppDateUtils.calculateAgeMonths(
          child.birthYear, child.birthMonth);
      _filter = MapFilter.initial(ageMonth: ageMonths);
    }

    // 거리 — 내 위치와 선택된 핀 사이. 참여 중인 방은 표시하지 않는다.
    final myPos = ref.watch(currentPositionProvider).valueOrNull;
    String? selectedDistance;
    final sel = _selectedPin;
    if (sel != null && !sel.joined && myPos != null) {
      selectedDistance = formatDistance(distanceKm(
          myPos.latitude, myPos.longitude, sel.latitude, sel.longitude));
    }

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
              // 내 위치로 카메라 이동 — 주변 모임이 화면에 들어오도록.
              // zoom 14 는 핀 모드(개월수·인원이 보이는 커스텀 마커).
              final pos =
                  await LocationService.instance.getCurrentPosition();
              if (pos != null && mounted) {
                await controller.updateCamera(
                  NCameraUpdate.withParams(
                    target: NLatLng(pos.latitude, pos.longitude),
                    zoom: 14,
                  ),
                );
              }
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

          // 상단 필터 패널
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: MapFilterPanel(
              filter: _filter,
              childAgeMonth: _filter.ageMonth,
              onChanged: _onFilterChanged,
              isSingleParent:
                  ref.watch(authProvider).user?.isSingleParent == true,
            ),
          ),

          // 결과 개수 / 로딩
          Positioned(
            top: MediaQuery.of(context).padding.top + 64,
            right: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoading)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    )
                  else
                    Icon(
                      _mode == 'CLUSTER'
                          ? Icons.location_city_rounded
                          : Icons.place_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                  const SizedBox(width: 5),
                  Text(
                    _mode == 'CLUSTER'
                        ? '동 ${_clusters.length}곳'
                        : '모임 ${_pins.length}개',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),

          if (_selectedPin != null)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => context.push('/rooms/${_selectedPin!.id}'),
                child: _PinCard(
                  pin: _selectedPin!,
                  distanceText: selectedDistance,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// 모집 상태 색 — 여유(민트) / 임박(코랄) / 마감(회색).
Color _pinAccent(MapPin pin) {
  if (pin.isFull) return const Color(0xFF9AA0A6);
  final ratio =
      pin.maxMembers == 0 ? 0.0 : pin.currentMembers / pin.maxMembers;
  return ratio >= 0.8 ? AppColors.accentCoral : AppColors.primary;
}

/// 지도 위 커스텀 핀 — 흰 카드에 개월수 + 모집 인원, 모집 상태 색 액센트.
class _PinMarker extends StatelessWidget {
  final MapPin pin;

  const _PinMarker({required this.pin});

  @override
  Widget build(BuildContext context) {
    final accent = _pinAccent(pin);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent, width: 1.6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${pin.ageMonthMin}~${pin.ageMonthMax}개월',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 1),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_alt_rounded, size: 11, color: accent),
                  const SizedBox(width: 3),
                  Text(
                    '${pin.currentMembers}/${pin.maxMembers}',
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // 핀 꼬리 — 카드와 살짝 겹쳐 자연스럽게.
        Transform.translate(
          offset: const Offset(0, -1.5),
          child: CustomPaint(
            size: const Size(16, 9),
            painter: _TailPainter(accent),
          ),
        ),
      ],
    );
  }
}

/// 지도 클러스터 — 원형 카운트 배지 + 동 이름 칩.
class _ClusterMarker extends StatelessWidget {
  final MapCluster cluster;

  const _ClusterMarker({required this.cluster});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF7FDDD0), AppColors.primary],
            ),
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '${cluster.count}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 3,
              ),
            ],
          ),
          child: Text(
            cluster.regionDong,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _TailPainter extends CustomPainter {
  final Color color;
  _TailPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TailPainter oldDelegate) => oldDelegate.color != color;
}

/// 핀 선택 시 하단 카드 — 거리 포함.
class _PinCard extends StatelessWidget {
  final MapPin pin;
  final String? distanceText;

  const _PinCard({required this.pin, this.distanceText});

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
          Row(
            children: [
              Expanded(
                child: Text(
                  pin.title,
                  style: AppTextStyles.body1Bold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (distanceText != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.near_me_rounded,
                          size: 12, color: AppColors.primary),
                      const SizedBox(width: 3),
                      Text(
                        distanceText!,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
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
