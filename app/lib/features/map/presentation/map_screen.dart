import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/location/location_service.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/room.dart';
import '../../../models/user.dart';
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
  // 같은 위치에 묶인 핀 묶음을 탭했을 때 표시 — 단일 핀(_selectedPin)과
  // 동일한 패턴으로 build 안에서 위젯으로 시트를 그린다.
  // platform view 위에서 showModalBottomSheet 을 호출할 때 가끔 modal 라우트가
  // 전혀 push 되지 않는 케이스가 있어 state 기반으로 통일.
  List<MapPin>? _selectedGroup;
  List<MapCluster> _clusters = [];
  List<MapPin> _pins = [];
  bool _isLoading = false;
  String _mode = 'CLUSTER';
  MapFilter _filter = const MapFilter();
  bool _filterInitialized = false;

  // 줌이 클러스터(≤11)/핀(≥12) 경계를 넘으면 자동 재조회 — 확대 시 클러스터가 풀리도록.
  Future<void> _onCameraIdle() async {
    final controller = _controller;
    if (controller == null || _isLoading) return;
    final zoom = (await controller.getCameraPosition()).zoom.round();
    final shouldBeCluster = zoom <= 11;
    if (shouldBeCluster != (_mode == 'CLUSTER')) {
      await _loadMapDataForCurrentRegion();
    }
  }

  Future<void> _loadMapDataForCurrentRegion() async {
    final controller = _controller;
    if (controller == null) return;

    setState(() => _isLoading = true);
    try {
      // 줌 레벨만 필요 — 클러스터/핀 모드 전환에 쓰인다. 뷰포트 인자는
      // 보내지 않는다("같이 놀자에 등록된 모든 방"을 한 번에 받는다).
      final cameraPosition = await controller.getCameraPosition();
      final zoom = cameraPosition.zoom.round();

      final data = await ref.read(roomRepositoryProvider).getMapRooms(
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
        final clusterPos = NLatLng(c.latitude, c.longitude);
        final marker = NMarker(
          id: 'cluster-${c.regionDong}',
          position: clusterPos,
          icon: icon,
          size: const Size(96, 74),
          anchor: const NPoint(0.5, 0.5),
        );
        // 클러스터 탭 → 줌인해서 개별 핀이 보이도록.
        marker.setOnTapListener((NMarker overlay) async {
          await controller.updateCamera(
            NCameraUpdate.withParams(target: clusterPos, zoom: 15),
          );
          // 줌인 후 핀 모드로 다시 받아온다 — 안 하면 클러스터가 안 풀린다.
          await _loadMapDataForCurrentRegion();
        });
        await controller.addOverlay(marker);
      }
    } else {
      // 같은 지점(~20m)에 여러 모임이 있으면 핀이 겹쳐 안 보이는 문제를 막기 위해
      // 좌표 격자로 그룹화 — 그룹 size>1 이면 스택 마커로 표시하고,
      // 탭하면 바텀시트로 그룹 안 모임을 골라볼 수 있게 한다.
      final groups = _groupNearbyPins(_pins);
      for (var gi = 0; gi < groups.length; gi++) {
        if (!mounted) return;
        final group = groups[gi];
        final head = group.first;
        final isStack = group.length > 1;
        final markerSize = isStack ? const Size(108, 78) : const Size(96, 66);
        final icon = await NOverlayImage.fromWidget(
          widget: isStack
              ? _StackedPinMarker(head: head, count: group.length)
              : _PinMarker(pin: head),
          size: markerSize,
          context: context,
        );
        final marker = NMarker(
          id: 'pin-group-$gi',
          position: NLatLng(head.latitude, head.longitude),
          icon: icon,
          size: markerSize,
          anchor: const NPoint(0.5, 1.0),
        );
        marker.setOnTapListener((NMarker overlay) {
          if (isStack) {
            // 묶음 시트는 _selectedPin 과 동일하게 state 로 띄운다 —
            // 콜백에서 showModalBottomSheet 을 호출하면 평면 view 위에서
            // 가끔 라우트가 push 안 되는 문제가 있었음.
            setState(() {
              _selectedGroup = group;
              _selectedPin = null;
            });
          } else {
            setState(() {
              _selectedPin = head;
              _selectedGroup = null;
            });
          }
        });
        await controller.addOverlay(marker);
      }
    }
  }

  /// 좌표가 거의 같은 핀들을 묶는다 — ~20m(0.00018도) 격자로 양자화.
  List<List<MapPin>> _groupNearbyPins(List<MapPin> pins) {
    const gridDeg = 0.00018; // ≈ 위도 20m, 서울 위도에서 경도 ~16m
    final byKey = <String, List<MapPin>>{};
    for (final p in pins) {
      final key =
          '${(p.latitude / gridDeg).floor()}_${(p.longitude / gridDeg).floor()}';
      byKey.putIfAbsent(key, () => []).add(p);
    }
    return byKey.values.toList();
  }

  void _onSelectFromGroup(MapPin pin) {
    setState(() {
      _selectedGroup = null;
      _selectedPin = pin;
    });
  }

  void _onFilterChanged(MapFilter next) {
    setState(() {
      _filter = next;
      _selectedPin = null;
      _selectedGroup = null;
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
            options: NaverMapViewOptions(
              initialCameraPosition: const NCameraPosition(
                target: _seoulCity,
                zoom: 12,
              ),
              mapType: NMapType.basic,
              locationButtonEnable: true,
              // 회전 금지 + 줌아웃·이동을 한국 범위로 제한.
              rotationGesturesEnable: false,
              minZoom: 6,
              extent: NLatLngBounds(
                southWest: const NLatLng(33.0, 124.5),
                northEast: const NLatLng(39.5, 132.0),
              ),
            ),
            onMapReady: (controller) async {
              _controller = controller;
              // 내 위치로 카메라 이동 — 주변 모임이 화면에 들어오도록.
              // zoom 14 는 핀 모드(개월수·인원이 보이는 커스텀 마커).
              final pos =
                  await LocationService.instance.getCurrentPosition();
              if (pos != null && mounted) {
                // 내 위치 오버레이(파란 점) 표시.
                final overlay = controller.getLocationOverlay();
                overlay.setPosition(NLatLng(pos.latitude, pos.longitude));
                overlay.setIsVisible(true);
                await controller.updateCamera(
                  NCameraUpdate.withParams(
                    target: NLatLng(pos.latitude, pos.longitude),
                    zoom: 14,
                  ),
                );
              }
              await _loadMapDataForCurrentRegion();
            },
            // 클러스터/핀 경계(줌 11↔12)를 넘을 때만 자동 재조회 — 확대하면 클러스터가 풀린다.
            // 그 외 이동/줌은 재조회하지 않는다(필터 변경·새로고침 버튼은 즉시 재조회).
            onCameraIdle: () => _onCameraIdle(),
            onMapTapped: (_, __) {
              if (_selectedPin != null || _selectedGroup != null) {
                setState(() {
                  _selectedPin = null;
                  _selectedGroup = null;
                });
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
              children: [
                for (final c in (ref.watch(authProvider).user?.children ??
                    const <Child>[]))
                  MapFilterChildInfo(
                    nickname: c.nickname,
                    ageMonth: AppDateUtils.calculateAgeMonths(
                        c.birthYear, c.birthMonth),
                  ),
              ],
              onChanged: _onFilterChanged,
              isSingleParent:
                  ref.watch(authProvider).user?.isSingleParent == true,
            ),
          ),

          // 결과 개수 / 로딩 + 새로고침 버튼.
          Positioned(
            top: MediaQuery.of(context).padding.top + 64,
            right: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
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
                const SizedBox(width: 8),
                // 새로고침 — 카메라 이동 후 현재 영역으로 다시 조회.
                Material(
                  color: AppColors.surface,
                  shape: const CircleBorder(),
                  elevation: 1.5,
                  shadowColor: Colors.black.withValues(alpha: 0.2),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _isLoading ? null : _loadMapDataForCurrentRegion,
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(
                        Icons.refresh_rounded,
                        size: 18,
                        color: _isLoading
                            ? AppColors.textSecondary
                            : AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_selectedPin != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _PinBottomSheet(
                pin: _selectedPin!,
                distanceText: selectedDistance,
                onClose: () => setState(() => _selectedPin = null),
                onOpenDetail: () {
                  // 지도 핀에서 들어가도 방 상세는 항상 뒤로가기를 표시한다.
                  context.push('/rooms/${_selectedPin!.id}');
                },
              ),
            ),

          if (_selectedGroup != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _StackedPinSheet(
                pins: _selectedGroup!,
                onSelect: _onSelectFromGroup,
                onClose: () => setState(() => _selectedGroup = null),
              ),
            ),

          // 방 만들기 — 우하단 떠 있는 버튼. 바텀시트가 떠 있으면 위로 비켜준다.
          // 바텀네비(약 74px)에 가리지 않도록 기본 bottom 을 넉넉히 둔다.
          Positioned(
            right: 16,
            bottom: (_selectedPin != null || _selectedGroup != null)
                ? 360
                : 100,
            child: FloatingActionButton.extended(
              heroTag: 'map-create-room',
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => context.push('/rooms/create'),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                '방 만들기',
                style: AppTextStyles.body2Bold.copyWith(color: Colors.white),
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

/// 같은 지점에 핀이 여러 개 있을 때 — 본 _PinMarker 뒤에 카드 2장이 살짝 비껴 보이고
/// 우상단에 "+N" 카운트 배지가 붙는다. 탭하면 _showStackedPinSheet 로 핀 선택.
class _StackedPinMarker extends StatelessWidget {
  final MapPin head;
  final int count;

  const _StackedPinMarker({required this.head, required this.count});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      height: 78,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // 뒤 카드 — 본 카드와 살짝 비껴 배치해 "여러 장 쌓인" 느낌.
          Positioned(
            top: 4,
            left: 12,
            child: Transform.rotate(
              angle: 0.06,
              child: const _StackShadowCard(),
            ),
          ),
          Positioned(
            top: 2,
            right: 12,
            child: Transform.rotate(
              angle: -0.06,
              child: const _StackShadowCard(),
            ),
          ),
          // 맨 위 — 실제 첫 핀.
          Align(
            alignment: Alignment.center,
            child: _PinMarker(pin: head),
          ),
          // 카운트 배지 — 나머지 핀이 몇 개 더 있는지.
          Positioned(
            top: -2,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Text(
                '+${count - 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// _StackedPinMarker 뒤에 살짝 비껴 깔리는 빈 카드 — 본 카드와 같은 모양/그림자.
class _StackShadowCard extends StatelessWidget {
  const _StackShadowCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.dividerStrong, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
              colors: [Color(0xFFF9A8BF), AppColors.primary],
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

/// 핀 선택 시 하단 바텀시트 — 풀너비, 드래그 핸들, 칩 묶음, CTA 버튼.
class _PinBottomSheet extends StatelessWidget {
  final MapPin pin;
  final String? distanceText;
  final VoidCallback onClose;
  final VoidCallback onOpenDetail;

  const _PinBottomSheet({
    required this.pin,
    required this.distanceText,
    required this.onClose,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _pinAccent(pin);
    final placeLabel = AppConstants.placeTypes[pin.placeType] ?? '기타';
    final placeIcon =
        IconData(AppConstants.placeTypeIcons[pin.placeType] ?? 0xe55f,
            fontFamily: 'MaterialIcons');
    final statusText = pin.isFull
        ? '마감'
        : (pin.maxMembers > 0 &&
                pin.currentMembers / pin.maxMembers >= 0.8)
            ? '마감 임박'
            : '모집중';

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        // 아래로 스와이프하면 닫는다 — X 버튼 외에도 자연스러운 dismiss.
        // 자식의 onTap(ElevatedButton 등)은 그대로 동작한다.
        behavior: HitTestBehavior.translucent,
        onVerticalDragEnd: (details) {
          final v = details.primaryVelocity ?? 0;
          if (v > 250) onClose();
        },
        child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            // 하단 바텀바(네이티브 탭바)에 내용이 가리지 않도록 여유를 둔다.
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 80),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 드래그 핸들
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E4EA),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 제목 + 닫기
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        pin.title,
                        style: AppTextStyles.sectionHead,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkResponse(
                      onTap: onClose,
                      radius: 20,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded,
                            size: 22, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 위치 · 거리
                Row(
                  children: [
                    const Icon(Icons.place_rounded,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        pin.regionDong.isNotEmpty ? pin.regionDong : '주변',
                        style: AppTextStyles.body2
                            .copyWith(color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (distanceText != null) ...[
                      const SizedBox(width: 6),
                      const Text('·',
                          style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(width: 6),
                      const Icon(Icons.near_me_rounded,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 3),
                      Text(
                        distanceText!,
                        style: AppTextStyles.body2.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),

                // 칩 묶음 — 장소 / 연령 / 모집 상태 / 입장 방식 / 한부모
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Chip(
                      icon: placeIcon,
                      label: placeLabel,
                      color: AppColors.textPrimary,
                    ),
                    _Chip(
                      icon: Icons.child_care_rounded,
                      label: '${pin.ageMonthMin}~${pin.ageMonthMax}개월',
                      color: AppColors.secondary,
                    ),
                    _Chip(
                      icon: Icons.people_alt_rounded,
                      label:
                          '$statusText ${pin.currentMembers}/${pin.maxMembers}',
                      color: accent,
                      filled: true,
                    ),
                    _Chip(
                      icon: pin.joinType == 'APPROVAL'
                          ? Icons.lock_rounded
                          : Icons.lock_open_rounded,
                      label: pin.joinType == 'APPROVAL' ? '승인 필요' : '자유 입장',
                      color: AppColors.textSecondary,
                    ),
                    if (pin.singleParentOnly)
                      const _Chip(
                        icon: Icons.favorite_rounded,
                        label: '한부모 전용',
                        color: AppColors.primary,
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // 일시 — 가장 중요한 정보, 별도 라인.
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppDateUtils.formatDateTime(
                              pin.date, pin.startTime),
                          style: AppTextStyles.body2Bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // CTA — 상세 보기
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: onOpenDetail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          pin.joined ? '내 방으로 이동' : '방 상세 보기',
                          style: AppTextStyles.body1Bold
                              .copyWith(color: Colors.white),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
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

/// 바텀시트 안에서 쓰는 작은 칩 — 아이콘 + 라벨. filled=true 면 색 배경 강조.
class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;

  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = filled ? color.withValues(alpha: 0.12) : const Color(0xFFF3F4F6);
    final fg = filled ? color : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 한 지점에 모인 핀들을 펼쳐 보여주는 시트 — _PinBottomSheet 과 동일하게
/// build 안에서 그린다(showModalBottomSheet 미사용).
class _StackedPinSheet extends StatelessWidget {
  final List<MapPin> pins;
  final void Function(MapPin) onSelect;
  final VoidCallback onClose;

  const _StackedPinSheet({
    required this.pins,
    required this.onSelect,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragEnd: (details) {
          final v = details.primaryVelocity ?? 0;
          if (v > 250) onClose();
        },
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 18,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: Padding(
                // 하단 바텀바(네이티브 탭바)에 내용이 가리지 않도록 여유를 둔다.
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 72),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E4EA),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '이 위치에 모임 ${pins.length}개',
                                style: AppTextStyles.sectionHead,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '보고 싶은 모임을 골라주세요.',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkResponse(
                          onTap: onClose,
                          radius: 20,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close_rounded,
                                size: 22, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: pins.length,
                        separatorBuilder: (_, __) => const Divider(
                            height: 1, color: AppColors.divider),
                        itemBuilder: (_, i) {
                          final p = pins[i];
                          final accent = _pinAccent(p);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              p.title,
                              style: AppTextStyles.body2Bold,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${p.ageMonthMin}~${p.ageMonthMax}개월 · ${p.currentMembers}/${p.maxMembers}명',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            leading: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded,
                                color: AppColors.ink500),
                            onTap: () => onSelect(p),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
