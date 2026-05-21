// 회원가입 → 방 만들기 → 지도 확인 (A) / 다른 계정 로그인 → 방 입장 (B)
//
// 사전 전제 (orchestrator):
//   - A/B 두 계정을 API 로 가입 + SSH 폰인증 우회 + 프로필 + 자녀 등록
//   - 방은 만들지 않음 — A 가 UI 로 직접 생성한다.
//   - dart-define 으로 UI_TEST_EMAIL / UI_TEST_PASSWORD / UI_TEST_ROLE /
//     UI_TARGET_ROOM_TITLE 주입. A 가 그 제목으로 방을 만들고 B 가 같은
//     제목으로 카드를 찾아 입장한다.
//
// A (회원가입 + 방 만들기 + 지도):
//   01 로그인 화면 → 02 이메일 로그인 → 03 회원가입 화면
//   04 회원가입 폼 입력 (가입 버튼은 누르지 않음 — KCP 본인인증 화면이
//      PopScope(canPop:false) 라 진입하면 빠져나올 수 없어 폼 작성까지만 시연)
//   06 뒤로 → 이메일 로그인 → 사전셋업 A 계정으로 로그인 → 홈
//   07~12 방 만들기 (제목/설명/날짜/시간/지역/제출)
//   13~14 방 상세 도달 → 15 지도 탭에서 방 확인
//
// B (다른 계정 로그인 + 방 입장):
//   01 로그인 → 02 이메일 로그인 → 홈
//   03 A 가 만든 방 카드 → 방 상세 → 04 참여하기 → 05 채팅방 입장
//
// 주의: iOS 26.4 시뮬에서 `pumpAndSettle` 이 화면 전환 지점에서 끝나지 않아
// (프레임이 계속 스케줄됨) 그대로 await 하면 테스트가 hang 한다. 모든
// settle 은 `_settle` 헬퍼로 — 짧은 timeout 후 고정 pump 로 폴백한다.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:app/main.dart' as app;
import 'package:app/features/home/presentation/widgets/room_card.dart';

final Dio _shotDio = Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 2),
  receiveTimeout: const Duration(seconds: 3),
));

const _email = String.fromEnvironment('UI_TEST_EMAIL', defaultValue: '');
const _password = String.fromEnvironment('UI_TEST_PASSWORD', defaultValue: '');
const _role = String.fromEnvironment('UI_TEST_ROLE', defaultValue: 'A');
const _targetRoomTitle =
    String.fromEnvironment('UI_TARGET_ROOM_TITLE', defaultValue: '');

/// pumpAndSettle 을 시도하되, iOS 26.4 시뮬에서 프레임이 계속 스케줄돼
/// settle 이 끝나지 않으면 timeout 후 고정 pump 로 폴백한다 (match 방식).
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

