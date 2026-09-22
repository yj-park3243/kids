// 회원가입 → 방 만들기 → 지도 확인 (A) / 다른 계정 로그인 → 방 입장 (B)
//
// 사전 전제 (orchestrator = run_ui_signup_flow.sh):
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
//   06 로그인 화면 복귀 → 사전셋업 A 계정으로 로그인 → 홈
//   07~12 방 만들기 4단계 (제목·설명 → 날짜·시간·장소 → 모집조건 → 비용·태그)
//   13~14 방 상세 도달 → 15 지도 탭 진입
//
// B (다른 계정 로그인 + 방 입장):
//   01 로그인 → 02 홈 → 03 '모임 찾기' 목록에서 A 의 방 → 방 상세
//   04 참여하기 → 05 채팅방 입장
//
// ─── 5탭 개편 + iOS 26 대응으로 고친 것 ────────────────────────────────
// 이전 버전은 초록불이면서 사실상 아무것도 검증하지 않았다.
//   - 로그인 후 도착지는 /home(대시보드)인데 방 만들기 버튼
//     (btn-home-create-room)은 '모임 찾기'(/rooms)에만 있다 → A 가 하드 실패.
//     이제 goTab(tester, '/rooms') 로 옮긴 뒤 누른다.
//   - 하단 탭은 iOS 26+ 에서 네이티브 탭바(플랫폼 뷰)라 위젯 트리에 없다.
//     find.text('지도') 같은 탭 이동은 무효 → 탭 이동은 전부 goTab(라우터).
//   - '모임 찾기' 목록 카드는 RoomCard 가 아니라 RoomCard 다. B 가
//     RoomCard 를 찾다 빈 finder 로 조용히 return 하며 통과하던 것을 expect 로 승격.
//   - 방 만들기는 4단계 위저드다. '다음'과 '모임 만들기'가 같은 키
//     (btn-room-create-submit)를 공유하므로 단계 이동은 AppBar 제목으로 확인한다.
//   - iOS 키체인은 앱 삭제 후에도 남아 이전 실행 토큰으로 자동 로그인된다
//     → app.main() 전에 resetAuthState().
//   - 스크린샷/로그인/탭 이동은 helpers/ui_helpers.dart 로 통일(iOS 는 캡처 스킵).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:app/main.dart' as app;
import 'package:app/features/home/presentation/widgets/room_card.dart';
import 'package:app/features/map/presentation/map_screen.dart';
import 'package:app/features/room/presentation/room_detail_screen.dart';

import 'helpers/ui_helpers.dart';

late IntegrationTestWidgetsFlutterBinding _binding;

const _email = String.fromEnvironment('UI_TEST_EMAIL', defaultValue: '');
const _password = String.fromEnvironment('UI_TEST_PASSWORD', defaultValue: '');
const _role = String.fromEnvironment('UI_TEST_ROLE', defaultValue: 'A');
const _targetRoomTitle =
    String.fromEnvironment('UI_TARGET_ROOM_TITLE', defaultValue: '');

/// 주소 JS 주입으로 넣는 값 — 폼에 반영됐는지 확인할 때 그대로 쓴다.
const _regionLabel = '서울특별시 강남구 역삼동';

Future<void> _shot(WidgetTester tester, String label) =>
    shot(_binding, tester, '${_role}_$label');

/// 방 만들기 위저드의 '다음'. 마지막 단계의 '모임 만들기'와 키를 공유하므로
/// (btn-room-create-submit) 단계가 실제로 넘어갔는지는 AppBar 제목으로 본다.
/// 필수 입력이 비면 토스트만 뜨고 제자리에 남는다 → false.
Future<bool> _wizardNext(WidgetTester tester, int nextStep) async {
  await tapSafely(tester, find.byKey(const Key('btn-room-create-submit')));
  return waitFor(tester, () => has(find.text('모임 만들기 ($nextStep/4)')),
      seconds: 10);
}

/// Cupertino 날짜/시간 시트를 기본값 그대로 '확인' 한다.
Future<bool> _confirmSheet(WidgetTester tester) async {
  if (!await waitFor(tester, () => has(find.text('확인')), seconds: 10)) {
    return false;
  }
  await tapSafely(tester, find.text('확인').last);
  return waitFor(tester, () => !has(find.text('확인')), seconds: 10);
}

