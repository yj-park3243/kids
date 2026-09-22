// 2 시뮬 UI 자동화 — 승인 방 (APPROVAL) 신청 → 승인 흐름.
//
// 사전 (orchestrator = run_ui_approval.sh):
//   - A/B 두 계정 가입 + 폰인증 + 프로필 + 자녀
//   - A 토큰으로 APPROVAL 방 사전 생성 (UI_TARGET_ROOM_TITLE)
//   - 순차 drive: B(신청) → A(수락)
//
// 시나리오:
//   B (참여자, 먼저):
//     01~04 로그인 → 홈
//     05 '모임 찾기' 목록에서 대상 방 카드 탭 → 방 상세
//     09 "참여 신청" 탭
//     10 "승인 대기 중" 상태 확인
//
//   A (방장, 다음):
//     01~04 로그인 → 홈
//     05 '모임 찾기' 목록에서 같은 방 탭 → 방 상세 (호스트)
//     09 방 상세 인라인 '참여 신청 (N)' 목록 확인
//     11 B 행의 "수락" 탭 → 신청 1건 감소 확인
//
// 5탭 개편 이후 고친 것:
//   - 로그인 직후 도착지는 /home 대시보드다. 거기에는 RoomCard 가 없어
//     find.byType(RoomCard) 가 항상 비었고, 비면 조용히 return 해서 나머지
//     단계가 통째로 스킵된 채 초록불이 났다. → goTab('/rooms') 로 옮긴 뒤
//     그 화면이 실제로 쓰는 RoomCard 에서 제목으로 찾는다.
//   - A 의 수락 경로가 ⋮ 메뉴의 '참여 관리' 였는데 그런 메뉴 항목은 없다
//     ('참여 관리' 는 JoinRequestScreen 의 AppBar 제목일 뿐). 방장은 방 상세
//     참여자 섹션 위에 인라인으로 뜨는 신청 목록에서 바로 수락한다.
//   - 조용히 return 하던 지점은 전부 expect 하드 단언으로 승격했다.
//   - 로그인/스크린샷/탭/탭이동은 helpers/ui_helpers.dart 로 통일.

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
// 승인 대상 user id. 인라인 신청 목록에는 위젯 Key 가 없어 id 로 행을 특정할 수
// 없다(btn-accept-<id> 는 JoinRequestScreen 쪽 키다) — 로그 대조용으로만 남긴다.
const _approveTargetUserId =
    String.fromEnvironment('UI_APPROVE_TARGET_USER_ID', defaultValue: '');
// 승인 대상 닉네임(선택). 넘어오면 그 닉네임이 든 신청 행의 '수락' 을 고른다.
// 안 넘어오면 첫 번째 '수락' 을 누른다(2 시뮬 흐름은 신청이 B 하나뿐).
const _approveTargetNick =
    String.fromEnvironment('UI_APPROVE_TARGET_NICK', defaultValue: '');

Future<void> _login(WidgetTester tester) async {
  // iOS 키체인은 앱을 지워도 남는다 — 이전 실행의 토큰으로 자동 로그인되면
  // 로그인 화면이 아예 안 뜬다. app.main() 전에 비운다.
  await resetAuthState();

  app.main();

  final started = await waitForAppStart(tester);
  await shot(_binding, tester, '${_role}_01_login_screen');
  expect(started, true, reason: '앱이 로그인 화면까지 뜨지 않음');

  final ok =
      await loginWithEmail(tester, email: _email, password: _password);
  await shot(_binding, tester, '${_role}_04_home');
  expect(ok, true, reason: '로그인 실패 — 홈 대시보드(같이크자)에 도달하지 못함');
}

