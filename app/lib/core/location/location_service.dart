import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// 사용자 현재 위치 — 모임과의 거리 계산에 쓴다.
/// 권한 거부/위치 꺼짐 시 조용히 null (거리 표시만 생략).
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  Position? _cached;
  Position? get cached => _cached;

  // 테스트 — dart-define 으로 위치를 주입하면 권한 다이얼로그 없이 그 좌표 사용.
  static const _testLat = String.fromEnvironment('UI_TEST_LAT');
  static const _testLng = String.fromEnvironment('UI_TEST_LNG');

  Future<Position?> getCurrentPosition() async {
    if (_testLat.isNotEmpty && _testLng.isNotEmpty) {
      final lat = double.tryParse(_testLat);
      final lng = double.tryParse(_testLng);
      if (lat != null && lng != null) {
        return Position(
          latitude: lat,
          longitude: lng,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      }
    }
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return _cached;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return _cached;
      }
      // timeLimit — 시뮬레이터 등 위치 신호가 없는 환경에서 hang 방지.
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      _cached = pos;
      return pos;
    } catch (_) {
      return _cached;
    }
  }
}

/// 현재 위치 provider — 첫 watch 시 권한 요청 후 위치를 받고 캐시한다.
final currentPositionProvider = FutureProvider<Position?>((ref) async {
  return LocationService.instance.getCurrentPosition();
});

/// 두 좌표 사이 거리(km).
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000;
}

/// 거리를 사람이 읽기 좋은 문자열로. 1km 미만은 m, 그 이상은 km.
String formatDistance(double km) {
  if (km < 1) return '${(km * 1000).round()}m';
  if (km < 10) return '${km.toStringAsFixed(1)}km';
  return '${km.round()}km';
}