Future<void> _pumpSeconds(WidgetTester tester, int seconds) async {
  for (var i = 0; i < seconds; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

// integration_test 의 Flutter surface 캡처(convertFlutterSurfaceToImage)는
// iOS 26.4 시뮬에서 멈춘다. orchestrator 가 띄운 HTTP 서버(9998)에 요청해
// 호스트가 `simctl io screenshot` 으로 네이티브 캡처하게 한다 (match 방식).
Future<void> _shot(WidgetTester tester, String label) async {
  await _settle(tester, fallbackSeconds: 1);
  await tester.pump(const Duration(milliseconds: 200));
  try {
    await _shotDio.get('http://127.0.0.1:9998/${_role}_$label');
    await Future.delayed(const Duration(milliseconds: 600));
  } catch (_) {}
}

/// 위젯이 보이면 스크롤해 화면에 들인 뒤 탭한다. 없으면 false.
Future<bool> _tapKey(WidgetTester tester, Key key) async {
  final f = find.byKey(key);
  if (f.evaluate().isEmpty) return false;
  try {
    await tester.ensureVisible(f.first);
    await tester.pump(const Duration(milliseconds: 200));
  } catch (_) {}
  await tester.tap(f.first, warnIfMissed: false);
  return true;
}

/// 키보드를 내린다. 입력 후 화면 하단 위젯이 키보드에 가려 탭이 안 먹는 것 방지.
Future<void> _dismissKeyboard(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await _settle(tester);
}

/// 스플래시 → 온보딩 → 로그인 화면 전환을 기다린다. 온보딩이 뜨면
/// "건너뛰기" 로 넘긴다. (erase 된 시뮬은 매 실행 온보딩이 다시 나타나고,
/// 스플래시가 길어 단순 settle 만으로는 온보딩 등장 전에 지나칠 수 있다)
Future<void> _skipOnboarding(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    if (find.byKey(const Key('btn-start-email')).evaluate().isNotEmpty) {
      return; // 로그인 화면 도달
    }
    final skip = find.text('건너뛰기');
    if (skip.evaluate().isNotEmpty) {
      await tester.tap(skip.first, warnIfMissed: false);
      await _settle(tester);
      continue;
    }
    await tester.pump(const Duration(seconds: 1));
  }
}

/// 이메일 로그인 화면에서 자격증명을 넣고 홈까지 진입.
Future<void> _emailLogin(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('input-email')), _email);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.enterText(find.byKey(const Key('input-password')), _password);
  await tester.pump(const Duration(milliseconds: 300));
  // 비밀번호 필드의 done 액션 → onSubmitted → _login(). 키보드가 화면 하단
  // 로그인 버튼을 가려 tap 이 안 먹히므로 done 액션으로 제출한다.
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump(const Duration(milliseconds: 300));
  // 폴백 — done 으로 제출이 안 됐으면 버튼도 직접 시도.
  final btn = find.byKey(const Key('btn-login-submit'));
  if (btn.evaluate().isNotEmpty) {
    await tester.tap(btn.first, warnIfMissed: false);
  }
  await _pumpSeconds(tester, 8);
}

/// 홈 방 목록에서 [_targetRoomTitle] 카드를 찾는다. (스크롤 포함)
Future<Finder?> _targetCard(WidgetTester tester) async {
  final cards = find.byType(RoomCard);
  if (cards.evaluate().isEmpty) return null;
  if (_targetRoomTitle.isEmpty) return cards.first;

  final titleFinder = find.text(_targetRoomTitle);
  if (titleFinder.evaluate().isNotEmpty) {
    return find
        .ancestor(of: titleFinder, matching: find.byType(RoomCard))
        .first;
  }
  try {
    await tester.scrollUntilVisible(
      find.text(_targetRoomTitle),
      300.0,
      scrollable: find.byType(Scrollable).last,
    );
    await _settle(tester);
    return find
        .ancestor(
          of: find.text(_targetRoomTitle),
          matching: find.byType(RoomCard),
        )
        .first;
  } catch (_) {
    return cards.first;
  }
}

/// Daum 우편번호 WebView 의 JS 채널(KidsPostcode)을 직접 호출해 주소를 주입.
/// WebView 내부 검색 UI 는 integration_test 로 조작할 수 없어, oncomplete 가
/// 부르는 postBack 과 동일한 payload 를 채널로 흘려보낸다.
Future<bool> _injectAddress(WidgetTester tester) async {
  // WebView 는 네이티브라 pump 으로는 로드되지 않음 — 실제 시간으로 대기.
  await tester.runAsync(() async {
    await Future.delayed(const Duration(seconds: 7));
  });
  await _settle(tester);

  final wv = find.byType(WebViewWidget);
  if (wv.evaluate().isEmpty) return false;
  final widget = wv.evaluate().first.widget as WebViewWidget;

  const js = "window.KidsPostcode.postMessage(JSON.stringify({"
      "sido:'서울특별시',sigungu:'강남구',dong:'역삼동',"
      "roadAddress:'서울 강남구 테헤란로 152',"
      "jibunAddress:'서울 강남구 역삼동 737',"
      "buildingName:'강남파이낸스센터',zonecode:'06236'}))";
  try {
    await tester.runAsync(() async {
      await widget.platform.params.controller.runJavaScript(js);
    });
    await _settle(tester);
    return true;
  } catch (e) {
    print('[UI_TEST] 주소 JS 주입 실패: $e');
    return false;
  }
}

