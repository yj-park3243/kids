// UI 자동화 풀 시나리오 —
//   로그인 → 방 만들기 화면 → 방 입장 → 채팅 → 신고 → 후기 → 차단 해제.
//
// 사전 전제 (orchestrator = run_ui_test.sh):
//   - 1 계정 회원가입 + 폰인증 우회 + 프로필 + 자녀 1
//   - 입장할 FREE 방 사전 생성 (다른 호스트) → orchestrator 가 별도 호스트 계정으로 만듦
//   - UI_TEST_EMAIL / UI_TEST_PASSWORD / UI_TARGET_ROOM_TITLE 주입
//   - 드라이브 시작 150초 뒤 백그라운드로 room.status=COMPLETED (후기 단계용)
//
// 2026-08 수정 — 이 테스트가 '초록불인데 아무것도 검증하지 않던' 이유:
//   * 로그인 도착지는 /home(대시보드)인데 거기엔 RoomCard 가 없다. 방 목록은
//     '모임 찾기'(/rooms)이고 카드 타입도 RoomCard 다. finder 가 비면
//     조용히 return 해서 08 단계 이후가 통째로 스킵됐다.
//     → goTab('/rooms') + RoomCard + expect 하드 단언.
//   * ⋮ 메뉴 항목은 '신고 / 차단' 이다('신고하기' 는 시트가 열린 뒤의 제출 버튼).
//     find.text('신고하기').last 는 빈 iterable 이라 StateError 로 죽었다.
//   * iOS 26+ 는 네이티브 탭바(플랫폼 뷰)라 find.text('마이') 같은 탭 이동이 무효다.
//     → goTab(). 스크린샷도 iOS 는 런치 이미지만 나와서 helpers 의 shot() 이 건너뛴다.
//   * 채팅은 '문구가 보인다'만으로는 미전송도 통과한다 → 입력창이 비워졌는지까지 본다.
//
// 흐름(단계 번호는 기존 유지, 02/03 캡처는 loginWithEmail 안으로 들어갔다):
//   01_login_screen   → 앱 기동 + 로그인 화면
//   04_home           → 로그인 후 홈 대시보드
//   05_create_form    → '모임 찾기'의 "+" 버튼 탭 → 방 만들기 화면
//   06_title_entered  → 제목 입력
//   07_back_home      → 뒤로 (저장은 안 함, 날짜/지역 필수)
//   08_room_detail    → 목록에서 대상 방 카드 탭
//   09_after_join     → 참여하기 탭
//   10_chat_room      → 채팅방 입장
//   11_msg_entered / 12_msg_sent
//   13_back_to_detail / 14_menu_opened / 15_report_sheet
//   16_reason_selected / 17_report_submitted
//   18_room_detail_completed / 19_review_form / 20_review_comment_entered
//   21_review_submitted
//   22_mypage / 23_blocked_users / 24_unblock_dialog / 25_unblock_done

import 'package:dio/dio.dart';
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
const _targetRoomTitle =
    String.fromEnvironment('UI_TARGET_ROOM_TITLE', defaultValue: '');
// 차단 해제 시나리오용 — 시뮬 안에서 직접 차단 API 를 호출해 시점을 정확히
// 맞춘다 (orchestrator background sleep 은 시뮬 진행과 동기화가 안 됨).
const _userToken = String.fromEnvironment('UI_USER_TOKEN', defaultValue: '');
const _hostId = String.fromEnvironment('UI_HOST_ID', defaultValue: '');
const _apiBase = String.fromEnvironment('API_BASE_URL', defaultValue: '');

