// 2 시뮬 UI 자동화 — 승인 방 (APPROVAL) 신청 → 승인 흐름.
//
// 사전 (orchestrator):
//   - A/B 두 계정 가입 + 폰인증 + 프로필 + 자녀
//   - A 토큰으로 APPROVAL 방 사전 생성 (UI_TARGET_ROOM_TITLE)
//   - 순차 drive: B(신청) → A(승인)
//
// 시나리오:
//   B (참여자, 먼저):
//     01~04 로그인 → 홈
//     08 방 카드 탭 → 방 상세
//     09 "참여 신청" 탭
//     10 "승인 대기 중" 상태 캡처
//
//   A (방장, 다음):
//     01~04 로그인 → 홈
//     08 방 카드 탭 → 방 상세 (호스트)
//     09 ⋮ 메뉴 열기
//     10 "참여 관리" 선택 → 신청 목록 진입
//     11 B 항목의 "수락" 탭
//     12 처리 완료

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
// 승인 대상 user id (A 시뮬에서 B 의 "수락" 버튼을 찾을 때 사용).
const _approveTargetUserId =
    String.fromEnvironment('UI_APPROVE_TARGET_USER_ID', defaultValue: '');

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
  final t = find.text(_targetRoomTitle);
  if (t.evaluate().isNotEmpty) {
    return find.ancestor(of: t, matching: find.byType(RoomCard)).first;
  }
  try {
    await tester.scrollUntilVisible(
      find.text(_targetRoomTitle),
      300.0,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    return find
        .ancestor(of: find.text(_targetRoomTitle), matching: find.byType(RoomCard))
        .first;
  } catch (_) {
    return cards.first;
  }
}

void main() {
  _binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('approval $_role', (tester) async {
    expect(_email.isNotEmpty, true, reason: 'UI_TEST_EMAIL 미주입');
    expect(_targetRoomTitle.isNotEmpty, true, reason: 'UI_TARGET_ROOM_TITLE 미주입');

    await _login(tester);

    final target = await _targetCard(tester);
    if (target == null) {
      await _shot(tester, '99_no_rooms');
      return;
    }
    await tester.ensureVisible(target);
    await tester.tap(target);
    await _pumpSeconds(tester, 3);
    await _shot(tester, '08_room_detail');

    if (_role == 'B') {
      // ─── B: 참여 신청 ─────────────────────────────────────
      final joinBtn = find.byKey(const Key('btn-room-detail-join'));
      if (joinBtn.evaluate().isEmpty) {
        await _shot(tester, '99_no_join_button');
        return;
      }
      await tester.tap(joinBtn);
      await _pumpSeconds(tester, 4);
      await _shot(tester, '09_after_request');

      // 다시 그려진 화면에서 "승인 대기 중" SecondaryButton 보일 것
      await _pumpSeconds(tester, 2);
      await _shot(tester, '10_pending');
      return;
    }

    // ─── A: ⋮ 메뉴 → 참여 관리 ─────────────────────────────
    final menu = find.byIcon(Icons.more_vert_rounded);
    if (menu.evaluate().isEmpty) {
      await _shot(tester, '99_no_menu');
      return;
    }
    await tester.tap(menu.first);
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    await _shot(tester, '09_menu_opened');

    final manage = find.text('참여 관리');
    if (manage.evaluate().isEmpty) {
      await _shot(tester, '99_no_manage_item');
      return;
    }
    await tester.tap(manage.last);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await _shot(tester, '10_join_requests');

    // 특정 B 의 "수락" 버튼 (Key 매칭) — 없으면 첫 번째 ElevatedButton.
    Finder acceptBtn;
    if (_approveTargetUserId.isNotEmpty) {
      acceptBtn = find.byKey(Key('btn-accept-$_approveTargetUserId'));
      if (acceptBtn.evaluate().isEmpty) {
        acceptBtn = find.text('수락');
      }
    } else {
      acceptBtn = find.text('수락');
    }
    if (acceptBtn.evaluate().isEmpty) {
      await _shot(tester, '99_no_accept_button');
      return;
    }
    await tester.tap(acceptBtn.first);
    await _pumpSeconds(tester, 4);
    await _shot(tester, '11_accepted');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
