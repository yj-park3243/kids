// 3 시뮬레이터 UI e2e — 방장(A) + 수락되는 참여자(B) + 거절되는 참여자(C).
//
// 사전 전제 (orchestrator = run_ui_three_sim.sh):
//   - A/B/C 세 계정 가입 + 폰인증 + 프로필 + 자녀
//   - A 토큰으로 '승인 필요(APPROVAL)' 방을 사전 생성
//   - 시뮬 3대에 --dart-define 으로 ROLE/PHASE 만 다르게 주입
//   - 빌드 race 회피를 위해 순차 drive: B1 → C1 → A2 → B3 → C3
//
// 시나리오(비동기 흐름이라 역할마다 단계를 나눈다):
//   B/PHASE1  로그인 → '모임 찾기' 목록에서 방 찾기 → 참여 신청 → 승인 대기 확인
//   C/PHASE1  로그인 → 방 상세 직행 → 참여 신청 → 승인 대기 확인
//   A/PHASE2  로그인 → 방 상세 → 신청 2건 확인 → B 수락 / C 거절 → 채팅 송신
//   B/PHASE3  로그인 → 방 상세(참여 확정) → 채팅에서 A 메시지 확인 + 답장 → 모임 나가기
//   C/PHASE3  로그인 → 방 상세(거절됨) → 재신청 → 신청 취소
//
// 탭 이동은 위젯 탭이 아니라 전역 appRouter 로 한다 — iOS 26+ 는 네이티브
// 탭바(플랫폼 뷰)라 하단 탭이 Flutter 위젯 트리에 없다.

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:app/main.dart' as app;
import 'package:app/core/router/app_router.dart';
import 'package:app/core/storage/secure_storage.dart';
import 'package:app/features/home/presentation/widgets/room_card.dart';
import 'package:app/features/room/presentation/room_detail_screen.dart';

late IntegrationTestWidgetsFlutterBinding _binding;

const _email = String.fromEnvironment('UI_TEST_EMAIL', defaultValue: '');
const _password = String.fromEnvironment('UI_TEST_PASSWORD', defaultValue: '');
const _role = String.fromEnvironment('UI_TEST_ROLE', defaultValue: 'A');
const _phase = String.fromEnvironment('UI_TEST_PHASE', defaultValue: '1');
const _roomId = String.fromEnvironment('UI_TARGET_ROOM_ID', defaultValue: '');
const _roomTitle =
    String.fromEnvironment('UI_TARGET_ROOM_TITLE', defaultValue: '');
const _nickB = String.fromEnvironment('UI_NICK_B', defaultValue: '');
const _nickC = String.fromEnvironment('UI_NICK_C', defaultValue: '');
// 참여 확정자에게만 보이는 장소명 — '없음'이 아니라 '보임'으로 판정하기 위해 필요.
const _placeName =
    String.fromEnvironment('UI_TARGET_PLACE_NAME', defaultValue: '');

/// 실패해도 즉시 죽지 않고 모아서 마지막에 한 번에 보고한다 —
/// 중간에 끊기면 뒤쪽 스크린샷을 못 남겨 원인 파악이 어렵다.
final List<String> _failures = [];
int _stepNo = 0;

void _step(String name, bool ok, {String? detail}) {
  _stepNo++;
  final tag = ok ? 'OK  ' : 'FAIL';
  // 셸에서 grep 하기 쉬운 한 줄 포맷.
  debugPrint('[E2E][$_role$_phase][$tag] ${_stepNo.toString().padLeft(2, '0')} '
      '$name${detail == null ? '' : ' — $detail'}');
  if (!ok) _failures.add('[$_role$_phase] $name${detail == null ? '' : ' ($detail)'}');
}

Future<void> _shot(WidgetTester tester, String label) async {
  await tester.pump(const Duration(milliseconds: 500));
  // iOS 는 takeScreenshot 이 런치 이미지만 돌려줘(매 단계 동일) 증거가 되지 못한다.
  // 판정은 [E2E] 스텝 로그로 하고, 캡처는 Android 에서만 남긴다.
  if (!Platform.isAndroid) return;
  await _binding.convertFlutterSurfaceToImage();
  await tester.pump(const Duration(milliseconds: 200));
  try {
    await _binding.takeScreenshot('$_role$_phase' '_$label');
  } catch (e) {
    debugPrint('[E2E][$_role$_phase][WARN] 스크린샷 실패($label): $e');
  }
}

