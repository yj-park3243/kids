import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/phone_verification_gate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_shadows.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/location/location_service.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/room.dart';
import '../../../models/user.dart';
import '../../../providers/selected_child_provider.dart';
import '../../../widgets/design/design_chip.dart';
import '../../../widgets/design/notebook.dart';
import '../../auth/providers/auth_provider.dart';
import '../../room/providers/room_detail_provider.dart';
import '../map_filter.dart';
import '../widgets/map_filter_panel.dart';
import '../widgets/pin_sheet.dart';

const _seoulCity = NLatLng(37.5665, 126.9780);

class MapScreen extends ConsumerStatefulWidget {
  /// UI 테스트 전용. 테스트 빌드가 아니면 false.
  static bool debugSelectFirstPin() => _MapScreenState.debugSelectFirstPin();

  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  /// UI 테스트 전용 — 네이티브 마커는 위젯 트리에서 탭할 수 없어, 첫 핀을 선택해
  /// 시트를 띄우는 진입점을 테스트 빌드(UI_TEST_SKIP_ATT)에서만 연다.
  static _MapScreenState? _debugInstance;
  static bool debugSelectFirstPin() {
    if (!const bool.fromEnvironment('UI_TEST_SKIP_ATT')) return false;
    final st = _debugInstance;
    if (st == null || !st.mounted || st._pins.isEmpty) return false;
    st._onSelectFromGroup(st._pins.first);
    return true;
  }

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
  // 핀 시트 높이(화면 비율) — FAB 을 시트 위로 비켜 세우는 데 쓴다.
  double _sheetExtent = 0;
  // 지도 로드 직렬화. 로드가 겹치면(onMapReady 명시 호출 + 카메라 idle 호출) 앞 로드가
  // 만든 마커 임시 이미지 파일을 뒤 로드의 clearOverlays 가 지워, 플러그인이
  // UIImage(contentsOfFile:)! 에서 nil 로 죽는다(NOverlayImage.swift:16). 진행 중이면
  // 예약만 하고, 끝난 뒤 한 번 더 돈다.
  Future<void>? _loadInFlight;
  bool _reloadRequested = false;

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

  Future<void> _loadMapDataForCurrentRegion() {
    final inFlight = _loadInFlight;
    if (inFlight != null) {
      _reloadRequested = true;
      return inFlight;
    }
    final run = () async {
      do {
        _reloadRequested = false;
        await _loadMapDataOnce();
      } while (_reloadRequested && mounted);
    }();
    _loadInFlight = run.whenComplete(() => _loadInFlight = null);
    return _loadInFlight!;
  }

  Future<void> _loadMapDataOnce() async {
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
        if (!mounted || !identical(_controller, controller)) return;
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
            _revealPin(head);
          }
        });
        if (!mounted || !identical(_controller, controller)) return;
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
    _revealPin(pin);
  }

  /// 시트가 올라오면 핀이 가려진다 — 핀을 화면 위쪽 1/3 지점으로 옮겨 시트 위에 남긴다.
  Future<void> _revealPin(MapPin pin) async {
    final controller = _controller;
    if (controller == null) return;
    final size = MediaQuery.of(context).size;
    final pos = await controller.getCameraPosition();
    if (!mounted) return;
    // 핀을 시트 위(화면 세로 ~40% 지점)에 두려면 중심을 그만큼 남쪽으로 옮긴다.
    // 위도 1도 ≈ 111km, 줌별 m/px 로 환산. (물리 px 이 아니라 논리 px 기준 = 지도 SDK 와 동일)
    final metersPerPx = 156543.03392 *
        math.cos(pin.latitude * math.pi / 180) /
        math.pow(2, pos.zoom);
    final shiftPx = size.height * 0.10;
    final shiftLat = shiftPx * metersPerPx / 111320;
    await controller.updateCamera(
      NCameraUpdate.withParams(
        target: NLatLng(pin.latitude - shiftLat, pin.longitude),
      )..setAnimation(
          animation: NCameraAnimation.easing,
          duration: const Duration(milliseconds: 320),
        ),
    );
  }

  void _onFilterChanged(MapFilter next) {
    setState(() {
      _filter = next;
      _selectedPin = null;
      _selectedGroup = null;
    });
    _loadMapDataForCurrentRegion();
  }

  // 내 위치로 카메라 이동 + 파란 점 오버레이.
  // zoom 14 는 핀 모드(개월수·인원이 보이는 커스텀 마커).
  Future<void> _moveToMyLocation() async {
    final controller = _controller;
    if (controller == null) return;
    final pos = await LocationService.instance.getCurrentPosition();
    if (pos == null || !mounted) return;
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

  @override
  void initState() {
    super.initState();
    _debugInstance = this;
  }

  @override
  void dispose() {
    if (identical(_debugInstance, this)) _debugInstance = null;
    super.dispose();
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
              // 기본(좌하단) 위치 버튼 대신 우상단 커스텀 버튼을 쓴다.
              locationButtonEnable: false,
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
              await _moveToMyLocation();
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
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.line2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isLoading)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.ink),
                        )
                      else
                        Icon(
                          _mode == 'CLUSTER'
                              ? Icons.location_city_rounded
                              : Icons.place_rounded,
                          size: 14,
                          color: AppColors.ink3,
                        ),
                      const SizedBox(width: 5),
                      Text(
                        _mode == 'CLUSTER'
                            ? '동 ${_clusters.length}곳'
                            : '모임 ${_pins.length}개',
                        style: AppTextStyles.captionBold,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 새로고침 — 카메라 이동 후 현재 영역으로 다시 조회.
                _MapControlButton(
                  icon: Icons.refresh_rounded,
                  onTap: _isLoading ? null : _loadMapDataForCurrentRegion,
                ),
              ],
            ),
          ),

          // 내 위치로 이동 — 우상단(새로고침 아래), 네이버 기본 버튼 대체.
          Positioned(
            top: MediaQuery.of(context).padding.top + 104,
            right: 16,
            child: _MapControlButton(
              icon: Icons.my_location_rounded,
              onTap: _moveToMyLocation,
            ),
          ),

          // 핀 시트 — 끌어 올리면 소개·참여자, 끝까지 올리면 상세로.
          if (_selectedPin != null)
            PinSheet(
              key: const ValueKey('map-pin-sheet'),
              pin: _selectedPin!,
              distanceText: selectedDistance,
              onExtentChanged: (e) {
                if (mounted) setState(() => _sheetExtent = e);
              },
              onClose: () => setState(() {
                _selectedPin = null;
                _sheetExtent = 0;
              }),
              onOpenDetail: () {
                // 지도 핀에서 들어가도 방 상세는 항상 뒤로가기를 표시한다.
                context.push('/rooms/${_selectedPin!.id}');
              },
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
          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            right: 16,
            bottom: _selectedGroup != null
                ? 360
                : _selectedPin != null
                    ? MediaQuery.of(context).size.height * _sheetExtent + 16
                    : 100,
            child: FloatingActionButton(
              heroTag: 'map-create-room',
              backgroundColor: AppColors.ink,
              foregroundColor: Colors.white,
              elevation: 0,
              highlightElevation: 0,
              shape: const CircleBorder(),
              tooltip: '방 만들기',
              onPressed: () => openRoomCreate(context, ref),
              child: const Icon(Icons.add_rounded, size: 26),
            ),
          ),
        ],
      ),
    );
  }
}

