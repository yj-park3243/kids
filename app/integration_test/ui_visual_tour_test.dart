// 수첩안 UI 육안 검증용 투어 — 참여 이후 화면(홈 다음 모임 카드 · 내 모임 행 ·
// 방 상세 참여 상태 · 채팅방)을 호스트 스크린샷 서버(127.0.0.1:9998)로 찍는다.
//
// 실행: run_smoke.sh 와 같은 준비(HOST 방 1개 + USER 계정)가 필요하다.
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/ui_visual_tour_test.dart \
//     --dart-define=UI_TEST_EMAIL=... --dart-define=UI_TEST_PASSWORD=... \
//     --dart-define=UI_DEVICE_TAG=kids --dart-define=UI_TEST_SKIP_ATT=true
import 'package:app/core/router/app_router.dart';
import 'package:app/features/chat/presentation/chat_room_screen.dart';
import 'package:app/features/home/presentation/home_dashboard_screen.dart';
import 'package:app/features/home/presentation/home_screen.dart';
import 'package:app/features/home/presentation/widgets/room_card.dart';
import 'package:app/features/map/presentation/map_screen.dart';
import 'package:app/features/mypage/presentation/my_rooms_screen.dart';
import 'package:app/features/room/presentation/room_detail_screen.dart';
import 'package:app/main.dart' as app;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/ui_helpers.dart';

const _email = String.fromEnvironment('UI_TEST_EMAIL');
const _password = String.fromEnvironment('UI_TEST_PASSWORD');
const _deviceTag = String.fromEnvironment('UI_DEVICE_TAG', defaultValue: 'kids');

final _shotDio = Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 3),
  receiveTimeout: const Duration(seconds: 20),
));

Future<void> _shot(WidgetTester tester, String label) async {
  await pumpFor(tester, 1);
  try {
    await _shotDio.get('http://127.0.0.1:9998/${_deviceTag}_$label');
    await Future.delayed(const Duration(milliseconds: 500));
  } catch (_) {}
  print('[TOUR] $label');
}

Finder _in(Type scope, Finder f) =>
    find.descendant(of: find.byType(scope), matching: f);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('수첩안 UI 투어', (tester) async {
    expect(_email.isNotEmpty, true, reason: 'UI_TEST_EMAIL 미주입');
    await resetAuthState();
    app.main();
    expect(await waitForAppStart(tester), isTrue);
    expect(await loginWithEmail(tester, email: _email, password: _password),
        isTrue);

    // 1) 모임 찾기 → 첫 방 상세 → 참여하기
    await goTab(tester, '/rooms');
    final cards = _in(HomeScreen, find.byType(RoomCard));
    expect(await waitFor(tester, () => has(cards), seconds: 40), isTrue,
        reason: '모임 찾기 목록 비어 있음');
    await _shot(tester, 't01_rooms_list');
    await tapSafely(tester, cards.first);
    expect(
        await waitFor(tester, () => has(find.byType(RoomDetailScreen)),
            seconds: 30),
        isTrue);
    await _shot(tester, 't02_room_detail_before_join');

    final join = find.byKey(const Key('btn-room-detail-join'));
    if (await waitFor(tester, () => has(join), seconds: 10)) {
      await tapSafely(tester, join, settle: 3);
      // 참여 후 채팅 버튼이 뜰 때까지.
      await waitFor(tester,
          () => has(find.byKey(const Key('btn-room-detail-chat'))),
          seconds: 20);
    }
    await _shot(tester, 't03_room_detail_joined');

    // 방 상세 아래쪽(참여자·소개·약속)
    final scrollable = find.descendant(
        of: find.byType(RoomDetailScreen), matching: find.byType(Scrollable));
    if (has(scrollable)) {
      await tester.drag(scrollable.first, const Offset(0, -600));
      await pumpFor(tester, 1);
      await _shot(tester, 't04_room_detail_scrolled');
    }

    // 2) 채팅방 — 메시지 하나 보내기
    if (await tapSafely(
        tester, find.byKey(const Key('btn-room-detail-chat')), settle: 3)) {
      await waitFor(tester, () => has(find.byType(ChatRoomScreen)),
          seconds: 20);
      await _shot(tester, 't05_chat_empty');
      final input = find.byKey(const Key('input-chat-message'));
      if (has(input)) {
        await tester.enterText(input, '내일 뵐게요! 돗자리 챙겨갈게요 🙂');
        await pumpFor(tester, 1);
        await tapSafely(tester, find.byKey(const Key('btn-chat-send')),
            settle: 3);
        FocusManager.instance.primaryFocus?.unfocus();
        await pumpFor(tester, 1);
        await _shot(tester, 't06_chat_sent');
      }
      // 뒤로 (채팅 → 방 상세 → 목록)
      appRouter.pop();
      await pumpFor(tester, 2);
    }
    if (has(find.byType(RoomDetailScreen))) {
      appRouter.pop();
      await pumpFor(tester, 2);
    }

    // 3) 홈 — 다음 모임 카드
    await goTab(tester, '/home', settle: 4);
    await waitFor(tester, () => has(find.byType(HomeDashboardScreen)),
        seconds: 15);
    await pumpFor(tester, 3);
    await _shot(tester, 't07_home_next_meeting');

    // 4) 내 모임 — 행 + 안읽음
    await goTab(tester, '/my-rooms', settle: 4);
    await waitFor(tester, () => has(find.byType(MyRoomsScreen)), seconds: 15);
    await pumpFor(tester, 2);
    await _shot(tester, 't08_my_rooms');

    // 4.5) 지도 — 핀 시트: 미리보기 → 위로 끌어 펼침
    await goTab(tester, '/map', settle: 4);
    await waitFor(tester, () => has(find.byType(MapScreen)), seconds: 15);
    // 지도 데이터가 오길 기다렸다가 첫 핀 선택(네이티브 마커는 탭 불가).
    final opened = await waitFor(tester, () => MapScreen.debugSelectFirstPin(), seconds: 40);
    if (opened) {
      await waitFor(tester, () => has(find.byKey(const ValueKey('map-pin-sheet'))), seconds: 10);
      await pumpFor(tester, 2);
      await _shot(tester, 't08b_map_pin_peek');
      // 핸들을 위로 끌어 펼친다.
      final sheet = find.byKey(const ValueKey('map-pin-sheet'));
      final size = tester.getSize(find.byType(MapScreen));
      await tester.dragFrom(
        Offset(size.width / 2, size.height * (1 - 0.40) + 20),
        Offset(0, -size.height * 0.34),
      );
      await pumpFor(tester, 3);
      await _shot(tester, 't08c_map_pin_expanded');
      expect(has(sheet), isTrue);
    } else {
      print('[TOUR] map pin sheet skipped (no pins)');
    }

    // 5) 모임 만들기 폼 1단계 (본인인증 완료 계정)
    await goTab(tester, '/rooms', settle: 2);
    if (await tapSafely(
        tester, find.byKey(const Key('btn-home-create-room')), settle: 3)) {
      await pumpFor(tester, 2);
      await _shot(tester, 't09_room_create_step1');
      appRouter.pop();
      await pumpFor(tester, 2);
    }

    print('[TOUR_RESULT] done');
  });
}