/// pumpAndSettle 은 무한 애니메이션(시머 등)에서 타임아웃 나므로 실시간 pump.
Future<void> _wait(WidgetTester tester, int seconds) async {
  for (var i = 0; i < seconds; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

/// 조건이 참이 될 때까지 1초 간격으로 기다린다.
/// 콜드 스타트·네트워크 왕복은 시뮬 부하에 따라 편차가 커서 고정 대기로는 불안정하다.
Future<bool> _waitFor(
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

Future<bool> _tapIfPresent(WidgetTester tester, Finder f,
    {int settle = 2}) async {
  if (f.evaluate().isEmpty) return false;
  await tester.tap(f.first, warnIfMissed: false);
  await _wait(tester, settle);
  return true;
}

bool _has(Finder f) => f.evaluate().isNotEmpty;

Future<void> _login(WidgetTester tester) async {
  // iOS 키체인은 앱을 지워도 남는다 — 이전 실행/이전 계정의 토큰이 있으면
  // 자동 로그인되어 로그인 화면이 아예 안 뜬다. 시작 전에 비운다.
  await SecureStorage.clearTokens();
  // 온보딩은 이 테스트의 검증 대상이 아니므로 완료 상태로 두고 건너뛴다.
  await SecureStorage.setOnboardingComplete();

  app.main();

  // 첫 설치 콜드 스타트는 스플래시 2초 + Firebase/부트스트랩까지 오래 걸린다.
  final started = await _waitFor(
    tester,
    () =>
        _has(find.byKey(const Key('btn-start-email'))) ||
        _has(find.text('건너뛰기')),
    seconds: 90,
  );
  _step('앱 기동', started);

  // 첫 설치면 온보딩부터 — 건너뛰기.
  if (await _tapIfPresent(tester, find.text('건너뛰기'), settle: 3)) {
    await _waitFor(
        tester, () => _has(find.byKey(const Key('btn-start-email'))),
        seconds: 20);
  }
  await _shot(tester, '01_login');

  final loginScreen = _has(find.byKey(const Key('btn-start-email')));
  _step('로그인 화면 진입', loginScreen);
  if (!loginScreen) return;

  await _tapIfPresent(tester, find.byKey(const Key('btn-start-email')));
  await _waitFor(tester, () => _has(find.byKey(const Key('input-email'))),
      seconds: 15);

  await tester.enterText(find.byKey(const Key('input-email')), _email);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.enterText(find.byKey(const Key('input-password')), _password);
  await tester.pump(const Duration(milliseconds: 300));
  // 소프트 키보드가 떠 있으면 스크롤 폼 아래쪽의 로그인 버튼을 덮어
  // 탭이 빗나간다 — 포커스를 풀고 버튼을 화면 안으로 끌어온다.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 600));
  _step('이메일 입력 반영', _has(find.text(_email)), detail: _email);
  await _shot(tester, '02_creds');

  // 시뮬 첫 HTTPS 요청은 connectTimeout(10초)에 걸리는 일이 잦다 — 재시도한다.
  var loggedIn = false;
  for (var attempt = 1; attempt <= 3 && !loggedIn; attempt++) {
    final submit = find.byKey(const Key('btn-login-submit'));
    if (!_has(submit)) break;
    try {
      await tester.ensureVisible(submit);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(submit);
    } catch (e) {
      debugPrint('[E2E][$_role$_phase][WARN] 로그인 탭 실패: $e');
    }
    // 버튼이 사라진 것만으로는 부족하다 — 폰인증/프로필 설정 화면으로 빠져도
    // 사라진다. 홈 대시보드 상단 타이틀까지 확인한다.
    loggedIn = await _waitFor(
      tester,
      () =>
          !_has(find.byKey(const Key('btn-login-submit'))) &&
          _has(find.text('같이크자')),
      seconds: 25,
    );
    if (!loggedIn) {
      debugPrint('[E2E][$_role$_phase][RETRY] 로그인 재시도 $attempt');
    }
  }
  await _shot(tester, '03_after_login');
  _step('로그인 성공', loggedIn);
}

/// 방 상세로 직행 — 목록 스크롤 의존을 없애 결정적으로 만든다.
/// 상세는 진입 후 API 를 한 번 더 부르므로 제목이 뜰 때까지 기다린다.
Future<bool> _openRoomById(WidgetTester tester) async {
  appRouter.push('/rooms/$_roomId');
  // 홈 대시보드의 '다음 약속' 카드에도 같은 제목이 그려져 있어, 화면 전체에서
  // 제목을 찾으면 상세가 뜨기도 전에 참이 된다(로딩 중 상세는 제목이 없다).
  // 반드시 RoomDetailScreen 서브트리 안에서 확인한다.
  final ok = await _waitFor(
    tester,
    () => _has(find.descendant(
        of: find.byType(RoomDetailScreen), matching: find.text(_roomTitle))),
    seconds: 40,
  );
  _step('방 상세 로드', ok, detail: _roomTitle);
  return ok;
}

/// '모임 찾기' 목록에서 제목으로 방 카드를 찾아 탭한다(B/PHASE1 만 사용).
Future<bool> _openRoomFromList(WidgetTester tester) async {
  appRouter.go('/rooms');
  // 목록은 시머 → 카드로 바뀐다. 카드가 하나라도 그려질 때까지 기다린다.
  await _waitFor(tester, () => _has(find.byType(RoomCard)), seconds: 40);
  await _shot(tester, '04_room_list');

  if (!_has(find.text(_roomTitle))) {
    try {
      await tester.scrollUntilVisible(
        find.text(_roomTitle),
        280,
        scrollable: find.byType(Scrollable).last,
        maxScrolls: 12,
      );
      await tester.pump(const Duration(milliseconds: 500));
    } catch (_) {
      // 아래 _has 체크에서 실패로 잡힌다.
    }
  }
  if (!_has(find.text(_roomTitle))) return false;

  final card = find
      .ancestor(of: find.text(_roomTitle), matching: find.byType(RoomCard))
      .first;
  await tester.ensureVisible(card);
  await tester.tap(card, warnIfMissed: false);
  // 탭 직후엔 상세가 아직 로딩 중이다(하단바도 없다). 목록에도 같은 제목이
  // 있으므로 반드시 RoomDetailScreen 서브트리 안에서 확인한다.
  final opened = await _waitFor(
    tester,
    () => _has(find.descendant(
        of: find.byType(RoomDetailScreen), matching: find.text(_roomTitle))),
    seconds: 40,
  );
  _step('방 상세 로드', opened, detail: _roomTitle);
  return opened;
}

/// 방 상세 ⋮ 메뉴를 열고 항목을 탭한다.
Future<bool> _tapMenuItem(WidgetTester tester, String label) async {
  if (!await _tapIfPresent(tester, find.byIcon(Icons.more_vert_rounded))) {
    return false;
  }
  // pumpAndSettle 의 첫 인자는 타임아웃이 아니라 pump 간격이다 — 무한
  // 애니메이션이 있으면 기본 10분까지 매달리므로 실시간 대기를 쓴다.
  await _wait(tester, 1);
  if (!_has(find.text(label))) return false;
  await tester.tap(find.text(label).last, warnIfMissed: false);
  await _wait(tester, 1);
  return true;
}

/// CupertinoActionSheet 의 액션 버튼을 누른다.
/// [sheetTitle] 로 시트가 실제로 떴는지 먼저 확인한다 — 확인 없이 라벨만 찾으면
/// 시트가 안 떴을 때도 '실행됨'으로 찍힌다.
Future<bool> _tapSheetAction(
    WidgetTester tester, String sheetTitle, String label) async {
  if (!_has(find.text(sheetTitle))) {
    debugPrint('[E2E][$_role$_phase][WARN] 시트 미표시: $sheetTitle');
    return false;
  }
  if (!_has(find.text(label))) return false;
  try {
    // 하단바에 같은 문구가 있을 수 있어 가장 나중에 그려진 것(시트)을 고른다.
    await tester.tap(find.text(label).last);
  } catch (e) {
    debugPrint('[E2E][$_role$_phase][WARN] 시트 액션 탭 실패($label): $e');
    return false;
  }
  await _wait(tester, 5);
  return true;
}

/// 채팅방에 들어가 메시지를 보낸다. 성공하면 true.
Future<bool> _sendChat(WidgetTester tester, String message) async {
  // 하단바는 참여 상태에 따라 버튼이 바뀐다 — 늦게 반영될 수 있어 기다린다.
  await _waitFor(tester,
      () => _has(find.byKey(const Key('btn-room-detail-chat'))),
      seconds: 20);
  final ok = await _tapIfPresent(
      tester, find.byKey(const Key('btn-room-detail-chat')),
      settle: 4);
  _step('채팅방 입장', ok);
  if (!ok) {
    // 어떤 하단바가 떠 있는지 남겨 원인을 좁힌다.
    for (final t in const [
      '참여하기', '참여 신청', '승인 대기 중', '모집이 마감되었습니다',
      '인원이 꽉 찼습니다', '채팅방 입장', '채팅방', '후기',
      '참여 확정 후 정확한 장소가 공개됩니다',
    ]) {
      if (_has(find.text(t))) {
        debugPrint('[E2E][$_role$_phase][DIAG] 화면에 있음: $t');
      }
    }
    debugPrint('[E2E][$_role$_phase][DIAG] '
        '사진첩버튼=${_has(find.byIcon(Icons.photo_library_outlined))} '
        '더보기=${_has(find.byIcon(Icons.more_vert_rounded))}');
    return false;
  }
  await _shot(tester, '20_chat_room');

  final input = find.byKey(const Key('input-chat-message'));
  if (!_has(input)) {
    _step('채팅 입력창 존재', false);
    return false;
  }
  await tester.enterText(input, message);
  await tester.pump(const Duration(milliseconds: 300));

  // 전송되면 컨트롤러가 즉시 비워지고 말풍선에만 남는다. 입력창에 그대로
  // 남아 있으면 미전송이다 — find.text 는 TextField 안의 글자도 매칭하므로
  // 존재 여부만 보면 '보내지 않았는데 성공'으로 찍힌다.
  bool sent() =>
      _has(find.text(message)) &&
      !_has(find.descendant(of: input, matching: find.text(message)));

  // 좌표 탭은 소프트 키보드에 가려 빗나갈 수 있다 — 입력창의 send 액션을 먼저 쓴다.
  await tester.testTextInput.receiveAction(TextInputAction.send);
  var ok2 = await _waitFor(tester, sent, seconds: 10);
  if (!ok2) {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 400));
    final sendBtn = find.byKey(const Key('btn-chat-send'));
    try {
      await tester.ensureVisible(sendBtn);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(sendBtn);
    } catch (e) {
      debugPrint('[E2E][$_role$_phase][WARN] 전송 버튼 탭 실패: $e');
    }
    ok2 = await _waitFor(tester, sent, seconds: 10);
  }
  await _shot(tester, '21_chat_sent');
  _step('채팅 메시지 송신', ok2, detail: message);
  return ok2;
}

void main() {
  _binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('3-sim e2e: $_role phase $_phase', (tester) async {
    expect(_email.isNotEmpty, true, reason: 'UI_TEST_EMAIL 미주입');
    expect(_roomId.isNotEmpty, true, reason: 'UI_TARGET_ROOM_ID 미주입');
    expect(_placeName.isNotEmpty, true, reason: 'UI_TARGET_PLACE_NAME 미주입');

    await _login(tester);

    // ══════════════════════════════════════════════════════════════
    // PHASE 1 — B/C 참여 신청
    // ══════════════════════════════════════════════════════════════
    if (_phase == '1') {
      if (_role == 'B') {
        // B 는 실제 탐색 경로(목록 → 카드)로 들어간다.
        final found = await _openRoomFromList(tester);
        _step('모임 찾기 목록에서 방 발견', found, detail: _roomTitle);
        if (!found && !await _openRoomById(tester)) return;
      } else {
        if (!await _openRoomById(tester)) return;
      }
      await _shot(tester, '05_room_detail');

      // 비참여자에게는 정확한 장소가 잠겨 있어야 한다(위치 노출 단계화).
      final locked = await _waitFor(
          tester, () => _has(find.text('참여 확정 후 정확한 장소가 공개됩니다')),
          seconds: 20);
      _step('비참여자 장소 잠금 표시', locked);

      // 하단바는 상세 로딩이 끝난 뒤에야 확정된다.
      final joinBtn = find.byKey(const Key('btn-room-detail-join'));
      final joinShown = await _waitFor(tester, () => _has(joinBtn), seconds: 20);
      _step('참여 신청 버튼 노출', joinShown);
      await _tapIfPresent(tester, joinBtn, settle: 2);
      // 승인 필요 방이므로 하단바가 '승인 대기 중 · 신청 취소하기' 로 바뀐다.
      final pending = await _waitFor(
          tester, () => _has(find.textContaining('승인 대기 중')),
          seconds: 30);
      await _shot(tester, '06_after_apply');
      _step('승인 대기 상태 표시', pending);
      return;
    }

    // ══════════════════════════════════════════════════════════════
    // PHASE 2 — A 방장: 수락/거절 + 채팅
    // ══════════════════════════════════════════════════════════════
    if (_phase == '2') {
      if (!await _openRoomById(tester)) return;
      await _shot(tester, '05_host_detail');

      // 신청 목록은 상세와 별개 API 라 늦게 도착한다 — 뜰 때까지 기다린다.
      final listed = await _waitFor(
          tester, () => _has(find.textContaining('참여 신청 (')),
          seconds: 40);
      _step('참여 신청 목록 노출', listed);
      _step('신청자 B 표시', _has(find.text(_nickB)), detail: _nickB);
      _step('신청자 C 표시', _has(find.text(_nickC)), detail: _nickC);
      await _shot(tester, '06_join_requests');

      // B 수락 — 닉네임이 든 신청 행 안의 '수락' 을 누른다.
      var accepted = false;
      if (_has(find.text(_nickB)) && _has(find.text('수락'))) {
        final row =
            find.ancestor(of: find.text(_nickB), matching: find.byType(Row));
        final inRow = find.descendant(of: row.first, matching: find.text('수락'));
        final target = _has(inRow) ? inRow.first : find.text('수락').first;
        // 남은 신청이 하나 줄어드는 것으로 판정한다 — 다른 신청(C)에도
        // '수락' 버튼이 남아 있어 존재 여부로는 알 수 없다.
        final before = find.text('수락').evaluate().length;
        try {
          await tester.ensureVisible(target);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(target);
          accepted = await _waitFor(
              tester, () => find.text('수락').evaluate().length < before,
              seconds: 20);
        } catch (e) {
          debugPrint('[E2E][$_role$_phase][WARN] 수락 탭 실패: $e');
        }
      }
      _step('B 참여 수락', accepted);
      await _shot(tester, '07_after_accept');

      // 수락이 실패하면 신청이 2건 남아 '거절' 의 first 가 B 일 수 있다 —
      // 운영 데이터를 잘못 바꾸지 않도록 여기서 멈춘다.
      if (!accepted) {
        _step('C 참여 거절', false, detail: '수락 실패로 중단');
        return;
      }

      // C 거절 — 남은 신청은 C 하나뿐이라 '거절' 이 유일하다.
      var rejected = false;
      if (_has(find.text('거절'))) {
        try {
          await tester.ensureVisible(find.text('거절').first);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(find.text('거절').first);
          rejected = await _waitFor(
              tester, () => !_has(find.text('거절')), seconds: 20);
        } catch (e) {
          debugPrint('[E2E][$_role$_phase][WARN] 거절 탭 실패: $e');
        }
      }
      _step('C 참여 거절', rejected);
      await _shot(tester, '08_after_reject');

      // 신청 목록이 비고 참여자가 2명(방장 A + B)이 됐는지로 판정한다 —
      // 닉네임 존재만 보면 아직 '참여 신청' 행에 남아 있어도 통과한다.
      final joined = await _waitFor(
          tester,
          () =>
              !_has(find.textContaining('참여 신청 (')) &&
              _has(find.textContaining('참여자 (2/')),
          seconds: 20);
      _step('참여자 목록에 B 포함', joined && _has(find.text(_nickB)));

      await _sendChat(tester, '방장 A 입니다. 내일 봬요!');
      return;
    }

    // ══════════════════════════════════════════════════════════════
    // PHASE 3 — B: 참여 확정 → 채팅 → 나가기 / C: 거절 확인 → 재신청 → 취소
    // ══════════════════════════════════════════════════════════════
    if (!await _openRoomById(tester)) return;
    await _shot(tester, '05_room_detail');

    if (_role == 'B') {
      // 참여가 확정되면 실제 장소명이 보인다. '잠금 문구가 없다'만 보면
      // 홈이나 로딩 화면에서도 통과하므로 긍정 판정을 함께 쓴다.
      _step(
          '참여 확정 후 장소 공개',
          _has(find.text(_placeName)) &&
              !_has(find.text('참여 확정 후 정확한 장소가 공개됩니다')),
          detail: _placeName);

      final chatOk = await _sendChat(tester, '참여자 B 입니다. 잘 부탁드려요!');
      _step('방장 A 메시지 수신 확인', _has(find.textContaining('방장 A 입니다')));
      await _shot(tester, '22_chat_both');
      // 채팅에 못 들어갔으면 이 아래는 방 상세가 아닌 화면에서 판정된다.
      if (!chatOk) return;

      // 채팅방 → 방 상세로 복귀.
      await _tapIfPresent(
          tester, find.byIcon(Icons.arrow_back_ios_new_rounded),
          settle: 3);
      final back = await _waitFor(
          tester, () => _has(find.byType(RoomDetailScreen)), seconds: 15);
      _step('방 상세 복귀', back);
      if (!back) return;

      // ── 모임 나가기 (이번에 추가한 기능) ──
      final menuOk = await _tapMenuItem(tester, '모임 나가기');
      _step('⋮ 메뉴에 모임 나가기 노출', menuOk);
      await _shot(tester, '30_leave_sheet');
      if (menuOk) {
        // 시작까지 24시간 이상 남은 방이라 노쇼가 안 붙는다는 안내가 나와야 한다.
        _step('노쇼 안내 문구 표시',
            _has(find.textContaining('노쇼')), detail: '확인 시트');
        final left = await _tapSheetAction(tester, '모임 나가기', '나가기');
        _step('나가기 실행', left);
        await _shot(tester, '31_after_leave');
        // 나가면 다시 비참여자 뷰 — 장소명이 사라지고 잠금 문구와 참여 버튼이 돌아온다.
        final relocked = await _waitFor(
            tester,
            () =>
                _has(find.text('참여 확정 후 정확한 장소가 공개됩니다')) &&
                !_has(find.text(_placeName)),
            seconds: 20);
        _step('나간 뒤 장소 재잠금', relocked);
        _step('나간 뒤 참여 버튼 복귀',
            _has(find.byKey(const Key('btn-room-detail-join'))));
      }
      return;
    }

    // ── C: 거절된 뒤 재신청 → 신청 취소 (이번에 추가한 기능) ──
    _step('거절 후 재신청 가능', _has(find.byKey(const Key('btn-room-detail-join'))));
    await _tapIfPresent(tester, find.byKey(const Key('btn-room-detail-join')),
        settle: 6);
    await _shot(tester, '10_reapplied');
    _step('재신청 후 승인 대기 표시', _has(find.textContaining('승인 대기 중')));

    // 하단바의 '승인 대기 중 · 신청 취소하기' 를 눌러 확인 시트를 연다.
    final pendingBtn = find.textContaining('승인 대기 중');
    await _tapIfPresent(tester, pendingBtn, settle: 2);
    await _shot(tester, '11_cancel_sheet');
    _step('신청 취소 시트 표시', _has(find.text('참여 신청 취소')));

    final cancelled = await _tapSheetAction(tester, '참여 신청 취소', '신청 취소하기');
    _step('신청 취소 실행', cancelled);
    await _wait(tester, 3);
    await _shot(tester, '12_after_cancel');
    _step('취소 후 참여 버튼 복귀',
        _has(find.byKey(const Key('btn-room-detail-join'))));
  }, timeout: const Timeout(Duration(minutes: 8)));

  tearDownAll(() {
    if (_failures.isEmpty) {
      debugPrint('[E2E][$_role$_phase][RESULT] ALL PASS ($_stepNo steps)');
    } else {
      debugPrint('[E2E][$_role$_phase][RESULT] ${_failures.length} FAILED '
          'of $_stepNo steps');
      for (final f in _failures) {
        debugPrint('[E2E][$_role$_phase][RESULT]   - $f');
      }
    }
    // 실패를 테스트 결과로 올려 flutter drive 가 0 이 아닌 코드로 끝나게 한다.
    expect(_failures, isEmpty, reason: _failures.join('\n'));
  });
}
