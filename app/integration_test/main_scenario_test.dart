// 두 시뮬레이터(A=방장, B=참여자) 병렬 e2e.
//
// 사전 전제 (orchestrator 쉘이 미리 처리):
//   - A, B 두 계정 회원가입
//   - DB 에서 is_phone_verified=true UPDATE (KCP 우회)
//   - A 의 프로필 setup + 아이 등록 + 방 생성 (roomId 추출)
//   - 두 시뮬에 --dart-define 으로 토큰/userId/peerUserId/roomId 주입
//
// 흐름:
//   A: 부팅 → 채팅 메시지 전송 → B 신고  (단계마다 스크린샷)
//   B: 부팅 → 방 참여(FREE join) → 채팅 메시지 전송  (단계마다 스크린샷)
//
// 모든 스크린샷은 driver(test_driver/integration_test.dart)에서 TEST_RESULTS_DIR
// 단일 디렉토리에 평탄하게 PNG 로 저장.

import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:app/main.dart' as app;

import 'helpers/api_helper.dart';
import 'helpers/test_config.dart';

late IntegrationTestWidgetsFlutterBinding _binding;

Future<void> _shot(WidgetTester tester, String label) async {
  await tester.pumpAndSettle(const Duration(milliseconds: 500));
  if (Platform.isIOS) {
    await _binding.convertFlutterSurfaceToImage();
  }
  await _binding.takeScreenshot('${TestConfig.role}_$label');
}

void main() {
  _binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('역할 ${TestConfig.role} 시나리오', (tester) async {
    expect(TestConfig.accessToken.isNotEmpty, true,
        reason: 'TEST_ACCESS_TOKEN 미주입 — orchestrator 실행 여부 확인');
    expect(TestConfig.sharedRoomId.isNotEmpty, true,
        reason: 'TEST_ROOM_ID 미주입 — orchestrator 가 방을 사전 생성하지 않았는지 확인');

    // 토큰 사전 주입 — 앱이 시작 시 SecureStorage 를 읽으면 자동 로그인 상태로 들어감
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    await storage.write(key: 'access_token', value: TestConfig.accessToken);
    await storage.write(key: 'refresh_token', value: TestConfig.refreshToken);
    await storage.write(key: 'onboarding_complete', value: 'true');

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _shot(tester, '00_boot');

    final api = ApiHelper(token: TestConfig.accessToken);

    if (TestConfig.isUserA) {
      await _runUserA(tester, api);
    } else {
      await _runUserB(tester, api);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}

Future<void> _runUserA(WidgetTester tester, ApiHelper api) async {
  // 방 / 프로필 / 아이는 orchestrator 가 미리 만들어 둠. UI 는 자동 로그인된 홈.
  await _shot(tester, '01_home');

  // A 가 채팅 메시지 전송
  await api.sendChatMessage(
    TestConfig.sharedRoomId,
    '안녕하세요! 방장(A)입니다. (e2e ${_ts()})',
  );
  await _shot(tester, '02_after_send_chat');

  // 양쪽 메시지 리스트 확인 (B 가 가입+전송할 시간을 약간 줌)
  await tester.pump(const Duration(seconds: 4));
  final messages = await api.listChatMessages(TestConfig.sharedRoomId);
  expect(messages.isNotEmpty, true, reason: 'A 의 메시지가 리스트에 있어야 함');
  await _shot(tester, '03_messages_fetched');

  // B 를 신고
  if (TestConfig.peerUserId.isNotEmpty) {
    await api.reportUser(
      targetUserId: TestConfig.peerUserId,
      reason: 'ABUSE',
      detail: 'e2e A→B 신고 (${_ts()})',
    );
  }
  await _shot(tester, '04_after_report');
}

Future<void> _runUserB(WidgetTester tester, ApiHelper api) async {
  await _shot(tester, '01_home');

  // B 가 방 참여 (FREE 방이라 즉시 멤버로 추가됨)
  await api.joinRoom(TestConfig.sharedRoomId);
  await _shot(tester, '02_after_join');

  // 채팅 메시지 전송
  await api.sendChatMessage(
    TestConfig.sharedRoomId,
    '반갑습니다, 참여자(B)입니다. (e2e ${_ts()})',
  );
  await _shot(tester, '03_after_send_chat');

  // 양쪽 메시지가 리스트에 있는지
  final messages = await api.listChatMessages(TestConfig.sharedRoomId);
  expect(messages.length, greaterThanOrEqualTo(1));
  await _shot(tester, '04_messages_fetched');
}

String _ts() {
  final n = DateTime.now();
  return '${n.hour.toString().padLeft(2, '0')}:'
      '${n.minute.toString().padLeft(2, '0')}:'
      '${n.second.toString().padLeft(2, '0')}';
}