Future<void> _runRoleA(WidgetTester tester) async {
  // ─── 로그인 화면 ────────────────────────────────────────
  app.main();
  await _settle(tester, fallbackSeconds: 5);
  await _skipOnboarding(tester);
  await _shot(tester, '01_login_screen');

  await _tapKey(tester, const Key('btn-start-email'));
  await _settle(tester);
  await _shot(tester, '02_email_login');

  // ─── 회원가입 화면으로 이동 ──────────────────────────────
  final toRegister = find.text('회원가입');
  if (toRegister.evaluate().isNotEmpty) {
    await tester.tap(toRegister.last, warnIfMissed: false);
    await _settle(tester);
    await _shot(tester, '03_register_form');

    // 회원가입 폼 입력만 시연한다. 가입 버튼을 누르면 KCP 본인인증 화면으로
    // 진입하는데 PopScope(canPop:false) 라 빠져나올 수 없고, 신규 이메일이
    // 서버에 쌓인다. 폼 작성(= 본인인증 직전)까지만 캡처하고 뒤로 돌아간다.
    final newEmail =
        'newcomer_${DateTime.now().millisecondsSinceEpoch}@test.com';
    await tester.enterText(
        find.byKey(const Key('input-register-email')), newEmail);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(
        find.byKey(const Key('input-register-password')), _password);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(
        find.byKey(const Key('input-register-password-confirm')), _password);
    await tester.pump(const Duration(milliseconds: 200));
    await _shot(tester, '04_register_filled');

    // 뒤로 → 최초 로그인 화면. email-login 의 "회원가입" 링크가
    // pushReplacement 라, 회원가입에서 뒤로 가면 /email-login 이 아니라
    // 최초 /login 화면으로 돌아간다.
    final back = find.byIcon(Icons.arrow_back_ios_new_rounded);
    if (back.evaluate().isNotEmpty) {
      await tester.tap(back.first, warnIfMissed: false);
      await _settle(tester);
    }
    // 로그인 화면에서 다시 이메일 로그인 폼으로 진입.
    if (await _tapKey(tester, const Key('btn-start-email'))) {
      await _settle(tester);
    }
  }

  // ─── 사전셋업 A 계정으로 로그인 ──────────────────────────
  await _emailLogin(tester);
  await _shot(tester, '06_home');

  // ─── 방 만들기 ──────────────────────────────────────────
  final createBtn = find.byKey(const Key('btn-home-create-room'));
  expect(createBtn, findsOneWidget, reason: '홈에 방 만들기 버튼이 없음');
  await tester.tap(createBtn, warnIfMissed: false);
  await _settle(tester);
  await _shot(tester, '07_create_form');

  // 제목 / 설명
  await tester.enterText(
      find.byKey(const Key('input-room-title')), _targetRoomTitle);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.enterText(
    find.byKey(const Key('input-room-description')),
    'UI 자동화 — 회원가입→방만들기→지도 시나리오로 생성된 모임입니다.',
  );
  await tester.pump(const Duration(milliseconds: 200));
  await _shot(tester, '08_basic_filled');

  // 키보드를 내려 아래쪽 날짜/시간/지역 위젯을 탭할 수 있게 한다.
  await _dismissKeyboard(tester);

  // 날짜 — 시트의 기본값(내일)을 그대로 "확인".
  await _tapKey(tester, const Key('btn-room-date'));
  await _settle(tester);
  if (find.text('확인').evaluate().isNotEmpty) {
    await tester.tap(find.text('확인').last, warnIfMissed: false);
    await _settle(tester);
  }
  await _shot(tester, '09_date_picked');

  // 시작 시간 — 기본값(14:00) 그대로 "확인".
  await _tapKey(tester, const Key('btn-room-start-time'));
  await _settle(tester);
  if (find.text('확인').evaluate().isNotEmpty) {
    await tester.tap(find.text('확인').last, warnIfMissed: false);
    await _settle(tester);
  }
  await _shot(tester, '10_time_picked');

  // 지역 — Daum WebView 띄운 뒤 JS 채널로 주소 주입.
  await _tapKey(tester, const Key('btn-room-address'));
  await _settle(tester);
  final addressOk = await _injectAddress(tester);
  // 주입 실패 등으로 주소 sheet 가 남아있으면 닫기 버튼으로 정리 — 안 닫으면
  // sheet 가 제출 버튼을 덮어 이후 탭이 불가능하다.
  final closeBtn = find.byIcon(Icons.close_rounded);
  if (closeBtn.evaluate().isNotEmpty) {
    await tester.tap(closeBtn.first, warnIfMissed: false);
    await _settle(tester);
  }
  await _shot(tester, '11_address${addressOk ? '_picked' : '_inject_failed'}');

  // 장소 유형 / 입장 방식은 기본값(PLAYGROUND / FREE) 사용 — FREE 라 B 가
  // 승인 없이 바로 입장할 수 있다.
  await _shot(tester, '12_form_complete');

  // 제출 — ListView 맨 아래 버튼이라 lazy build 로 아직 element 가 없을 수
  // 있다. scrollUntilVisible 로 끝까지 스크롤해 찾은 뒤 탭한다.
  final submit = find.byKey(const Key('btn-room-create-submit'));
  try {
    await tester.scrollUntilVisible(
      submit,
      400.0,
      scrollable: find.byType(Scrollable).first,
    );
    await _settle(tester);
  } catch (_) {}
  if (submit.evaluate().isNotEmpty) {
    await tester.tap(submit.first, warnIfMissed: false);
  }
  await _pumpSeconds(tester, 6);
  await _shot(tester, '13_after_submit');

  // 제출 성공 시 방 상세(/rooms/:id)로 이동.
  await _shot(tester, '14_room_created');

  // ─── 지도에서 방 확인 ───────────────────────────────────
  // 방 상세 → 뒤로 → 홈 → "지도" 탭.
  final backFromDetail = find.byIcon(Icons.arrow_back_ios_new_rounded);
  if (backFromDetail.evaluate().isNotEmpty) {
    await tester.tap(backFromDetail.first, warnIfMissed: false);
    await _settle(tester);
  }
  final mapTab = find.text('지도');
  if (mapTab.evaluate().isNotEmpty) {
    await tester.tap(mapTab.first, warnIfMissed: false);
    await _settle(tester);
    // NaverMap 로딩 + 카메라 idle → 마커 렌더링까지 충분히 대기.
    await tester.runAsync(() async {
      await Future.delayed(const Duration(seconds: 6));
    });
    await _pumpSeconds(tester, 2);
    await _shot(tester, '15_map');
  } else {
    await _shot(tester, '15_map_tab_missing');
  }
}

