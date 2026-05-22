import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../storage/secure_storage.dart';

/// FCM 디바이스 토큰을 서버에 등록한다.
/// - 로그인된 상태(access token 보유)에서만 등록 — 미로그인 시 401 방지.
/// - FCM 토큰 갱신(onTokenRefresh)도 감지해 재등록한다.
class PushTokenService {
  PushTokenService._();
  static final PushTokenService instance = PushTokenService._();

  StreamSubscription<String>? _refreshSub;
  bool _initialized = false;

  /// 앱 시작 시(부트스트랩) 1회 호출. 권한 요청 → 토큰 등록 → 갱신 구독.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (e) {
      if (kDebugMode) debugPrint('[Push] 권한 요청 실패: $e');
    }

    // 토큰 갱신 감지 — 갱신될 때마다 재등록.
    _refreshSub?.cancel();
    _refreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) => unawaited(_register(token)),
    );

    // 현재 토큰 등록 시도.
    await registerCurrentToken();
  }

  /// 현재 FCM 토큰을 받아 서버에 등록. 로그인 직후에도 호출 가능.
  Future<void> registerCurrentToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _register(token);
      }
    } catch (e) {
      // 시뮬레이터 등에서 FCM 토큰을 못 받을 수 있음 — 무시.
      if (kDebugMode) debugPrint('[Push] FCM 토큰 조회 실패: $e');
    }
  }

  Future<void> _register(String token) async {
    // 미로그인 상태면 등록 보류 — 로그인 후 registerCurrentToken() 으로 재시도.
    final accessToken = await SecureStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      if (kDebugMode) debugPrint('[Push] 미로그인 — FCM 토큰 등록 보류');
      return;
    }

    final platform = Platform.isIOS ? 'IOS' : 'ANDROID';
    try {
      await ApiClient.instance.post(
        ApiConstants.deviceToken,
        data: {'token': token, 'platform': platform},
      );
      if (kDebugMode) debugPrint('[Push] FCM 토큰 등록 완료 (platform=$platform)');
    } catch (e) {
      if (kDebugMode) debugPrint('[Push] FCM 토큰 등록 실패: $e');
    }
  }

  void dispose() {
    _refreshSub?.cancel();
    _refreshSub = null;
  }
}
