// 2 시뮬레이터 UI 자동화 — 방장(A) + 참여자(B) 채팅 양방향.
//
// 사전 전제 (orchestrator):
//   - A/B 두 계정 가입 + 폰인증 + 프로필 + 자녀
//   - A 가 API 로 FREE 방을 사전 생성 (제목 UI_TARGET_ROOM_TITLE)
//   - 두 시뮬에 --dart-define 으로 UI_TEST_ROLE 만 다르게 주입
//   - 시뮬 race 회피를 위해 orchestrator 가 A → B 순차 drive
//
// 시나리오:
//   A (방장):
//     01 로그인 화면
//     02 이메일 폼
//     03 자격증명 입력
//     04 홈
//     05 "+" 방 만들기 진입 — UI 검증용 (저장은 안 함)
//     06 제목 입력
//     07 뒤로 → 홈
//     08 사전 생성된 우리 방 카드 탭 → 방 상세 (호스트)
//     09 "채팅방 입장" 탭 → 채팅방
//     10 "안녕하세요 방장 A" 메시지 송신
//     11 송신 완료
//
//   B (참여자):
//     01~04 동일
//     08 같은 방 카드 탭 → 방 상세
//     09 "참여하기" 탭 → 입장 완료
//     10 "채팅방 입장" 탭 → 채팅방 (A 메시지 보임)
//     11 "반갑습니다 참여자 B" 송신
//
// ── 이번 수정(왜) ──────────────────────────────────────────────────
// 5탭 개편 뒤 이 테스트는 "초록불인데 아무것도 검증하지 않는" 상태였다.
//  * 로그인 직후 도착지는 /home(대시보드)인데 거기엔 방 카드가 없다. 그런데
//    _targetCard 가 find.byType(RoomCard) 로 대시보드에서 카드를 찾다 항상 비었고,
//    비면 스크린샷만 찍고 return 해서 08~13 단계가 통째로 스킵된 채 통과했다.
//    → 카드를 찾기 전에 '모임 찾기'(/rooms) 로 이동하고, 그 목록의 위젯인
//      RoomCard 로 찾는다(RoomCard 는 '내 모임' 전용).
//  * 각 단계의 "finder 가 비면 조용히 return" 을 expect 하드 단언으로 바꿔
//    실패가 드러나게 했다. 방 진입·채팅 송신이 이 테스트의 존재 이유다.
//  * 로그인/스크린샷/탭이동은 helpers/ui_helpers.dart 로 통일했다
//    (iOS 키체인 잔존 토큰, iOS 스크린샷 무의미, 네이티브 탭바 회피).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:app/main.dart' as app;
import 'package:app/features/home/presentation/widgets/room_card.dart';
import 'package:app/features/room/presentation/room_detail_screen.dart';

import 'helpers/ui_helpers.dart';

late IntegrationTestWidgetsFlutterBinding _binding;

const _email = String.fromEnvironment('UI_TEST_EMAIL', defaultValue: '');
const _password = String.fromEnvironment('UI_TEST_PASSWORD', defaultValue: '');
const _role = String.fromEnvironment('UI_TEST_ROLE', defaultValue: 'A');
const _targetRoomTitle =
    String.fromEnvironment('UI_TARGET_ROOM_TITLE', defaultValue: '');

/// 사전 생성된 방 카드를 '모임 찾기'(/rooms) 목록에서 찾는다.
///
/// 로그인 직후 도착지인 홈 대시보드(/home)에는 방 카드가 아예 없으므로 탭부터
/// 옮긴다. 하단 탭은 iOS 26+ 에서 네이티브 뷰라 탭할 수 없어 라우터로 이동한다.
/// 목록이 쓰는 위젯은 RoomCard 가 아니라 RoomCard 다.
Future<Finder?> _targetCard(WidgetTester tester) async {
  await goTab(tester, '/rooms');
  // 목록은 시머 → 카드로 바뀐다. 카드가 하나라도 그려질 때까지 기다린다.
  await waitFor(tester, () => has(find.byType(RoomCard)), seconds: 40);
  if (!has(find.byType(RoomCard))) {
    debugPrint('[E2E_$_role] /rooms 목록에 카드가 하나도 없다');
    return null;
  }

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
      // 아래 has 체크에서 null 로 판정된다.
    }
  }
  // 제목이 안 잡히면 cards.first 로 대체하지 않는다 — 엉뚱한 방에 들어가
  // 채팅까지 성공해 버리면 거짓 통과가 된다.
  if (!has(find.text(_targetRoomTitle))) return null;

  return find
      .ancestor(
        of: find.text(_targetRoomTitle),
        matching: find.byType(RoomCard),
      )
      .first;
}

