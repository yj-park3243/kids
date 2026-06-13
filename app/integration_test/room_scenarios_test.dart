// 2-sim 방 입장 / 한부모 시나리오 — match3(한부모 방장 A) + match4(일반 부모 B).
//
// orchestrator(run_room_scenarios.sh)가 미리 처리:
//   - A(한부모)/B(일반) 가입 + DB 강제 본인인증 + 프로필
//   - A 토큰으로 방 3개 생성: room1(FREE/ALL), room2(APPROVAL/ALL), room3(FREE/한부모전용)
//   - 시뮬마다 --dart-define 으로 role/토큰/roomId 주입 → SecureStorage 자동 로그인
//
// 검증 시나리오:
//   1. 일반(B) → 자유 방 입장 성공
//   2. 일반(B) → 승인 방 입장 신청 → 한부모(A) 가 승인
//   3. 일반(B) 목록에 한부모 방이 보이지 않음 (서버 필터)
//   4. 일반(B) → 한부모 방 입장 시도 거부(403) / 한부모(A) → 본인 방 정상

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

  testWidgets('역할 ${TestConfig.role} — 방 입장 / 한부모 시나리오',
      (tester) async {
    expect(TestConfig.accessToken.isNotEmpty, true,
        reason: 'TEST_ACCESS_TOKEN 미주입 — orchestrator 실행 여부 확인');
    expect(TestConfig.room1Id.isNotEmpty, true, reason: 'TEST_ROOM_ID_1 미주입');

    // 토큰 사전 주입 → 앱이 시작 시 SecureStorage 를 읽어 자동 로그인.
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
      await _runHost(tester, api);
    } else {
      await _runGuest(tester, api);
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}

// ─────────────────────────────────────────────────────────────────────
// A (match3) — 한부모 방장. 승인 방의 신청을 승인하고, 한부모 방 본인 멤버 확인.
// ─────────────────────────────────────────────────────────────────────
Future<void> _runHost(WidgetTester tester, ApiHelper api) async {
  await _shot(tester, '01_home');

  // [시나리오 2] 승인 방 — 일반 부모(B)의 신청을 승인.
  await tester.pump(const Duration(seconds: 10)); // B 신청 도달 대기
  final pending = await api.listJoinRequests(TestConfig.room2Id);
  await _shot(tester, 'host_r2_join_requests');
  for (final req in pending) {
    final reqId = req['id'] as String;
    await api.respondJoinRequest(
      roomId: TestConfig.room2Id,
      requestId: reqId,
      action: 'ACCEPT',
    );
  }
  await _shot(tester, 'host_r2_approved');

  // [시나리오 4] 한부모 방 — 방장(한부모)은 멤버이며 상세 정상 조회.
  final r3 = await api.getRoomDetail(TestConfig.room3Id);
  expect(r3['singleParentOnly'], true, reason: 'room3 는 한부모 전용이어야 함');
  await _shot(tester, 'host_r3_singleparent_room');

  await _shot(tester, '99_done');
}

// ─────────────────────────────────────────────────────────────────────
// B (match4) — 일반 부모. 자유입장 / 승인신청 / 한부모 비노출 + 입장거부.
// ─────────────────────────────────────────────────────────────────────
Future<void> _runGuest(WidgetTester tester, ApiHelper api) async {
  await _shot(tester, '01_home');

  // [시나리오 1] 자유 방 입장 성공.
  await api.joinRoom(TestConfig.room1Id);
  await _shot(tester, 'guest_r1_joined_free');

  // [시나리오 2] 승인 방 입장 신청 (APPROVAL → 신청 생성, A 가 승인).
  await api.joinRoom(TestConfig.room2Id);
  await _shot(tester, 'guest_r2_requested');

  // [시나리오 3] 한부모 방이 일반 부모 목록에 노출되지 않아야 함 (서버 필터).
  final rooms = await api.listRooms();
  final ids = rooms
      .map((r) => (r as Map)['id'] as String?)
      .whereType<String>()
      .toSet();
  expect(ids.contains(TestConfig.room1Id), true,
      reason: '자유 방은 일반 부모 목록에 보여야 함 (목록 도달 확인)');
  expect(ids.contains(TestConfig.room3Id), false,
      reason: '한부모 방은 일반 부모 목록에서 제외돼야 함');
  await _shot(tester, 'guest_r3_list_no_singleparent');

  // [시나리오 4] 한부모 방 직접 입장 시도는 거부(403).
  final status = await api.tryJoinRoom(TestConfig.room3Id);
  expect(status, isNot(inInclusiveRange(200, 299)),
      reason: '일반 부모는 한부모 방 입장이 거부돼야 함. status=$status');
  await _shot(tester, 'guest_r4_singleparent_rejected');

  await _shot(tester, '99_done');
}