Future<void> _runRoleB(WidgetTester tester) async {
  // ─── 로그인 ─────────────────────────────────────────────
  app.main();
  await _settle(tester, fallbackSeconds: 5);
  await _skipOnboarding(tester);
  await _shot(tester, '01_login_screen');

  await _tapKey(tester, const Key('btn-start-email'));
  await _settle(tester);
  await _emailLogin(tester);
  await _shot(tester, '02_home');

  // ─── A 가 만든 방 카드 탭 → 방 상세 ─────────────────────
  final target = await _targetCard(tester);
  if (target == null) {
    print('[UI_TEST] 방 카드 없음 — A 의 UI 방 생성이 실패했을 수 있음');
    await _shot(tester, '99_no_rooms');
    return;
  }
  try {
    await tester.ensureVisible(target);
  } catch (_) {}
  await tester.tap(target, warnIfMissed: false);
  await _pumpSeconds(tester, 3);
  await _shot(tester, '03_room_detail');

  // ─── 참여하기 ───────────────────────────────────────────
  if (await _tapKey(tester, const Key('btn-room-detail-join'))) {
    await _pumpSeconds(tester, 5);
  }
  await _shot(tester, '04_after_join');

  // ─── 채팅방 입장 ────────────────────────────────────────
  if (await _tapKey(tester, const Key('btn-room-detail-chat'))) {
    await _pumpSeconds(tester, 3);
    await _shot(tester, '05_chat_room');
  } else {
    await _shot(tester, '05_chat_unavailable');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('회원가입→방만들기→지도 / 입장 — $_role', (tester) async {
    expect(_email.isNotEmpty, true, reason: 'UI_TEST_EMAIL 미주입');
    expect(_targetRoomTitle.isNotEmpty, true,
        reason: 'UI_TARGET_ROOM_TITLE 미주입');

    if (_role == 'A') {
      await _runRoleA(tester);
    } else {
      await _runRoleB(tester);
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
