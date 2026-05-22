import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

/// 외부에서 들어온 딥링크/유니버설 링크를 라우터로 푸시한다.
/// 지원 형식:
///   kids://room/:id
///   https://growtogether.kr/room/:id
class DeeplinkHandler {
  DeeplinkHandler._();
  static final DeeplinkHandler instance = DeeplinkHandler._();

  AppLinks? _appLinks;
  StreamSubscription<Uri>? _sub;

  /// 콜드 스타트 + 런타임 유입을 모두 받는다.
  Future<void> init(GoRouter router) async {
    _appLinks ??= AppLinks();

    // 콜드 스타트 — 앱이 링크로 처음 열렸을 때.
    try {
      final initial = await _appLinks!.getInitialLink();
      if (initial != null) _handle(router, initial);
    } catch (e) {
      if (kDebugMode) debugPrint('Deeplink initial fetch failed: $e');
    }

    // 백그라운드/포어그라운드 유입.
    _sub?.cancel();
    _sub = _appLinks!.uriLinkStream.listen(
      (uri) => _handle(router, uri),
      onError: (Object err) {
        if (kDebugMode) debugPrint('Deeplink stream error: $err');
      },
    );
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  void _handle(GoRouter router, Uri uri) {
    if (kDebugMode) debugPrint('Deeplink received: $uri');

    final segments = uri.pathSegments;
    final host = uri.host; // kids://room/123 → host='room', path='/123'

    // 1) 커스텀 스킴: kids://room/:id
    if (uri.scheme == 'kids') {
      if (host == 'room' && segments.isNotEmpty) {
        router.push('/rooms/${segments.first}');
        return;
      }
    }

    // 2) 유니버설 링크: https://growtogether.kr/room/:id
    if (segments.length >= 2) {
      final type = segments[0];
      final id = segments[1];
      if (type == 'room' || type == 'rooms') {
        router.push('/rooms/$id');
        return;
      }
    }
  }
}