/// '모임 찾기'(/rooms) 목록에서 제목으로 방을 찾아 상세로 들어간다.
/// 하단 탭은 iOS 26+ 네이티브 탭바라 탭할 수 없어 라우터로 옮긴다(goTab).
Future<bool> _openRoomFromList(WidgetTester tester) async {
  await goTab(tester, '/rooms');
  // 목록은 시머 → 카드로 바뀐다. 카드가 하나라도 그려질 때까지 기다린다.
  await waitFor(tester, () => has(find.byType(RoomCard)), seconds: 40);
  await shot(_binding, tester, '${_role}_05_room_list');

  final title = find.text(_targetRoomTitle);
  if (!has(title)) {
    try {
      await tester.scrollUntilVisible(
        title,
        280,
        scrollable: find.byType(Scrollable).last,
        maxScrolls: 12,
      );
      await tester.pump(const Duration(milliseconds: 500));
    } catch (_) {
      // 아래 has 체크 → 호출부 expect 에서 실패로 드러난다.
    }
  }
  if (!has(title)) return false;

  final card =
      find.ancestor(of: title, matching: find.byType(RoomCard)).first;
  await tapSafely(tester, card, settle: 4);

  // 상세는 진입 후 API 를 한 번 더 부른다. 홈 대시보드/목록에도 같은 제목이
  // 그려져 있어, 반드시 RoomDetailScreen 서브트리 안에서 확인한다.
  return waitFor(
    tester,
    () => has(find.descendant(
        of: find.byType(RoomDetailScreen), matching: title)),
    seconds: 40,
  );
}

void main() {
  _binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('approval $_role', (tester) async {
    expect(_email.isNotEmpty, true, reason: 'UI_TEST_EMAIL 미주입');
    expect(_targetRoomTitle.isNotEmpty, true, reason: 'UI_TARGET_ROOM_TITLE 미주입');

    await _login(tester);

    final opened = await _openRoomFromList(tester);
    await shot(_binding, tester, '${_role}_08_room_detail');
    expect(opened, true,
        reason: "'모임 찾기' 목록에서 방 상세를 열지 못함: $_targetRoomTitle");

    if (_role == 'B') {
      // ─── B: 참여 신청 ─────────────────────────────────────
      final joinBtn = find.byKey(const Key('btn-room-detail-join'));
      expect(has(joinBtn), true, reason: '참여 신청 버튼 없음 (이미 신청/참여 상태?)');
      await tapSafely(tester, joinBtn, settle: 2);
      await shot(_binding, tester, '${_role}_09_after_request');

      // 승인 필요 방이라 하단바가 '승인 대기 중 · 신청 취소하기' 로 바뀐다.
      final pending = await waitFor(
          tester, () => has(find.textContaining('승인 대기 중')),
          seconds: 30);
      await shot(_binding, tester, '${_role}_10_pending');
      expect(pending, true, reason: '참여 신청 후 승인 대기 상태가 표시되지 않음');
      return;
    }

    // ─── A: 방 상세 인라인 신청 목록에서 수락 ────────────────
    // 이 목록은 방 상세와 별개 API 라 늦게 도착한다 — 뜰 때까지 기다린다.
    debugPrint('[UI] 승인 대상 user=$_approveTargetUserId nick=$_approveTargetNick');
    final listed = await waitFor(
        tester, () => has(find.textContaining('참여 신청 (')),
        seconds: 40);
    await shot(_binding, tester, '${_role}_09_join_requests');
    expect(listed, true, reason: '방장 화면에 인라인 참여 신청 목록이 뜨지 않음');

    final accept = find.text('수락');
    expect(has(accept), true, reason: "'수락' 버튼 없음 — B 신청이 도착하지 않았을 수 있음");

    // 신청자 닉네임이 든 행 안의 '수락' 을 고른다. 닉네임을 못 받았거나 못
    // 찾으면 첫 번째(2 시뮬 흐름은 신청이 하나뿐).
    var target = accept.first;
    if (_approveTargetNick.isNotEmpty && has(find.text(_approveTargetNick))) {
      final row = find.ancestor(
          of: find.text(_approveTargetNick), matching: find.byType(Row));
      final inRow = find.descendant(of: row.first, matching: accept);
      if (has(inRow)) target = inRow.first;
    }

    // 성공 판정은 '수락' 개수 감소로 한다 — 다른 신청에도 '수락' 이 남아 있어
    // 존재 여부로는 알 수 없다.
    final before = accept.evaluate().length;
    await tapSafely(tester, target, settle: 2);
    final accepted = await waitFor(
        tester, () => find.text('수락').evaluate().length < before,
        seconds: 20);
    await shot(_binding, tester, '${_role}_11_accepted');
    expect(accepted, true,
        reason: '수락 후에도 신청이 그대로 남아 있음 (before=$before)');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