void main() {
  _binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('2-sim UI: $_role', (tester) async {
    expect(_email.isNotEmpty, true, reason: 'UI_TEST_EMAIL 미주입');
    expect(_targetRoomTitle.isNotEmpty, true,
        reason: 'UI_TARGET_ROOM_TITLE 미주입');

    // 01~04 로그인 — iOS 키체인에 남은 이전 실행 토큰으로 자동 로그인되면
    // 로그인 화면이 아예 안 뜨므로 app.main() 전에 지운다.
    await resetAuthState();
    app.main();

    final started = await waitForAppStart(tester);
    await shot(_binding, tester, '${_role}_01_login_screen');
    expect(started, true, reason: '앱이 로그인 화면까지 뜨지 않았다');

    // 02_email_form / 03_creds_entered 단계는 loginWithEmail 안에 있다.
    final loggedIn =
        await loginWithEmail(tester, email: _email, password: _password);
    await shot(_binding, tester, '${_role}_04_home');
    expect(loggedIn, true, reason: '로그인 실패 — $_email');

    // ─── A 전용: 방 만들기 화면 진입 (UI 검증) ─────────────────────
    // '+' 버튼(btn-home-create-room)은 '모임 찾기'(/rooms) 화면에만 있다.
    // 본 시나리오(방 진입·채팅)의 보조 단계라 실패해도 로그만 남기고 진행한다.
    if (_role == 'A') {
      await goTab(tester, '/rooms');
      final createBtn = find.byKey(const Key('btn-home-create-room'));
      if (await tapSafely(tester, createBtn, settle: 3)) {
        await shot(_binding, tester, '${_role}_05_create_form');

        final title = find.byKey(const Key('input-room-title'));
        if (has(title)) {
          await tester.enterText(
              title, 'A의 방 ${DateTime.now().millisecondsSinceEpoch % 1000000}');
          await tester.pump(const Duration(milliseconds: 300));
          await shot(_binding, tester, '${_role}_06_title_entered');
        } else {
          debugPrint('[E2E_$_role] 방 만들기 폼에 input-room-title 없음');
        }
        // 뒤로 — 저장하지 않는다.
        await tapSafely(
            tester, find.byIcon(Icons.arrow_back_ios_new_rounded), settle: 3);
        await shot(_binding, tester, '${_role}_07_back_home');
      } else {
        debugPrint('[E2E_$_role] btn-home-create-room 탭 실패 — 05~07 건너뜀');
      }
    }

    // ─── 공통: 사전 생성된 방 카드 탭 → 방 상세 ────────────────────
    final target = await _targetCard(tester);
    expect(target, isNotNull,
        reason: "'모임 찾기' 목록에서 방 카드를 찾지 못했다 — $_targetRoomTitle");

    final tapped = await tapSafely(tester, target!, settle: 4);
    expect(tapped, true, reason: '방 카드 탭 실패 — $_targetRoomTitle');

    // 상세는 진입 후 API 를 한 번 더 부르므로 화면 자체가 뜰 때까지 기다린다.
    final detailOpen = await waitFor(
        tester, () => has(find.byType(RoomDetailScreen)),
        seconds: 40);
    await shot(_binding, tester, '${_role}_08_room_detail');
    expect(detailOpen, true, reason: '방 상세 화면에 진입하지 못했다');

    // ─── B 전용: 참여하기 ─────────────────────────────────────────
    if (_role == 'B') {
      // 하단바는 상세 로딩이 끝난 뒤에 확정된다 — 버튼이 뜰 때까지 기다린다.
      final joinBtn = find.byKey(const Key('btn-room-detail-join'));
      final joinShown = await waitFor(tester, () => has(joinBtn), seconds: 25);
      expect(joinShown, true, reason: "B: '참여하기' 버튼이 없다");

      final joinTapped = await tapSafely(tester, joinBtn, settle: 3);
      expect(joinTapped, true, reason: "B: '참여하기' 탭 실패");

      // FREE 방이라 즉시 참여 확정 — 하단바가 '채팅방 입장'으로 바뀐다.
      // 버튼이 사라진 것만 보면 에러 스낵바가 떠도 통과하므로 전환까지 확인한다.
      final joined = await waitFor(
          tester, () => has(find.byKey(const Key('btn-room-detail-chat'))),
          seconds: 30);
      await shot(_binding, tester, '${_role}_09_after_join');
      expect(joined, true, reason: 'B: 참여 후 하단바가 채팅방 입장으로 바뀌지 않았다');
    }

    // ─── 공통: 채팅방 진입 + 메시지 송신 ───────────────────────────
    final chatBtn = find.byKey(const Key('btn-room-detail-chat'));
    final chatShown = await waitFor(tester, () => has(chatBtn), seconds: 25);
    expect(chatShown, true, reason: "'채팅방 입장' 버튼이 없다");

    final chatTapped = await tapSafely(tester, chatBtn, settle: 4);
    expect(chatTapped, true, reason: "'채팅방 입장' 탭 실패");

    final input = find.byKey(const Key('input-chat-message'));
    final inChat = await waitFor(tester, () => has(input), seconds: 30);
    await shot(_binding, tester, '${_role}_10_chat_room');
    expect(inChat, true, reason: '채팅방에 들어가지 못했다(입력창 없음)');

    final msg = _role == 'A'
        ? '안녕하세요 방장 A 입니다. (${DateTime.now().millisecondsSinceEpoch % 100000})'
        : '반갑습니다 참여자 B 입니다. (${DateTime.now().millisecondsSinceEpoch % 100000})';

    await tester.enterText(input, msg);
    await tester.pump(const Duration(milliseconds: 300));
    await shot(_binding, tester, '${_role}_11_msg_entered');

    // 전송되면 컨트롤러가 비워지고 말풍선에만 남는다. find.text 는 TextField
    // 안의 글자도 매칭하므로 존재 여부만 보면 '안 보냈는데 성공'으로 찍힌다 —
    // 입력창 서브트리 밖에 있는지까지 확인한다.
    bool sent() =>
        has(find.text(msg)) &&
        !has(find.descendant(of: input, matching: find.text(msg)));

    // 좌표 탭은 소프트 키보드에 가려 빗나갈 수 있어 키보드 send 액션을 먼저 쓴다.
    await tester.testTextInput.receiveAction(TextInputAction.send);
    var sendOk = await waitFor(tester, sent, seconds: 10);
    if (!sendOk) {
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 400));
      await tapSafely(tester, find.byKey(const Key('btn-chat-send')), settle: 2);
      sendOk = await waitFor(tester, sent, seconds: 10);
    }
    await shot(_binding, tester, '${_role}_12_msg_sent');
    expect(sendOk, true, reason: '채팅 메시지 송신 실패 — $msg');

    // ─── B 추가: 이전 A 메시지가 채팅창에 보이는지 ──────────────────
    // 원래는 스크린샷만 찍었지만 iOS 는 캡처가 런치 이미지라 증거가 안 된다.
    // 양방향 확인이 이 시나리오의 목적이므로 finder 로 판정한다.
    // (A 의 메시지 꼬리 숫자는 B 가 모르므로 앞부분만 본다.)
    if (_role == 'B') {
      final sawA = await waitFor(
          tester, () => has(find.textContaining('안녕하세요 방장 A')),
          seconds: 20);
      await shot(_binding, tester, '${_role}_13_chat_with_both');
      expect(sawA, true, reason: 'B: 방장 A 의 메시지가 채팅방에 보이지 않는다');
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}
