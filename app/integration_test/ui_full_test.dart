// UI 자동화 풀 시나리오 — 로그인 → 방 만들기 → 방 입장 → 채팅 메시지 전송.
//
// 사전 전제 (orchestrator):
//   - 1 계정 회원가입 + 폰인증 우회 + 프로필 + 자녀 1
//   - 입장할 FREE 방 사전 생성 (다른 호스트) → orchestrator 가 별도 호스트 계정으로 만듦
//   - UI_TEST_EMAIL / UI_TEST_PASSWORD 주입
//
// 흐름:
//   01_login_screen   → "이메일로 시작하기" 탭
//   02_email_form     → 이메일/비밀번호 입력
//   03_creds_entered
//   04_home           → 로그인 후 홈
//   05_create_form    → "+" 버튼 탭 → 방 만들기 화면
//   06_title_entered  → 제목 입력
//   07_back_home      → 뒤로 → 홈 복귀 (저장은 안 함, 날짜/지역 필수)
//   08_room_detail    → 첫 RoomCard 탭
//   09_after_join     → 참여하기 탭
//   10_chat_room      → 채팅방 입장 탭
//   11_msg_entered    → 메시지 입력
//   12_msg_sent       → 전송

import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:app/main.dart' as app;
import 'package:app/features/home/presentation/widgets/room_card.dart';

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

Future<void> _shot(WidgetTester tester, String label) async {
  await tester.pumpAndSettle(const Duration(milliseconds: 500));
  // native simctl 캡처 직전 짧게 한 프레임 더 pump — GPU commit 시간 확보.
  await tester.pump(const Duration(milliseconds: 200));
  if (Platform.isIOS) {
    await _binding.convertFlutterSurfaceToImage();
  }
  await _binding.takeScreenshot('ui_$label');
}