/// 지도 위 보조 버튼 — 흰 면 + 헤어라인. 그림자 대신 테두리로 띄운다.
class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _MapControlButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(
        side: BorderSide(color: AppColors.line2),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            icon,
            size: 18,
            color: onTap == null ? AppColors.ink3 : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

// 모집 상태 — 형광펜(모집중) / 회색 선(마감). 색은 두 가지뿐이다.
Color _pinAccent(MapPin pin) =>
    pin.isFull ? AppColors.line2 : AppColors.hi;

/// 지도 위 커스텀 핀 — 흰 카드에 개월수 + 모집 인원, 모집중이면 형광펜 테두리.
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
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${pin.ageMonthMin}~${pin.ageMonthMax}개월',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 1),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people_alt_rounded,
                      size: 11, color: AppColors.ink3),
                  const SizedBox(width: 3),
                  Text(
                    '${pin.currentMembers}/${pin.maxMembers}',
                    style: const TextStyle(
                      color: AppColors.ink2,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
              child: Text(
                '+${count - 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
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

/// _StackedPinMarker 뒤에 살짝 비껴 깔리는 빈 카드 — 본 카드와 같은 모양.
class _StackShadowCard extends StatelessWidget {
  const _StackShadowCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line2, width: 1.4),
      ),
    );
  }
}

/// 지도 클러스터 — 잉크 원형 카운트 + 동 이름 칩.
class _ClusterMarker extends StatelessWidget {
  final MapCluster cluster;

  const _ClusterMarker({required this.cluster});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.ink,
            border: Border.all(color: AppColors.surface, width: 2.5),
          ),
          alignment: Alignment.center,
          child: Text(
            '${cluster.count}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.line2),
          ),
          child: Text(
            cluster.regionDong,
            style: const TextStyle(
              color: AppColors.ink,
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
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
            border: const Border(top: BorderSide(color: AppColors.line)),
            boxShadow: AppShadows.overlay,
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
                          color: AppColors.line2,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
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
                                style: AppTextStyles.caption,
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
                                size: 22, color: AppColors.ink3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: pins.length,
                        separatorBuilder: (_, __) => const DashedDivider(),
                        itemBuilder: (_, i) {
                          final p = pins[i];
                          return InkWell(
                            onTap: () => onSelect(p),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.title,
                                          style: AppTextStyles.cardTitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${AppDateUtils.formatTime(p.startTime)} · ${p.ageMonthMin}~${p.ageMonthMax}개월 · ${p.currentMembers}/${p.maxMembers}명',
                                          style: AppTextStyles.body2,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (!p.isFull)
                                    const Pill(label: '모집중', tone: PillTone.hi)
                                  else
                                    const Pill(
                                        label: '마감', tone: PillTone.muted),
                                  const Icon(Icons.chevron_right_rounded,
                                      color: AppColors.line2),
                                ],
                              ),
                            ),
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