/// Daum 우편번호 WebView 의 JS 채널(KidsPostcode)을 직접 호출해 주소를 주입.
/// WebView 내부 검색 UI 는 integration_test 로 조작할 수 없어, oncomplete 가
/// 부르는 postBack 과 동일한 payload 를 채널로 흘려보낸다.
Future<bool> _injectAddress(WidgetTester tester) async {
  if (!await waitFor(tester, () => has(find.byType(WebViewWidget)),
      seconds: 20)) {
    debugPrint('[UI] 주소 검색 시트가 열리지 않음');
    return false;
  }
  // WebView 는 네이티브라 pump 으로는 로드되지 않음 — 실제 시간으로 대기.
  await tester.runAsync(() async {
    await Future.delayed(const Duration(seconds: 7));
  });
  await pumpFor(tester, 1);

  final wv = find.byType(WebViewWidget);
  if (!has(wv)) {
    debugPrint('[UI] 대기 중 주소 WebView 가 사라짐');
    return false;
  }
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
    await pumpFor(tester, 2);
    return true;
  } catch (e) {
    debugPrint('[UI] 주소 JS 주입 실패: $e');
    return false;
  }
}

Future<void> _runRoleA(WidgetTester tester) async {
  // ─── 로그인 화면 ────────────────────────────────────────
  // 이전 실행의 토큰이 키체인에 남아 있으면 스플래시가 곧장 /home 으로 보내
  // 회원가입/로그인 단계가 통째로 사라진다.
  await resetAuthState();
  app.main();
  expect(await waitForAppStart(tester), true,
      reason: '앱이 로그인 화면까지 뜨지 않음');
  await _shot(tester, '01_login_screen');

  expect(await tapSafely(tester, find.byKey(const Key('btn-start-email'))),
      true, reason: '이메일 로그인 진입 실패');
  expect(await waitFor(tester, () => has(find.byKey(const Key('input-email'))),
          seconds: 15),
      true,
      reason: '이메일 로그인 화면이 뜨지 않음');
  await _shot(tester, '02_email_login');

  // ─── 회원가입 화면 (폼 작성까지만 시연) ──────────────────
  await tapSafely(tester, find.text('회원가입').last);
  expect(
      await waitFor(
          tester, () => has(find.byKey(const Key('input-register-email'))),
          seconds: 15),
      true,
      reason: '회원가입 화면 진입 실패');
  await _shot(tester, '03_register_form');

  // 가입 버튼을 누르면 KCP 본인인증 화면으로 진입하는데 PopScope(canPop:false)
  // 라 빠져나올 수 없고, 신규 이메일이 서버에 쌓인다. 폼 작성(= 본인인증
  // 직전)까지만 캡처하고 돌아간다.
  final newEmail = 'newcomer_${DateTime.now().millisecondsSinceEpoch}@test.com';
  await tester.enterText(
      find.byKey(const Key('input-register-email')), newEmail);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.enterText(
      find.byKey(const Key('input-register-password')), _password);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.enterText(
      find.byKey(const Key('input-register-password-confirm')), _password);
  await tester.pump(const Duration(milliseconds: 300));
  await _shot(tester, '04_register_filled');

  // 로그인 화면으로 복귀. email-login → 회원가입이 pushReplacement 라 뒤로가기
  // 목적지가 화면마다 달라진다 — 라우터로 확정적으로 되돌린다.
  await goTab(tester, '/login');
  expect(
      await waitFor(
          tester, () => has(find.byKey(const Key('btn-start-email'))),
          seconds: 15),
      true,
      reason: '로그인 화면 복귀 실패');

  // ─── 사전셋업 A 계정으로 로그인 ──────────────────────────
  expect(await loginWithEmail(tester, email: _email, password: _password), true,
      reason: '로그인 실패 — $_email');
  await _shot(tester, '06_home');

  // ─── 방 만들기 ──────────────────────────────────────────
  // 로그인 직후 도착지는 /home(대시보드)이고 방 만들기 버튼은 '모임 찾기'
  // (/rooms = HomeScreen)에만 있다. 탭바는 네이티브라 라우터로 옮긴다.
  await goTab(tester, '/rooms');
  final createBtn = find.byKey(const Key('btn-home-create-room'));
  expect(createBtn, findsOneWidget, reason: '모임 찾기 화면에 방 만들기 버튼이 없음');
  await tapSafely(tester, createBtn);
  expect(
      await waitFor(
          tester, () => has(find.byKey(const Key('input-room-title'))),
          seconds: 15),
      true,
      reason: '방 만들기 화면 진입 실패');
  await _shot(tester, '07_create_form');

  // 1단계 — 제목/설명 (제목 2~30자, 설명 10~500자 검증이 걸려 있다).
  await tester.enterText(
      find.byKey(const Key('input-room-title')), _targetRoomTitle);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.enterText(
    find.byKey(const Key('input-room-description')),
    'UI 자동화 — 회원가입→방만들기→지도 시나리오로 생성된 모임입니다.',
  );
  await tester.pump(const Duration(milliseconds: 300));
  await _shot(tester, '08_basic_filled');
  expect(await _wizardNext(tester, 2), true,
      reason: '1단계(제목·설명) → 2단계 이동 실패');

  // 2단계 — 날짜/시간/장소. 셋 다 채워야 3단계로 넘어간다.
  // 날짜 — 시트의 기본값(내일)을 그대로 "확인".
  await tapSafely(tester, find.byKey(const Key('btn-room-date')));
  expect(await _confirmSheet(tester), true, reason: '날짜 선택 시트 처리 실패');
  expect(has(find.text('날짜를 선택하세요')), false, reason: '날짜가 선택되지 않음');
  await _shot(tester, '09_date_picked');

  // 시작 시간 — 기본값(14:00) 그대로 "확인".
  await tapSafely(tester, find.byKey(const Key('btn-room-start-time')));
  expect(await _confirmSheet(tester), true, reason: '시작 시간 시트 처리 실패');
  expect(
      has(find.descendant(
          of: find.byKey(const Key('btn-room-start-time')),
          matching: find.text('시작 시간'))),
      false,
      reason: '시작 시간이 선택되지 않음');
  await _shot(tester, '10_time_picked');

  // 지역 — Daum WebView 를 띄운 뒤 JS 채널로 주소 주입.
  await tapSafely(tester, find.byKey(const Key('btn-room-address')));
  final addressOk = await _injectAddress(tester);
  await _shot(tester, '11_address${addressOk ? '_picked' : '_inject_failed'}');
  expect(addressOk, true, reason: '주소 WebView JS 주입 실패');

  // 주소가 정해지면 앱이 "정확한 위치 지정" 지도 시트를 이어서 띄운다.
  // 핀 보정은 이 테스트의 대상이 아니므로 닫는다(지오코딩/서버 폴백 좌표 사용).
  // 안 닫으면 시트가 남아 이후 탭이 전부 빗나간다.
  if (await waitFor(tester, () => has(find.text('이 위치로 선택')), seconds: 25)) {
    await tapSafely(tester, find.byIcon(Icons.close_rounded));
  } else {
    debugPrint('[UI] 위치 보정 시트 미표시 — 지오코딩이 늦거나 실패했을 수 있음');
  }
  expect(await waitFor(tester, () => has(find.text(_regionLabel)), seconds: 10),
      true, reason: '주소가 폼에 반영되지 않음');

  expect(await _wizardNext(tester, 3), true,
      reason: '2단계(일시·장소) → 3단계 이동 실패');

  // 3단계(모집 조건) / 4단계(비용·준비물·태그)는 기본값 그대로 — 입장 방식
  // 기본값이 FREE 라 B 가 승인 없이 바로 입장할 수 있다.
  expect(await _wizardNext(tester, 4), true,
      reason: '3단계(모집조건) → 4단계 이동 실패');
  await _shot(tester, '12_form_complete');

  // 제출 — 마지막 단계에서 같은 버튼이 '모임 만들기'가 된다.
  await tapSafely(tester, find.byKey(const Key('btn-room-create-submit')));
  // 생성 성공이면 create 를 pop 하고 /rooms/:id 를 push 한다. 대시보드에도 같은
  // 제목이 그려질 수 있어 반드시 RoomDetailScreen 서브트리 안에서 확인한다.
  final created = await waitFor(
    tester,
    () => has(find.descendant(
        of: find.byType(RoomDetailScreen),
        matching: find.text(_targetRoomTitle))),
    seconds: 40,
  );
  await _shot(tester, '13_after_submit');
  expect(created, true, reason: '방 생성 후 상세로 진입하지 못함 — $_targetRoomTitle');
  await _shot(tester, '14_room_created');

  // ─── 지도에서 방 확인 ───────────────────────────────────
  // 마커는 NaverMap(플랫폼 뷰) 안에 그려져 위젯 트리로 검증할 수 없다 —
  // 지도 탭 진입까지 단언하고 핀은 스크린샷(Android)으로 본다.
  await goTab(tester, '/map');
  expect(await waitFor(tester, () => has(find.byType(MapScreen)), seconds: 20),
      true, reason: '지도 탭 진입 실패');
  await pumpFor(tester, 8); // 지도 로드 + 카메라 idle → 마커 렌더 대기
  await _shot(tester, '15_map');
}