Future<void> _pumpSeconds(WidgetTester tester, int seconds) async {
  for (var i = 0; i < seconds; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  _binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('UI 풀 시나리오', (tester) async {
    expect(_email.isNotEmpty, true, reason: 'UI_TEST_EMAIL 미주입');

    // ─── 로그인 ─────────────────────────────────────────────
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

    // ─── 방 만들기 화면 진입 (제출은 안 함) ───────────────────
    final createBtn = find.byKey(const Key('btn-home-create-room'));
    if (createBtn.evaluate().isNotEmpty) {
      await tester.tap(createBtn);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await _shot(tester, '05_create_form');

      // 제목만 입력 — 날짜/지역 등은 cupertino sheet / WebView 라 자동화 어려움.
      final titleInput = find.byKey(const Key('input-room-title'));
      if (titleInput.evaluate().isNotEmpty) {
        await tester.enterText(
          titleInput,
          'UI 자동화 모임 ${DateTime.now().millisecondsSinceEpoch % 1000000}',
        );
        await tester.pump(const Duration(milliseconds: 200));
        await _shot(tester, '06_title_entered');
      }

      // 뒤로 가기 — CustomAppBar 의 IconButton.
      final back = find.byIcon(Icons.arrow_back_ios_new_rounded);
      if (back.evaluate().isNotEmpty) {
        await tester.tap(back.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }
      await _shot(tester, '07_back_home');
    }

    // ─── 우리 방 카드 탭 → 방 상세 (title 매칭) ──────────────
    final cards = find.byType(RoomCard);
    if (cards.evaluate().isEmpty) {
      print('[UI_TEST] 방 카드가 없어 입장 흐름 스킵');
      await _shot(tester, '99_no_rooms');
      return;
    }
    Finder target = cards.first;
    if (_targetRoomTitle.isNotEmpty) {
      // 우리가 사전 생성한 방의 제목으로 카드 찾기.
      // scroll 이 필요할 수 있어 ensureVisible 시도.
      final titleFinder = find.text(_targetRoomTitle);
      if (titleFinder.evaluate().isNotEmpty) {
        target = find
            .ancestor(of: titleFinder, matching: find.byType(RoomCard))
            .first;
      } else {
        // 안 보이면 list scroll 시도. 홈에는 칩 가로 ListView 가 여러 개 있고
        // 방 목록은 가장 마지막 ListView 라 .last 사용.
        try {
          final listFinder = find.byType(Scrollable).last;
          await tester.scrollUntilVisible(
            find.text(_targetRoomTitle),
            300.0,
            scrollable: listFinder,
          );
          await tester.pumpAndSettle(const Duration(milliseconds: 500));
          target = find
              .ancestor(
                of: find.text(_targetRoomTitle),
                matching: find.byType(RoomCard),
              )
              .first;
        } catch (_) {
          print('[UI_TEST] 대상 방($_targetRoomTitle) 못 찾음 — 첫 카드로 폴백');
        }
      }
    }
    await tester.ensureVisible(target);
    await tester.tap(target);
    await _pumpSeconds(tester, 3);
    await _shot(tester, '08_room_detail');

    // ─── 입장 시도 ─────────────────────────────────────────
    final joinBtn = find.byKey(const Key('btn-room-detail-join'));
    final chatBtn = find.byKey(const Key('btn-room-detail-chat'));

    if (joinBtn.evaluate().isNotEmpty) {
      try {
        await tester.tap(joinBtn);
        await _pumpSeconds(tester, 5);
      } catch (e) {
        print('[UI_TEST] join tap 실패: $e');
      }
    }
    await _shot(tester, '09_after_join');

    // ─── 채팅방 입장 ───────────────────────────────────────
    // 입장 후 버튼이 '채팅방 입장' 으로 바뀜.
    final chatBtnAfter = find.byKey(const Key('btn-room-detail-chat'));
    if (chatBtnAfter.evaluate().isNotEmpty) {
      await tester.tap(chatBtnAfter);
      await _pumpSeconds(tester, 3);
      await _shot(tester, '10_chat_room');

      // ─── 메시지 입력 + 전송 ──────────────────────────────
      final msgInput = find.byKey(const Key('input-chat-message'));
      if (msgInput.evaluate().isNotEmpty) {
        await tester.enterText(
          msgInput,
          '안녕하세요! UI 자동화 e2e ${DateTime.now().millisecondsSinceEpoch}',
        );
        await tester.pump(const Duration(milliseconds: 200));
        await _shot(tester, '11_msg_entered');

        final sendBtn = find.byKey(const Key('btn-chat-send'));
        if (sendBtn.evaluate().isNotEmpty) {
          await tester.tap(sendBtn);
          await _pumpSeconds(tester, 3);
          await _shot(tester, '12_msg_sent');
        }
      }

      // ─── 뒤로 → 방 상세 → 신고 시도 ─────────────────────
      final backFromChat = find.byIcon(Icons.arrow_back_ios_new_rounded);
      if (backFromChat.evaluate().isNotEmpty) {
        await tester.tap(backFromChat.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }
      await _shot(tester, '13_back_to_detail');

      // 우상단 ⋮ 메뉴 탭
      final menu = find.byIcon(Icons.more_vert_rounded);
      if (menu.evaluate().isNotEmpty) {
        await tester.tap(menu.first);
        await tester.pumpAndSettle(const Duration(milliseconds: 600));
        await _shot(tester, '14_menu_opened');

        // 신고하기 항목 탭
        final reportItem = find.text('신고하기').last;
        if (reportItem.evaluate().isNotEmpty) {
          await tester.tap(reportItem);
          await tester.pumpAndSettle(const Duration(seconds: 1));
          await _shot(tester, '15_report_sheet');

          // 사유 선택: ABUSE
          final reason = find.byKey(const Key('report-reason-ABUSE'));
          if (reason.evaluate().isNotEmpty) {
            await tester.tap(reason);
            await tester.pump(const Duration(milliseconds: 300));
            await _shot(tester, '16_reason_selected');
          }

          // 제출
          final submit = find.byKey(const Key('btn-report-submit'));
          if (submit.evaluate().isNotEmpty) {
            await tester.tap(submit);
            await _pumpSeconds(tester, 3);
            await _shot(tester, '17_report_submitted');
          }
        }
      }

      // ─── 모임 완료 후 후기 작성 ─────────────────────────────
      // orchestrator 가 백그라운드로 room.status=COMPLETED 처리.
      // 시뮬 client cache 갱신을 위해 충분히 wait 후 다시 진입.
      await _pumpSeconds(tester, 45);
      // 뒤로 → 홈 → 다시 방 카드 탭 (status 새로고침)
      final backFromReport = find.byIcon(Icons.arrow_back_ios_new_rounded);
      if (backFromReport.evaluate().isNotEmpty) {
        await tester.tap(backFromReport.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }
      // 홈 카드 재탭
      final cards2 = find.byType(RoomCard);
      if (cards2.evaluate().isNotEmpty) {
        Finder target2 = cards2.first;
        if (_targetRoomTitle.isNotEmpty) {
          final t = find.text(_targetRoomTitle);
          if (t.evaluate().isNotEmpty) {
            target2 = find
                .ancestor(of: t, matching: find.byType(RoomCard))
                .first;
          }
        }
        await tester.tap(target2);
        await _pumpSeconds(tester, 3);
        await _shot(tester, '18_room_detail_completed');

        final reviewBtn = find.byKey(const Key('btn-room-detail-review'));
        if (reviewBtn.evaluate().isNotEmpty) {
          await tester.tap(reviewBtn);
          await tester.pumpAndSettle(const Duration(seconds: 2));
          await _shot(tester, '19_review_form');

          // 후기 대상 멤버의 코멘트 입력 — Key 는 멤버 ID 기반이라 어떤
          // EditableText 든 하나 잡혀 있으면 그 중 첫 번째에 입력.
          final commentInputs = find.byWidgetPredicate((w) =>
              w.runtimeType.toString() == 'TextField' &&
              (w.key is ValueKey<String>) &&
              (w.key as ValueKey<String>).value
                  .startsWith('input-review-comment-'));
          if (commentInputs.evaluate().isNotEmpty) {
            await tester.enterText(
              commentInputs.first,
              '함께해서 즐거웠어요! (UI 자동화)',
            );
            await tester.pump(const Duration(milliseconds: 300));
            await _shot(tester, '20_review_comment_entered');
          }

          final submitReview = find.byKey(const Key('btn-review-submit'));
          if (submitReview.evaluate().isNotEmpty) {
            await tester.tap(submitReview);
            await _pumpSeconds(tester, 4);
            await _shot(tester, '21_review_submitted');
          }
        } else {
          await _shot(tester, '18_no_review_button');
        }
      }

      // ─── 차단 시드: 시뮬 안에서 직접 API 호출 (시점 정확) ──────
      // 후기 작성이 끝난 지금 시점에 차단을 넣어야 join/후기 멤버에 영향 없음.
      if (_userToken.isNotEmpty && _hostId.isNotEmpty && _apiBase.isNotEmpty) {
        try {
          await Dio().post(
            '$_apiBase/v1/blocks',
            data: {'targetUserId': _hostId},
            options: Options(
              headers: {'Authorization': 'Bearer $_userToken'},
              validateStatus: (_) => true,
            ),
          );
          print('[UI_TEST] 차단 시드 완료');
        } catch (e) {
          print('[UI_TEST] 차단 시드 실패: $e');
        }
      }

      // ─── 사용자 차단 해제 흐름 (마이페이지 → 차단한 유저) ─────
      // 후기 화면에서 뒤로(가능한 만큼) → 마이 탭 → 차단한 유저 → 해제.
      for (var i = 0; i < 3; i++) {
        final back = find.byIcon(Icons.arrow_back_ios_new_rounded);
        if (back.evaluate().isEmpty) break;
        await tester.tap(back.first);
        await tester.pumpAndSettle(const Duration(seconds: 1));
      }
      // 하단 탭 "마이" — 텍스트로 찾기. NavigationBar 위젯.
      final myTab = find.text('마이');
      if (myTab.evaluate().isNotEmpty) {
        await tester.tap(myTab.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        await _shot(tester, '22_mypage');

        // "차단한 유저" 메뉴 탭 — ListView 안에 있어 ensureVisible/scroll.
        final blockMenu = find.text('차단한 유저');
        if (blockMenu.evaluate().isNotEmpty) {
          try {
            await tester.ensureVisible(blockMenu.first);
          } catch (_) {}
          await tester.tap(blockMenu.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));
          await _shot(tester, '23_blocked_users');

          // 첫 차단 해제 버튼 — 동적 Key 라 prefix 매칭.
          final unblock = find.byWidgetPredicate((w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>)
                  .value
                  .startsWith('btn-unblock-') &&
              (w.key as ValueKey<String>).value != 'btn-unblock-confirm');
          if (unblock.evaluate().isNotEmpty) {
            await tester.tap(unblock.first);
            await tester.pumpAndSettle(const Duration(seconds: 1));
            await _shot(tester, '24_unblock_dialog');

            final confirm = find.byKey(const Key('btn-unblock-confirm'));
            if (confirm.evaluate().isNotEmpty) {
              await tester.tap(confirm);
              await _pumpSeconds(tester, 3);
              await _shot(tester, '25_unblock_done');
            }
          }
        }
      }
    } else {
      await _shot(tester, '10_chat_unavailable');
    }
  }, timeout: const Timeout(Duration(minutes: 7)));
}