void main() {
  _binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('UI 풀 시나리오', (tester) async {
    expect(_email.isNotEmpty, true, reason: 'UI_TEST_EMAIL 미주입');

    // ─── 로그인 ─────────────────────────────────────────────
    // iOS 키체인은 앱을 지워도 남는다 — 이전 실행 토큰으로 자동 로그인되면
    // 로그인 화면이 아예 안 뜬다. main() 전에 비운다.
    await resetAuthState();
    app.main();

    final started = await waitForAppStart(tester);
    expect(started, true, reason: '앱이 로그인 화면까지 뜨지 않음');
    await shot(_binding, tester, '01_login_screen');

    final loggedIn = await loginWithEmail(
      tester,
      email: _email,
      password: _password,
    );
    expect(loggedIn, true, reason: '로그인 실패 — 홈 대시보드에 도달하지 못함');
    await shot(_binding, tester, '04_home');

    // ─── 방 만들기 화면 진입 (제출은 안 함) ───────────────────
    // "+"(btn-home-create-room)는 홈 대시보드가 아니라 '모임 찾기'(/rooms)에 있다.
    await goTab(tester, '/rooms');
    final createBtn = find.byKey(const Key('btn-home-create-room'));
    if (has(createBtn)) {
      await tapSafely(tester, createBtn);
      await shot(_binding, tester, '05_create_form');

      // 제목만 입력 — 날짜/지역 등은 cupertino sheet / WebView 라 자동화 어려움.
      final titleInput = find.byKey(const Key('input-room-title'));
      if (has(titleInput)) {
        await tester.enterText(
          titleInput,
          'UI 자동화 모임 ${DateTime.now().millisecondsSinceEpoch % 1000000}',
        );
        await tester.pump(const Duration(milliseconds: 300));
        await shot(_binding, tester, '06_title_entered');
      } else {
        debugPrint('[UI_TEST] 방 만들기 제목 입력창 없음');
      }

      // 뒤로 가기 — CustomAppBar 의 IconButton.
      await tapSafely(tester, find.byIcon(Icons.arrow_back_ios_new_rounded));
      await shot(_binding, tester, '07_back_home');
    } else {
      // 생성 화면은 제출까지 하지 않는 보조 단계라 실패로 만들지 않는다.
      debugPrint('[UI_TEST] 모임 만들기 버튼 없음 — 05~07 단계 스킵');
    }

    // ─── 대상 방 카드 탭 → 방 상세 ──────────────────────────
    // 여기가 이 테스트의 존재 이유 — 카드가 없으면 뒤 단계가 전부 무의미하므로
    // 조용히 return 하지 않고 하드 단언한다.
    await goTab(tester, '/rooms');
    final cardListed = await waitFor(
      tester,
      () => has(find.byType(RoomCard)),
      seconds: 40,
    );
    expect(cardListed, true,
        reason: "'모임 찾기' 목록에 방 카드(RoomCard)가 없음");

    Finder target = find.byType(RoomCard).first;
    if (_targetRoomTitle.isNotEmpty) {
      if (!has(find.text(_targetRoomTitle))) {
        // 아래쪽에 있으면 스크롤. 칩 가로 ListView 가 여러 개라 방 목록은 마지막 Scrollable.
        try {
          await tester.scrollUntilVisible(
            find.text(_targetRoomTitle),
            280,
            scrollable: find.byType(Scrollable).last,
            maxScrolls: 12,
          );
          await tester.pump(const Duration(milliseconds: 500));
        } catch (_) {
          // 아래 has() 에서 폴백으로 잡힌다.
        }
      }
      if (has(find.text(_targetRoomTitle))) {
        target = find
            .ancestor(
              of: find.text(_targetRoomTitle),
              matching: find.byType(RoomCard),
            )
            .first;
      } else {
        debugPrint('[UI_TEST] 대상 방($_targetRoomTitle) 못 찾음 — 첫 카드로 폴백');
      }
    }
    await tapSafely(tester, target);

    // 상세는 진입 후 API 를 한 번 더 부른다 — 하단바 버튼이 뜰 때까지 기다린다.
    final detailReady = await waitFor(
      tester,
      () =>
          has(find.byKey(const Key('btn-room-detail-join'))) ||
          has(find.byKey(const Key('btn-room-detail-chat'))),
      seconds: 40,
    );
    expect(detailReady, true, reason: '방 상세가 로드되지 않음(참여/채팅 버튼 없음)');
    await shot(_binding, tester, '08_room_detail');

    // 후기 단계에서 상세를 다시 열어야 한다(재진입해야 status 가 갱신된다).
    // 목록을 다시 뒤지지 않도록 지금 roomId 를 잡아 둔다.
    final roomId = tester
        .widget<RoomDetailScreen>(find.byType(RoomDetailScreen).first)
        .roomId;

    // ─── 입장 시도 ─────────────────────────────────────────
    final joinBtn = find.byKey(const Key('btn-room-detail-join'));
    if (has(joinBtn)) {
      await tapSafely(tester, joinBtn);
    } else {
      debugPrint('[UI_TEST] 참여 버튼 없음 — 이미 참여 중으로 간주');
    }
    // FREE 방이라 신청 즉시 확정 → 하단바가 '채팅방 입장'으로 바뀐다.
    final joined = await waitFor(
      tester,
      () => has(find.byKey(const Key('btn-room-detail-chat'))),
      seconds: 40,
    );
    expect(joined, true, reason: '참여 후에도 채팅 버튼이 뜨지 않음 — 방 입장 실패');
    await shot(_binding, tester, '09_after_join');

    // ─── 채팅방 입장 ───────────────────────────────────────
    await tapSafely(
      tester,
      find.byKey(const Key('btn-room-detail-chat')),
      settle: 4,
    );
    final msgInput = find.byKey(const Key('input-chat-message'));
    final chatOpen = await waitFor(tester, () => has(msgInput), seconds: 30);
    expect(chatOpen, true, reason: '채팅방이 열리지 않음(입력창 없음)');
    await shot(_binding, tester, '10_chat_room');

    // ─── 메시지 입력 + 전송 ──────────────────────────────
    final message = '안녕하세요! UI 자동화 e2e ${DateTime.now().millisecondsSinceEpoch}';
    await tester.enterText(msgInput, message);
    await tester.pump(const Duration(milliseconds: 300));
    await shot(_binding, tester, '11_msg_entered');

    // 전송되면 컨트롤러가 비워지고 말풍선에만 남는다. find.text 는 TextField 안의
    // 글자도 매칭하므로 '보인다'만 보면 미전송도 성공으로 찍힌다.
    bool sent() =>
        has(find.text(message)) &&
        !has(find.descendant(of: msgInput, matching: find.text(message)));

    // 좌표 탭은 소프트 키보드에 가려 빗나갈 수 있어 입력창의 send 액션을 먼저 쓴다.
    await tester.testTextInput.receiveAction(TextInputAction.send);
    var msgSent = await waitFor(tester, sent, seconds: 10);
    if (!msgSent) {
      await tapSafely(tester, find.byKey(const Key('btn-chat-send')));
      msgSent = await waitFor(tester, sent, seconds: 10);
    }
    expect(msgSent, true, reason: '채팅 메시지 미전송 — 입력창에 문구가 그대로 남아 있음');
    await shot(_binding, tester, '12_msg_sent');

    // ─── 뒤로 → 방 상세 → 신고 ──────────────────────────────
    await tapSafely(tester, find.byIcon(Icons.arrow_back_ios_new_rounded));
    // ⋮ 는 방 상세에만 있다(채팅 화면엔 없다) — 복귀 판정에 쓴다.
    final backOnDetail = await waitFor(
      tester,
      () => has(find.byIcon(Icons.more_vert_rounded)),
      seconds: 20,
    );
    expect(backOnDetail, true, reason: '채팅방에서 방 상세로 돌아오지 못함');
    await shot(_binding, tester, '13_back_to_detail');

    await tapSafely(tester, find.byIcon(Icons.more_vert_rounded), settle: 1);
    await shot(_binding, tester, '14_menu_opened');

    // ⋮ 메뉴 항목은 '신고 / 차단' 이다. '신고하기' 는 시트가 열린 뒤의 제출 버튼이라
    // 여기서 찾으면 빈 iterable 이고, 예전 코드처럼 .last 를 붙이면 StateError 로 죽는다.
    final menuTapped = await tapSafely(tester, find.text('신고 / 차단'));
    expect(menuTapped, true, reason: "⋮ 메뉴에 '신고 / 차단' 항목이 없음");

    final sheetOpen = await waitFor(
      tester,
      () => has(find.byKey(const Key('btn-report-submit'))),
      seconds: 20,
    );
    expect(sheetOpen, true, reason: '신고 시트가 열리지 않음');
    await shot(_binding, tester, '15_report_sheet');

    // 사유 선택: ABUSE — 미선택이면 제출이 토스트만 띄우고 막힌다.
    final reasonTapped =
        await tapSafely(tester, find.byKey(const Key('report-reason-ABUSE')), settle: 1);
    expect(reasonTapped, true, reason: '신고 사유(ABUSE) 항목 없음');
    await shot(_binding, tester, '16_reason_selected');

    await tapSafely(tester, find.byKey(const Key('btn-report-submit')));
    // 접수되면 시트가 닫힌다 — 제출 버튼이 사라지는 것으로 판정한다.
    final reported = await waitFor(
      tester,
      () => !has(find.byKey(const Key('btn-report-submit'))),
      seconds: 20,
    );
    expect(reported, true, reason: '신고 제출 후에도 시트가 닫히지 않음');
    await shot(_binding, tester, '17_report_submitted');

    // ─── 모임 완료 후 후기 작성 ─────────────────────────────
    // orchestrator 가 드라이브 시작 150초 뒤 room.status=COMPLETED 로 바꾼다.
    // 빌드 시간 편차가 커서 고정 대기로는 어긋난다 — 상세를 다시 열어 보며 기다린다.
    // 상세는 initState 마다 loadRoom() 을 부르므로 재진입이 곧 새로고침이다.
    final reviewBtn = find.byKey(const Key('btn-room-detail-review'));
    var completed = false;
    for (var attempt = 0; attempt < 3 && !completed; attempt++) {
      await pumpFor(tester, attempt == 0 ? 45 : 30);
      await goTab(tester, '/home');
      await pushRoute(tester, '/rooms/$roomId');
      completed = await waitFor(tester, () => has(reviewBtn), seconds: 20);
    }
    await shot(_binding, tester, '18_room_detail_completed');
    expect(completed, true,
        reason: '모임이 COMPLETED 로 바뀌지 않아 후기 버튼이 없음(orchestrator 전제 확인)');

    await tapSafely(tester, reviewBtn);
    final reviewFormOpen = await waitFor(
      tester,
      () => has(find.byKey(const Key('btn-review-submit'))),
      seconds: 30,
    );
    expect(reviewFormOpen, true, reason: '후기 작성 화면이 열리지 않음');
    await shot(_binding, tester, '19_review_form');

    // 후기 대상 멤버의 코멘트 입력 — Key 가 멤버 ID 기반이라 prefix 매칭.
    final commentInputs = find.byWidgetPredicate((w) =>
        w.key is ValueKey<String> &&
        (w.key as ValueKey<String>).value.startsWith('input-review-comment-'));
    if (has(commentInputs)) {
      await tester.enterText(commentInputs.first, '함께해서 즐거웠어요! (UI 자동화)');
      await tester.pump(const Duration(milliseconds: 300));
      await shot(_binding, tester, '20_review_comment_entered');
    } else {
      // 코멘트는 선택 입력이라 없어도 점수(기본 5점)로 제출된다.
      debugPrint('[UI_TEST] 후기 코멘트 입력창 없음 — 점수만 제출');
    }

    await tapSafely(tester, find.byKey(const Key('btn-review-submit')), settle: 3);
    // 성공하면 화면이 pop 된다(실패 시 버튼이 그대로 남는다).
    final reviewDone = await waitFor(
      tester,
      () =>
          !has(find.byKey(const Key('btn-review-submit'))) ||
          has(find.text('제출 완료')),
      seconds: 30,
    );
    expect(reviewDone, true, reason: '후기 제출이 반영되지 않음');
    await shot(_binding, tester, '21_review_submitted');

    // ─── 차단 시드: 시뮬 안에서 직접 API 호출 (시점 정확) ──────
    // 후기 작성이 끝난 지금 넣어야 join/후기 멤버 목록에 영향이 없다.
    var seeded = false;
    if (_userToken.isNotEmpty && _hostId.isNotEmpty && _apiBase.isNotEmpty) {
      try {
        final res = await Dio().post(
          '$_apiBase/v1/blocks',
          data: {'targetUserId': _hostId},
          options: Options(
            headers: {'Authorization': 'Bearer $_userToken'},
            validateStatus: (_) => true,
          ),
        );
        seeded = (res.statusCode ?? 500) < 300;
        debugPrint('[UI_TEST] 차단 시드 status=${res.statusCode}');
      } catch (e) {
        debugPrint('[UI_TEST] 차단 시드 실패: $e');
      }
    } else {
      debugPrint('[UI_TEST] 차단 시드 정보(UI_USER_TOKEN/UI_HOST_ID/API_BASE_URL) 미주입');
    }

    // ─── 사용자 차단 해제 흐름 (마이 → 차단한 유저) ───────────
    // iOS 26+ 는 네이티브 탭바라 find.text('마이') 로는 탭을 누를 수 없다 → goTab.
    await goTab(tester, '/mypage');
    await shot(_binding, tester, '22_mypage');

    // 차단 대상이 없으면 해제할 것도 없다 — 실패가 아니라 미실행으로 남긴다.
    if (!seeded) {
      debugPrint('[UI_TEST] 차단 시드가 없어 차단 해제 단계 미실행');
      return;
    }

    final blockMenuTapped = await tapSafely(tester, find.text('차단한 유저'));
    expect(blockMenuTapped, true, reason: "마이페이지에 '차단한 유저' 메뉴가 없음");

    // 차단 해제 버튼 — Key 가 대상 유저 ID 기반이라 prefix 매칭.
    final unblockBtn = find.byWidgetPredicate((w) =>
        w.key is ValueKey<String> &&
        (w.key as ValueKey<String>).value.startsWith('btn-unblock-'));
    final blockedListed =
        await waitFor(tester, () => has(unblockBtn), seconds: 30);
    await shot(_binding, tester, '23_blocked_users');
    expect(blockedListed, true, reason: '차단 목록에 해제 버튼이 없음(시드가 반영되지 않음)');

    await tapSafely(tester, unblockBtn, settle: 1);
    // 확인 다이얼로그는 AwesomeDialog 라 전용 Key 가 없다 — 확인 버튼 문구('해제')로 찾는다.
    // 목록의 '차단 해제', 다이얼로그 제목 '차단 해제' 와는 문자열이 달라 겹치지 않는다.
    final confirm = find.text('해제');
    final dialogOpen = await waitFor(tester, () => has(confirm), seconds: 15);
    expect(dialogOpen, true, reason: '차단 해제 확인 다이얼로그가 뜨지 않음');
    await shot(_binding, tester, '24_unblock_dialog');

    await tapSafely(tester, confirm, settle: 3);
    // 해제되면 목록에서 사라진다.
    final unblocked = await waitFor(tester, () => !has(unblockBtn), seconds: 30);
    expect(unblocked, true, reason: '차단 해제 후에도 목록에 그대로 남아 있음');
    await shot(_binding, tester, '25_unblock_done');
    // 시나리오 마지막 단계 — 여기까지 오면 전 구간이 실제로 실행된 것이다.
  }, timeout: const Timeout(Duration(minutes: 10)));
}