Future<void> _runRoleB(WidgetTester tester) async {
  // ─── 로그인 ─────────────────────────────────────────────
  await resetAuthState();
  app.main();
  expect(await waitForAppStart(tester), true,
      reason: '앱이 로그인 화면까지 뜨지 않음');
  await _shot(tester, '01_login_screen');

  expect(await loginWithEmail(tester, email: _email, password: _password), true,
      reason: '로그인 실패 — $_email');
  await _shot(tester, '02_home');

  // ─── A 가 만든 방 카드 탭 → 방 상세 ─────────────────────
  // 로그인 직후 도착지인 /home(대시보드)에는 방 카드가 없다. 목록은
  // '모임 찾기'(/rooms)에 있고 카드 타입은 RoomCard 다.
  await goTab(tester, '/rooms');
  final listed =
      await waitFor(tester, () => has(find.byType(RoomCard)), seconds: 40);
  await _shot(tester, '02b_room_list');
  expect(listed, true, reason: '모임 찾기 목록에 방 카드가 없음');

  if (!has(find.text(_targetRoomTitle))) {
    try {
      await tester.scrollUntilVisible(
        find.text(_targetRoomTitle),
        280,
        scrollable: find.byType(Scrollable).last,
        maxScrolls: 12,
      );
      await tester.pump(const Duration(milliseconds: 500));
    } catch (_) {
      // 아래 expect 에서 실패로 드러난다.
    }
  }
  expect(find.text(_targetRoomTitle), findsWidgets,
      reason: 'A 가 만든 방을 목록에서 찾지 못함 — $_targetRoomTitle');

  await tapSafely(
    tester,
    find
        .ancestor(
            of: find.text(_targetRoomTitle),
            matching: find.byType(RoomCard))
        .first,
    settle: 3,
  );
  final opened = await waitFor(
    tester,
    () => has(find.descendant(
        of: find.byType(RoomDetailScreen),
        matching: find.text(_targetRoomTitle))),
    seconds: 40,
  );
  await _shot(tester, '03_room_detail');
  expect(opened, true, reason: '방 상세 로드 실패 — $_targetRoomTitle');

  // ─── 참여하기 (FREE 방이라 승인 없이 즉시 참여) ──────────
  final joinBtn = find.byKey(const Key('btn-room-detail-join'));
  expect(joinBtn, findsOneWidget,
      reason: '참여하기 버튼이 없음 — 이미 참여 중이거나 참여 불가 상태');
  await tapSafely(tester, joinBtn, settle: 3);
  // 참여가 확정되면 하단 버튼이 '채팅방 입장'(btn-room-detail-chat)으로 바뀐다.
  final joined = await waitFor(
      tester, () => has(find.byKey(const Key('btn-room-detail-chat'))),
      seconds: 30);
  await _shot(tester, '04_after_join');
  expect(joined, true, reason: '참여 후 채팅방 입장 버튼이 나타나지 않음');

  // ─── 채팅방 입장 ────────────────────────────────────────
  await tapSafely(tester, find.byKey(const Key('btn-room-detail-chat')),
      settle: 3);
  final inChat = await waitFor(
      tester, () => has(find.byKey(const Key('input-chat-message'))),
      seconds: 30);
  await _shot(tester, '05_chat_room');
  expect(inChat, true, reason: '채팅방 진입 실패');
}

void main() {
  _binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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
