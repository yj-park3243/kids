import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

/// FCM 알림 탭 → 라우팅. data payload 의 type 필드로 분기한다.
/// type 종류는 docs/02_기능정의서.md FCM 섹션 기준.
class FcmTapHandler {
  FcmTapHandler._();
  static final FcmTapHandler instance = FcmTapHandler._();

  StreamSubscription<RemoteMessage>? _sub;

  Future<void> init(GoRouter router) async {
    // 콜드 스타트 — 알림 탭으로 앱이 처음 열렸을 때.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _handle(router, initial);

    // 백그라운드 → 포어그라운드 진입 (알림 탭).
    _sub?.cancel();
    _sub = FirebaseMessaging.onMessageOpenedApp.listen(
      (msg) => _handle(router, msg),
    );
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  void _handle(GoRouter router, RemoteMessage message) {
    final data = message.data;
    final type = (data['type'] ?? '').toString();
    final roomId = data['roomId']?.toString();
    final chatRoomId = data['chatRoomId']?.toString();
    final ageMonth = data['ageMonth']?.toString();

    if (kDebugMode) {
      debugPrint('FCM tap: type=$type data=$data');
    }

    switch (type) {
      case 'JOIN_REQUEST':
      case 'JOIN_ACCEPTED':
      case 'JOIN_REJECTED':
      case 'ROOM_REMINDER':
      case 'ROOM_CANCELLED':
      case 'NEW_ROOM':
      case 'NEW_FLASH':
      case 'FOLLOW_NEW_ROOM':
        if (roomId != null) router.push('/rooms/$roomId');
        return;
      case 'NEW_CHAT':
        if (chatRoomId != null) router.push('/chat/$chatRoomId');
        return;
      case 'REVIEW_REQUEST':
        if (roomId != null) {
          router.push('/reviews/write?roomId=$roomId');
        }
        return;
      case 'GROWTH_UPDATE':
        if (ageMonth != null) router.push('/growth-guide/$ageMonth');
        return;
      case 'NOSHOW_WARNING':
      case 'REPORT_RESOLVED':
        router.push('/notifications');
        return;
      default:
        // 알 수 없는 타입 — 알림 화면으로 폴백.
        router.push('/notifications');
    }
  }
}
