// 앱 전 화면 스모크 테스트 — 로그인 후 주요 화면·버튼을 순회하며
// 크래시·렌더 에러 없이 동작하는지 검증한다.
//
// 각 화면 진입 직후 tester.takeException() 으로 예외를 수집한다.
// 실패한 화면은 [SMOKE_FAIL] 로그 + _failures 에 쌓이고, 끝에서 expect 로
// 전체 통과/실패를 판정한다.
//
// 사전 전제 (orchestrator):
//   - 계정 1개 가입 + 폰인증 우회 + 프로필 + 자녀
//   - 방 1개 사전 생성 (방 상세/카드 검증용)
//   - dart-define: UI_TEST_EMAIL / UI_TEST_PASSWORD / UI_TEST_LAT / UI_TEST_LNG

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:app/main.dart' as app;
import 'package:app/features/home/presentation/widgets/room_card.dart';
import 'package:app/widgets/design/design_chip.dart';

final Dio _shotDio = Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 2),
  receiveTimeout: const Duration(seconds: 3),
));

const _email = String.fromEnvironment('UI_TEST_EMAIL', defaultValue: '');
const _password = String.fromEnvironment('UI_TEST_PASSWORD', defaultValue: '');
// 스크린샷 prefix — 디바이스(kids/ip17)별로 구분.
const _deviceTag = String.fromEnvironment('UI_DEVICE_TAG', defaultValue: 'smoke');

final List<String> _failures = [];

Future<void> _settle(WidgetTester tester, {int fallbackSeconds = 3}) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 6),
    );
  } catch (_) {
    for (var i = 0; i < fallbackSeconds; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }
}

Future<void> _shot(WidgetTester tester, String label) async {
  await _settle(tester, fallbackSeconds: 1);
  await tester.pump(const Duration(milliseconds: 200));
  try {
    await _shotDio.get('http://127.0.0.1:9998/${_deviceTag}_$label');
    await Future.delayed(const Duration(milliseconds: 500));
  } catch (_) {}
}

/// 화면 진입 직후 호출 — 예외 또는 에러 상태면 실패로 기록한다.
Future<void> _check(WidgetTester tester, String label) async {
  await _settle(tester);
  final ex = tester.takeException();
  if (ex != null) {
    _failures.add('$label → 예외: $ex');
    print('[SMOKE_FAIL] $label → 예외: $ex');
  } else if (find.textContaining('불러올 수 없').evaluate().isNotEmpty ||
      find.textContaining('다시 시도').evaluate().isNotEmpty) {
    _failures.add('$label → 화면 로딩 실패(에러 상태)');
    print('[SMOKE_FAIL] $label → 에러 상태');
  } else {
    print('[SMOKE_OK] $label');
  }
  await _shot(tester, label);
}

/// 보이면 탭. 없으면 false.
Future<bool> _tap(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) return false;
  try {
    await tester.ensureVisible(f.first);
  } catch (_) {}
  await tester.tap(f.first, warnIfMissed: false);
  await _settle(tester);
  return true;
}

/// 뒤로가기 — CustomAppBar 의 back 아이콘.
Future<void> _back(WidgetTester tester) async {
  final back = find.byIcon(Icons.arrow_back_ios_new_rounded);
  if (back.evaluate().isNotEmpty) {
    await tester.tap(back.first, warnIfMissed: false);
    await _settle(tester);
  }
}

Future<void> _skipOnboarding(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    if (find.byKey(const Key('btn-start-email')).evaluate().isNotEmpty) return;
    final skip = find.text('건너뛰기');
    if (skip.evaluate().isNotEmpty) {
      await tester.tap(skip.first, warnIfMissed: false);
      await _settle(tester);
      continue;
    }
    await tester.pump(const Duration(seconds: 1));
  }
}

Future<void> _login(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('btn-start-email')),
      warnIfMissed: false);
  await _settle(tester);
  await tester.enterText(find.byKey(const Key('input-email')), _email);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.enterText(find.byKey(const Key('input-password')), _password);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump(const Duration(milliseconds: 300));
  final btn = find.byKey(const Key('btn-login-submit'));
  if (btn.evaluate().isNotEmpty) {
    await tester.tap(btn.first, warnIfMissed: false);
  }
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

