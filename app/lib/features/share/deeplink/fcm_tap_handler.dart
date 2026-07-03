import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// FCM 알림 처리. data payload 의 type 필드로 라우팅을 분기한다.
/// type 종류는 docs/02_기능정의서.md FCM 섹션 기준.
/// - 탭(콜드/백그라운드): 목적지로 push
/// - 포어그라운드 수신: Android 는 인앱 SnackBar 로 표시(iOS 는 시스템 배너)
class FcmTapHandler {
  FcmTapHandler._();
  static final FcmTapHandler instance = FcmTapHandler._();

  /// 포어그라운드 인앱 알림(SnackBar) 표시용 — MaterialApp.scaffoldMessengerKey 에 연결.
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  StreamSubscription<RemoteMessage>? _openedSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;

  Future<void> init(GoRouter router) async {
    // iOS: 포어그라운드에서도 시스템 배너/사운드 표시. (Android 는 onMessage 로 인앱 표시)
    if (Platform.isIOS) {
      try {
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      } catch (_) {}
    }

    // 콜드 스타트 — 알림 탭으로 앱이 처음 열렸을 때.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _handleTap(router, initial);

    // 백그라운드 → 포어그라운드 진입 (알림 탭).
    _openedSub?.cancel();
    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(
      (msg) => _handleTap(router, msg),
    );

    // 포어그라운드 수신 — Android 는 시스템 배너가 안 떠서 인앱 SnackBar 로 표시.
    _foregroundSub?.cancel();
    _foregroundSub = FirebaseMessaging.onMessage.listen(
      (msg) => _handleForeground(router, msg),
    );
  }

  void dispose() {
    _openedSub?.cancel();
    _foregroundSub?.cancel();
    _openedSub = null;
    _foregroundSub = null;
  }

  /// 구버전 서버 호환: data 전체가 payload(JSON 문자열) 한 키로 오면 펼친다.
  Map<String, dynamic> _normalize(Map<String, dynamic> raw) {
    if (raw['type'] == null && raw['payload'] is String) {
      try {
        final decoded = jsonDecode(raw['payload'] as String);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      } catch (_) {
        // 파싱 실패 — 원본 그대로 사용.
      }
    }
    return raw;
  }

  /// type/roomId 등으로 목적지 경로를 만든다. 딥링크가 없으면 null.
  String? _resolveRoute(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString();
    final roomId = data['roomId']?.toString();
    final chatRoomId = data['chatRoomId']?.toString();
    final photoId = data['photoId']?.toString();

    switch (type) {
      case 'JOIN_REQUEST':
      case 'JOIN_ACCEPTED':
      case 'JOIN_REJECTED':
      case 'ROOM_REMINDER':
      case 'ROOM_CANCELLED':
      case 'ROOM_COMPLETED':
      case 'NEW_ROOM':
      case 'FOLLOW_NEW_ROOM':
        return roomId != null ? '/rooms/$roomId' : null;
      case 'NEW_CHAT':
        return chatRoomId != null ? '/chat/$chatRoomId' : null;
      case 'REVIEW_REQUEST':
        // /reviews/write 는 멤버 목록(extra)이 필요해 직행하면 빈 화면이 된다.
        // 방 상세로 보내면 '후기' 버튼이 멤버 목록과 함께 열어준다.
        return roomId != null ? '/rooms/$roomId' : null;
      case 'NEW_PHOTO':
      case 'PHOTO_COMMENT':
      case 'PHOTO_TAG':
        if (roomId == null) return null;
        return photoId != null
            ? '/rooms/$roomId/photos/$photoId'
            : '/rooms/$roomId/photos';
      case 'NOSHOW_WARNING':
      case 'REPORT_RESOLVED':
        return '/notifications';
      default:
        return null;
    }
  }

  void _handleTap(GoRouter router, RemoteMessage message) {
    final data = _normalize(message.data);
    if (kDebugMode) debugPrint('FCM tap: data=$data');
    // 알 수 없는 타입은 알림 화면으로 폴백.
    router.push(_resolveRoute(data) ?? '/notifications');
  }

  void _handleForeground(GoRouter router, RemoteMessage message) {
    // iOS 는 presentation options 로 시스템 배너가 뜨므로 중복 표시 방지.
    if (!Platform.isAndroid) return;
    final messenger = messengerKey.currentState;
    if (messenger == null) return;

    final notification = message.notification;
    final title = notification?.title ?? '알림';
    final body = notification?.body ?? '';
    final route = _resolveRoute(_normalize(message.data));

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (body.isNotEmpty)
              Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
        action: SnackBarAction(
          label: '보기',
          onPressed: () => router.push(route ?? '/notifications'),
        ),
      ),
    );
  }
}
