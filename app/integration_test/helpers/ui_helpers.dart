// UI 통합테스트 공용 헬퍼.
//
// iOS 시뮬레이터에서 실측으로 확인한 함정 네 가지를 한곳에 모아 둔다.
// 새 UI 테스트는 이 헬퍼를 쓰고, 개별 파일에서 같은 로직을 다시 만들지 않는다.
//
//  1) iOS 키체인은 앱 삭제(simctl uninstall) 후에도 남는다. 이전 실행의 토큰이
//     살아 있으면 스플래시가 곧장 /home 으로 보내 로그인 화면이 아예 안 뜬다.
//     → [resetAuthState] 를 app.main() 전에 부른다.
//  2) convertFlutterSurfaceToImage 는 Android 전용이고, iOS takeScreenshot 은
//     런치 이미지만 돌려준다(매 단계 동일). → [shot] 은 Android 에서만 캡처한다.
//     iOS 판정은 스크린샷이 아니라 로그/finder 로 한다.
//  3) iOS 26+ 는 네이티브 탭바(플랫폼 뷰)라 하단 탭이 Flutter 위젯 트리에 없다.
//     find.text('모임 찾기') 같은 탭 이동은 동작하지 않는다. → [goTab]/[pushRoute].
//  4) enterText 후 소프트 키보드가 스크롤 폼 아래의 버튼을 덮어 tap 이 빗나간다.
//     → [tapSafely] 가 unfocus + ensureVisible 후 누른다.

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:app/core/router/app_router.dart';
import 'package:app/core/storage/secure_storage.dart';

/// finder 가 하나라도 잡히는지.
bool has(Finder f) => f.evaluate().isNotEmpty;

/// 실시간으로 [seconds] 초 기다린다(pumpAndSettle 은 무한 애니메이션에서 멈춘다).
Future<void> pumpFor(WidgetTester tester, int seconds) async {
  for (var i = 0; i < seconds; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

/// 조건이 참이 될 때까지 1초 간격으로 기다린다. 고정 대기는 콜드스타트·네트워크
/// 편차 때문에 불안정하다.
Future<bool> waitFor(
  WidgetTester tester,
  bool Function() ready, {
  int seconds = 30,
}) async {
  for (var i = 0; i < seconds; i++) {
    if (ready()) return true;
    await tester.pump(const Duration(seconds: 1));
  }
  return ready();
}

/// 이전 실행이 남긴 로그인 상태를 지우고 온보딩을 건너뛴 상태로 만든다.
/// app.main() 호출 **전에** 부를 것.
Future<void> resetAuthState() async {
  await SecureStorage.clearTokens();
  await SecureStorage.setOnboardingComplete();
}

/// 스크린샷. iOS 에서는 의미가 없어 건너뛴다.
Future<void> shot(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name,
) async {
  await tester.pump(const Duration(milliseconds: 500));
  if (!Platform.isAndroid) return;
  await binding.convertFlutterSurfaceToImage();
  await tester.pump(const Duration(milliseconds: 200));
  try {
    await binding.takeScreenshot(name);
  } catch (e) {
    debugPrint('[UI] 스크린샷 실패($name): $e');
  }
}

/// 하단 탭 이동 — 네이티브 탭바를 탭할 수 없으므로 라우터로 옮긴다.
/// path 예: '/home', '/map', '/rooms', '/my-rooms', '/mypage'
Future<void> goTab(WidgetTester tester, String path, {int settle = 3}) async {
  appRouter.go(path);
  await pumpFor(tester, settle);
}

/// 라우트 push (방 상세 등).
Future<void> pushRoute(WidgetTester tester, String path,
    {int settle = 3}) async {
  appRouter.push(path);
  await pumpFor(tester, settle);
}

/// 키보드/스크롤 때문에 빗나가지 않게 눌러 준다. 성공하면 true.
Future<bool> tapSafely(WidgetTester tester, Finder f, {int settle = 2}) async {
  if (!has(f)) return false;
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 300));
  try {
    await tester.ensureVisible(f.first);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(f.first);
  } catch (e) {
    debugPrint('[UI] 탭 실패: $e');
    return false;
  }
  await pumpFor(tester, settle);
  return true;
}

/// 앱이 로그인 화면(또는 온보딩)까지 뜨기를 기다린다. 콜드 스타트는 오래 걸린다.
Future<bool> waitForAppStart(WidgetTester tester, {int seconds = 90}) async {
  final started = await waitFor(
    tester,
    () =>
        has(find.byKey(const Key('btn-start-email'))) ||
        has(find.text('건너뛰기')),
    seconds: seconds,
  );
  if (has(find.text('건너뛰기'))) {
    await tapSafely(tester, find.text('건너뛰기'), settle: 3);
    await waitFor(tester, () => has(find.byKey(const Key('btn-start-email'))),
        seconds: 20);
  }
  return started;
}

/// 이메일 로그인. 홈 대시보드 도달까지 확인하고 true 를 돌려준다.
/// 시뮬의 첫 HTTPS 요청이 connectTimeout 에 걸리는 일이 잦아 재시도한다.
Future<bool> loginWithEmail(
  WidgetTester tester, {
  required String email,
  required String password,
  int attempts = 3,
}) async {
  if (!has(find.byKey(const Key('btn-start-email')))) return false;
  await tapSafely(tester, find.byKey(const Key('btn-start-email')));
  await waitFor(tester, () => has(find.byKey(const Key('input-email'))),
      seconds: 15);

  await tester.enterText(find.byKey(const Key('input-email')), email);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.enterText(find.byKey(const Key('input-password')), password);
  await tester.pump(const Duration(milliseconds: 300));

  for (var i = 0; i < attempts; i++) {
    final submit = find.byKey(const Key('btn-login-submit'));
    if (!has(submit)) break;
    await tapSafely(tester, submit, settle: 0);
    // 버튼이 사라진 것만으로는 부족하다 — 폰인증/프로필 설정으로 빠져도 사라진다.
    final ok = await waitFor(
      tester,
      () =>
          !has(find.byKey(const Key('btn-login-submit'))) &&
          has(find.text('같이크자')),
      seconds: 25,
    );
    if (ok) return true;
    debugPrint('[UI] 로그인 재시도 ${i + 1}');
  }
  return !has(find.byKey(const Key('btn-login-submit'))) &&
      has(find.text('같이크자'));
}