/// 하단 탭으로 이동.
Future<void> _navTab(WidgetTester tester, String label) async {
  final tab = find.text(label);
  if (tab.evaluate().isNotEmpty) {
    await tester.tap(tab.last, warnIfMissed: false);
    await _settle(tester);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('앱 전 화면 스모크', (tester) async {
    expect(_email.isNotEmpty, true, reason: 'UI_TEST_EMAIL 미주입');

    // ─── 로그인 ─────────────────────────────────────────────
    app.main();
    await _settle(tester, fallbackSeconds: 5);
    await _skipOnboarding(tester);
    await _check(tester, '01_login');
    await _login(tester);
    await _check(tester, '02_home');

    // ─── 홈 — 필터 칩 ───────────────────────────────────────
    if (await _tap(tester, find.text('오늘'))) {
      await _check(tester, '03_home_date_today');
    }
    await _tap(tester, find.text('전체'));

    // ─── 홈 — 알림 진입 ─────────────────────────────────────
    if (await _tap(tester, find.byIcon(Icons.notifications_outlined))) {
      await _check(tester, '04_notifications');
      await _back(tester);
    }

    // ─── 지도 탭 ────────────────────────────────────────────
    await _navTab(tester, '지도');
    await _check(tester, '05_map');
    if (await _tap(tester, find.text('펼치기'))) {
      await _check(tester, '06_map_filter_expanded');
      await _tap(tester, find.text('접기'));
    }

    // ─── 내방 탭 ────────────────────────────────────────────
    await _navTab(tester, '내방');
    await _check(tester, '07_myrooms');

    // ─── 마이 탭 ────────────────────────────────────────────
    await _navTab(tester, '마이');
    await _check(tester, '08_mypage');

    // ─── 마이 — 프로필 수정 ─────────────────────────────────
    if (await _tap(tester, find.text('프로필 수정'))) {
      await _check(tester, '09_profile_edit');
      await _back(tester);
    }

    // ─── 마이 — 알림 설정 ───────────────────────────────────
    if (await _tap(tester, find.text('알림 설정'))) {
      await _check(tester, '10_notification_settings');
      // 토글 동작
      final sw = find.byType(Switch);
      if (sw.evaluate().isNotEmpty) {
        await tester.tap(sw.first, warnIfMissed: false);
        await _check(tester, '11_noti_toggle');
      }
      await _back(tester);
    }

    // ─── 마이 — 차단한 유저 ─────────────────────────────────
    if (await _tap(tester, find.text('차단한 유저'))) {
      await _check(tester, '12_blocked_users');
      await _back(tester);
    }

    // ─── 마이 — 1:1 문의 ────────────────────────────────────
    if (await _tap(tester, find.text('1:1 문의'))) {
      await _check(tester, '13_inquiry');
      await _back(tester);
    }

    // ─── 홈 — 방 상세 진입 ──────────────────────────────────
    await _navTab(tester, '홈');
    await _settle(tester);
    // 홈 재진입 시 자동 loadRooms 가 끝나길 대기 — 로딩 중이면 날짜 필터
    // 변경이 isLoading 가드에 막혀 무시된다.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    // 날짜 필터를 '전체'로 되돌린다 — 03 단계에서 '오늘'을 눌러둔 상태면
    // 다른 날짜의 방이 목록에 안 나온다.
    final dateAll = find.widgetWithText(DesignChip, '전체');
    if (dateAll.evaluate().isNotEmpty) {
      await tester.tap(dateAll.first, warnIfMissed: false);
      await _settle(tester);
    }
    // 방 목록 API 로딩 대기 — 카드가 나올 때까지 최대 8초 폴링.
    for (var i = 0; i < 8; i++) {
      if (find.byType(RoomCard).evaluate().isNotEmpty) break;
      await tester.pump(const Duration(seconds: 1));
    }
    final card = find.byType(RoomCard);
    if (card.evaluate().isNotEmpty) {
      await tester.tap(card.first, warnIfMissed: false);
      await _settle(tester);
      await _check(tester, '14_room_detail');
      await _back(tester);
    } else {
      _failures.add('14_room_detail → 홈에 방 카드가 없음');
      print('[SMOKE_FAIL] 14_room_detail → 방 카드 없음');
    }

    // ─── 마이 — 로그아웃 다이얼로그 (취소) ──────────────────
    await _navTab(tester, '마이');
    await _settle(tester);
    if (await _tap(tester, find.text('로그아웃'))) {
      await _check(tester, '15_logout_dialog');
      final cancel = find.text('취소');
      if (cancel.evaluate().isNotEmpty) {
        await tester.tap(cancel.last, warnIfMissed: false);
        await _settle(tester);
      }
    }

    // ─── 결과 판정 ──────────────────────────────────────────
    print('[SMOKE_RESULT] 실패 ${_failures.length}건');
    for (final f in _failures) {
      print('[SMOKE_RESULT]   - $f');
    }
    expect(_failures, isEmpty,
        reason: '스모크 실패 화면: ${_failures.join(" | ")}');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
