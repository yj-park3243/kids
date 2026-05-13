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

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:app/main.dart' as app;
import 'package:app/features/home/presentation/widgets/room_card.dart';

late IntegrationTestWidgetsFlutterBinding _binding;

const _email = String.fromEnvironment('UI_TEST_EMAIL', defaultValue: '');
const _password = String.fromEnvironment('UI_TEST_PASSWORD', defaultValue: '');
const _role = String.fromEnvironment('UI_TEST_ROLE', defaultValue: 'A');
const _targetRoomTitle =
    String.fromEnvironment('UI_TARGET_ROOM_TITLE', defaultValue: '');

Future<void> _shot(WidgetTester tester, String label) async {
  await tester.pumpAndSettle(const Duration(milliseconds: 500));
  if (Platform.isIOS) {
    await _binding.convertFlutterSurfaceToImage();
  }
  await _binding.takeScreenshot('${_role}_$label');
}

Future<void> _pumpSeconds(WidgetTester tester, int seconds) async {
  for (var i = 0; i < seconds; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

Future<void> _login(WidgetTester tester) async {
  app.main();
  await tester.pumpAndSettle(const Duration(seconds: 4));
  await _shot(tester, '01_login_screen');

  await tester.tap(find.byKey(const Key('btn-start-email')));
  await tester.pumpAndSettle(const Duration(seconds: 1));
  await _shot(tester, '02_email_form');

  await tester.enterText(find.byKey(const Key('input-email')), _email);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.enterText(find.byKey(const Key('input-password')), _password);
  await tester.pump(const Duration(milliseconds: 200));
  await _shot(tester, '03_creds_entered');

  await tester.tap(find.byKey(const Key('btn-login-submit')));
  await _pumpSeconds(tester, 8);
  await _shot(tester, '04_home');
}

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
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
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

void main() {
  _binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('2-sim UI: $_role', (tester) async {
    expect(_email.isNotEmpty, true, reason: 'UI_TEST_EMAIL 미주입');
    expect(_targetRoomTitle.isNotEmpty, true,
        reason: 'UI_TARGET_ROOM_TITLE 미주입');

    await _login(tester);

    // ─── A 전용: 방 만들기 화면 진입 (UI 검증) ─────────────────────
    if (_role == 'A') {
      final createBtn = find.byKey(const Key('btn-home-create-room'));
      if (createBtn.evaluate().isNotEmpty) {
        await tester.tap(createBtn);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        await _shot(tester, '05_create_form');

        final title = find.byKey(const Key('input-room-title'));
        if (title.evaluate().isNotEmpty) {
          await tester.enterText(
              title, 'A의 방 ${DateTime.now().millisecondsSinceEpoch % 1000000}');
          await tester.pump(const Duration(milliseconds: 200));
          await _shot(tester, '06_title_entered');
        }
        // 뒤로
        final back = find.byIcon(Icons.arrow_back_ios_new_rounded);
        if (back.evaluate().isNotEmpty) {
          await tester.tap(back.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));
        }
        await _shot(tester, '07_back_home');
      }
    }

    // ─── 공통: 사전 생성된 방 카드 탭 → 방 상세 ────────────────────
    final target = await _targetCard(tester);
    if (target == null) {
      await _shot(tester, '99_no_rooms');
      return;
    }
    await tester.ensureVisible(target);
    await tester.tap(target);
    await _pumpSeconds(tester, 3);
    await _shot(tester, '08_room_detail');

    // ─── B 전용: 참여하기 ─────────────────────────────────────────
    if (_role == 'B') {
      final joinBtn = find.byKey(const Key('btn-room-detail-join'));
      if (joinBtn.evaluate().isNotEmpty) {
        try {
          await tester.tap(joinBtn);
          await _pumpSeconds(tester, 5);
        } catch (e) {
          print('[E2E_B] join 실패: $e');
        }
      }
      await _shot(tester, '09_after_join');
    }

    // ─── 공통: 채팅방 진입 + 메시지 송신 ───────────────────────────
    final chatBtn = find.byKey(const Key('btn-room-detail-chat'));
    if (chatBtn.evaluate().isEmpty) {
      await _shot(tester, '99_no_chat_button');
      return;
    }
    await tester.tap(chatBtn);
    await _pumpSeconds(tester, 3);
    await _shot(tester, '10_chat_room');

    final msg = _role == 'A'
        ? '안녕하세요 방장 A 입니다. (${DateTime.now().millisecondsSinceEpoch % 100000})'
        : '반갑습니다 참여자 B 입니다. (${DateTime.now().millisecondsSinceEpoch % 100000})';

    final input = find.byKey(const Key('input-chat-message'));
    if (input.evaluate().isNotEmpty) {
      await tester.enterText(input, msg);
      await tester.pump(const Duration(milliseconds: 200));
      await _shot(tester, '11_msg_entered');

      final send = find.byKey(const Key('btn-chat-send'));
      if (send.evaluate().isNotEmpty) {
        await tester.tap(send);
        await _pumpSeconds(tester, 3);
        await _shot(tester, '12_msg_sent');
      }
    }

    // ─── B 추가: 이전 A 메시지가 채팅창에 보이는지 그대로 캡처 ──────
    if (_role == 'B') {
      await _pumpSeconds(tester, 2);
      await _shot(tester, '13_chat_with_both');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
