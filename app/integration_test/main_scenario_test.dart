// 시뮬레이터 3대(A/B/C) 병렬 e2e — 3 round 시나리오.
//
// 사전 전제 (orchestrator 가 미리 처리):
//   - A/B/C 세 계정 회원가입 + 폰인증 우회 (DB UPDATE)
//   - 프로필 setup (A: MOM+single, B: MOM+single, C: DAD+normal) + 자녀 2/2/4명
//   - Round 1 방 (FREE/ALL) 생성 → room1Id
//   - Round 2 방 (APPROVAL/MOM_ONLY) 생성 → room2Id
//   - Round 3 방 (FREE/singleParentOnly=true) 생성 → room3Id
//   - 시뮬마다 --dart-define 으로 ROLE / 토큰 / 모든 roomId / peer userId 주입
//
// 시뮬레이터 안에서:
//   - 토큰 SecureStorage 주입 → 자동 로그인 홈
//   - role 별로 API 액션 + 단계마다 스크린샷
//   - 거부 케이스(403/400)는 try/catch 로 확인하고 통과로 처리
//
// 모든 스크린샷은 test_results/ 단일 디렉토리에 평탄 저장.
// 파일명: {ROLE}_{round}_{step}_{label}.png

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

String _ts() {
  final n = DateTime.now();
  return '${n.hour.toString().padLeft(2, '0')}:'
      '${n.minute.toString().padLeft(2, '0')}:'
      '${n.second.toString().padLeft(2, '0')}';
}

void main() {
  _binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('역할 ${TestConfig.role} — 3 round 시나리오', (tester) async {
    expect(TestConfig.accessToken.isNotEmpty, true,
        reason: 'TEST_ACCESS_TOKEN 미주입 — orchestrator 실행 여부 확인');
    expect(TestConfig.room1Id.isNotEmpty, true,
        reason: 'TEST_ROOM_ID_1 미주입');

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
    } else if (TestConfig.isUserB) {
      await _runUserB(tester, api);
    } else {
      await _runUserC(tester, api);
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}

// ─────────────────────────────────────────────────────────────────────
// A — 방장. 3 round 모두 방을 만들었고, 신청 승인 / 채팅 / 후기 수행.
// ─────────────────────────────────────────────────────────────────────
Future<void> _runUserA(WidgetTester tester, ApiHelper api) async {
  await _shot(tester, '01_home');

  // ═══ Round 1 — 일반 방 (FREE/ALL) ═══════════════════════════════════
  // B, C 가 FREE 로 join 하기를 잠시 대기.
  await tester.pump(const Duration(seconds: 6));
  await _shot(tester, 'r1_01_after_joins_settle');

  // A 가 채팅 전송
  await api.sendChatMessage(
    TestConfig.room1Id,
    '안녕하세요! 방장 A 입니다. (${_ts()})',
  );
  await _shot(tester, 'r1_02_chat_sent');

  // 멤버 모인 후 채팅 리스트 확인
  await tester.pump(const Duration(seconds: 4));
  final r1Messages = await api.listChatMessages(TestConfig.room1Id);
  expect(r1Messages.length, greaterThanOrEqualTo(1));
  await _shot(tester, 'r1_03_chat_fetched');

  // 후기: A → B, A → C (모임 완료 후 가능. orchestrator 가 COMPLETED 처리)
  await tester.pump(const Duration(seconds: 5));
  final reviewIdB = await api.createReview(
    roomId: TestConfig.room1Id,
    targetUserId: TestConfig.otherUserId1, // B
    score: 5,
    tags: ['친절했어요', '시간 잘 지켜요'],
    comment: 'e2e A→B 후기 (${_ts()})',
  );
  await api.createReview(
    roomId: TestConfig.room1Id,
    targetUserId: TestConfig.otherUserId2, // C
    score: 4,
    tags: ['친절했어요'],
    comment: 'e2e A→C 후기 (${_ts()})',
  );
  await _shot(tester, 'r1_04_reviews_done');

  // ═══ Round 2 — 승인 + MOM_ONLY ═════════════════════════════════════
  // B 의 신청 승인 (C 는 시도 자체가 서버에서 거부되어 join_request 없음)
  await tester.pump(const Duration(seconds: 6));
  final pending = await api.listJoinRequests(TestConfig.room2Id);
  await _shot(tester, 'r2_01_join_requests');
  for (final req in pending) {
    final reqId = req['id'] as String;
    final requesterId = (req['user'] as Map?)?['id'] as String? ??
        req['userId'] as String?;
    if (requesterId == TestConfig.otherUserId1) {
      await api.respondJoinRequest(
        roomId: TestConfig.room2Id,
        requestId: reqId,
        action: 'ACCEPT',
      );
    }
  }
  await _shot(tester, 'r2_02_b_approved');

  // 채팅
  await api.sendChatMessage(
    TestConfig.room2Id,
    '엄마들만 모임! 방장 A 입니다. (${_ts()})',
  );
  await _shot(tester, 'r2_03_chat_sent');

  // ═══ Round 3 — 한부모 전용 ═════════════════════════════════════════
  // B 는 한부모라 자동 입장(FREE), C 는 서버 거부 (singleParentOnly).
  await tester.pump(const Duration(seconds: 4));
  await api.sendChatMessage(
    TestConfig.room3Id,
    '한부모 모임! 방장 A 입니다. (${_ts()})',
  );
  await _shot(tester, 'r3_01_chat_sent');

  // ═══ Round 5 — 노쇼 출석 체크 + 후기 수정 (방장) ═════════════════════
  // room1 은 orchestrator 가 COMPLETED 처리. 방장이 B 를 출석 처리.
  // (C 는 자기 시나리오에서 A 를 차단하며 room1 멤버십이 제거되므로 대상에서 제외)
  await tester.pump(const Duration(seconds: 3));
  final attStatus = await api.submitAttendance(
    TestConfig.room1Id,
    [
      {'userId': TestConfig.otherUserId1, 'attended': true}, // B
    ],
  );
  expect(attStatus, inInclusiveRange(200, 299),
      reason: '방장 출석 체크는 성공해야 함. status=$attStatus');
  await _shot(tester, 'r5_01_attendance');

  // 후기 수정 (완료 7일 이내) — Round1 의 A→B 후기.
  if (reviewIdB.isNotEmpty) {
    await api.updateReview(
      reviewIdB,
      score: 4,
      comment: 'e2e A→B 후기 수정 (${_ts()})',
    );
    await _shot(tester, 'r5_02_review_updated');
  }

  // 비방장이 출석 체크를 호출하면 거부(403)여야 함은 C 시나리오에서 검증.

  // ═══ Round 6 — 프로필 수정 불가 + 내 모임 + 외부 프로필 ══════════════
  // 수정 불가 필드: parentGender / isSingleParent 변경 시도 → 2xx 이나 값 불변.
  final before = await api.getMe();
  await api.updateMe({'parentGender': 'DAD', 'isSingleParent': false});
  final after = await api.getMe();
  expect(after['parentGender'], before['parentGender'],
      reason: 'parentGender 는 가입 후 수정 불가여야 함');
  expect(after['isSingleParent'], before['isSingleParent'],
      reason: 'isSingleParent 는 가입 후 수정 불가여야 함');
  await _shot(tester, 'r6_01_immutable_fields');

  // 내 모임 목록 — 지난 모임(PAST)에 COMPLETED 된 room1 이 포함.
  await api.listMyRooms(status: 'UPCOMING');
  await api.listMyRooms(status: 'PAST');
  await _shot(tester, 'r6_02_my_rooms');

  // 외부 유저 프로필 — 한부모 여부가 노출되면 안 됨.
  final bProfile = await api.getUserById(TestConfig.otherUserId1); // B
  expect(bProfile.containsKey('isSingleParent'), false,
      reason: '외부 프로필에 한부모 여부가 노출되면 안 됨');
  await _shot(tester, 'r6_03_user_profile');

  await _shot(tester, '99_done');
}

// ─────────────────────────────────────────────────────────────────────
// B — 참여자 (MOM, 한부모). 3 round 모두 입장 가능한 케이스.
// ─────────────────────────────────────────────────────────────────────
Future<void> _runUserB(WidgetTester tester, ApiHelper api) async {
  print('[E2E_B] 01_home shot');
  await _shot(tester, '01_home');

  // ═══ Round 1 — 일반 방 (FREE 라 즉시 입장) ═══════════════════════════
  print('[E2E_B] joinRoom(room1) start: ${TestConfig.room1Id}');
  try {
    await api.joinRoom(TestConfig.room1Id);
    print('[E2E_B] joinRoom(room1) OK');
  } catch (e) {
    print('[E2E_B] joinRoom(room1) FAILED: $e');
  }
  await _shot(tester, 'r1_01_joined');

  await tester.pump(const Duration(seconds: 2));
  await api.sendChatMessage(
    TestConfig.room1Id,
    '안녕하세요, 참여자 B 입니다. (${_ts()})',
  );
  await _shot(tester, 'r1_02_chat_sent');

  // ═══ Round 2 — 승인 방 (APPROVAL/MOM_ONLY): 신청 후 A 승인 대기 ═════
  await api.joinRoom(TestConfig.room2Id);
  await _shot(tester, 'r2_01_requested');

  // A 가 승인할 시간을 줌
  await tester.pump(const Duration(seconds: 10));
  await _shot(tester, 'r2_02_after_wait');

  // 승인 후 채팅 (승인 전이라면 403 — 약간 더 대기 후 재시도)
  for (var i = 0; i < 5; i++) {
    try {
      await api.sendChatMessage(
        TestConfig.room2Id,
        '엄마 B 입장 완료! (${_ts()})',
      );
      break;
    } catch (_) {
      await tester.pump(const Duration(seconds: 3));
    }
  }
  await _shot(tester, 'r2_03_chat_after_approve');

  // ═══ Round 3 — 한부모 전용 방 (B 는 한부모라 입장 가능) ═══════════════
  await api.joinRoom(TestConfig.room3Id);
  await _shot(tester, 'r3_01_joined');

  await api.sendChatMessage(
    TestConfig.room3Id,
    '한부모 B 입장! (${_ts()})',
  );
  await _shot(tester, 'r3_02_chat_sent');

  // ═══ Round 4 — 팔로우 (B → A) + 위치 노출(참여 확정자) ═══════════════
  // B 는 A(otherUserId1)를 단골로 팔로우.
  await api.followUser(TestConfig.otherUserId1);
  final following = await api.listFollowing();
  expect(following.isNotEmpty, true,
      reason: 'A 팔로우 후 내 팔로잉 목록에 있어야 함');
  await _shot(tester, 'r4_01_followed');

  // 위치 노출 단계화: B 는 room1 참여 확정자 → placeName/placeAddress 공개.
  final r1Detail = await api.getRoomDetail(TestConfig.room1Id);
  expect(r1Detail.containsKey('placeName'), true,
      reason: '참여 확정자 응답에는 placeName 키가 포함되어야 함');
  await _shot(tester, 'r4_02_room_detail_member');

  await _shot(tester, '99_done');
}

// ─────────────────────────────────────────────────────────────────────
// C — 참여자 (DAD, 일반 가정). Round 1 만 OK, Round 2/3 은 거부 검증.
// ─────────────────────────────────────────────────────────────────────
Future<void> _runUserC(WidgetTester tester, ApiHelper api) async {
  print('[E2E_C] 01_home shot');
  await _shot(tester, '01_home');

  // ═══ Round 1 — 일반 방: 입장 가능 ═════════════════════════════════
  print('[E2E_C] joinRoom(room1) start: ${TestConfig.room1Id}');
  try {
    await api.joinRoom(TestConfig.room1Id);
    print('[E2E_C] joinRoom(room1) OK');
  } catch (e) {
    print('[E2E_C] joinRoom(room1) FAILED: $e');
  }
  await _shot(tester, 'r1_01_joined');

  await api.sendChatMessage(
    TestConfig.room1Id,
    '안녕하세요, 참여자 C(아빠) 입니다. (${_ts()})',
  );
  await _shot(tester, 'r1_02_chat_sent');

  // ═══ Round 2 — MOM_ONLY: C(DAD) 는 거부되어야 ═══════════════════════
  final r2Status = await api.tryJoinRoom(TestConfig.room2Id);
  expect(
    r2Status,
    isNot(inInclusiveRange(200, 299)),
    reason: 'C(DAD) 는 MOM_ONLY 방에서 거부되어야 함. 실제 status=$r2Status',
  );
  await _shot(tester, 'r2_01_rejected');

  // ═══ Round 3 — 한부모 전용: C(일반 가정) 도 거부되어야 ═══════════════
  final r3Status = await api.tryJoinRoom(TestConfig.room3Id);
  expect(
    r3Status,
    isNot(inInclusiveRange(200, 299)),
    reason: 'C(일반) 는 한부모 전용 방에서 거부되어야 함. 실제 status=$r3Status',
  );
  await _shot(tester, 'r3_01_rejected');

  // ═══ Round 4 — 신고 / 위치노출(비참여) / 권한 검증 ═══════════════════
  // 신고 (C → A, USER). POST /reports — 어드민 신고 큐로 이관.
  await api.reportTarget(
    targetType: 'USER',
    targetId: TestConfig.otherUserId1, // A
    reason: 'HARASSMENT',
    description: 'e2e 신고 (${_ts()})',
  );
  await _shot(tester, 'r4_01_reported');

  // 위치 노출 단계화: C 는 room2(MOM_ONLY) 비참여자 → placeName 비공개.
  final r2Detail = await api.getRoomDetail(TestConfig.room2Id);
  expect(r2Detail.containsKey('placeName'), false,
      reason: '비참여자 응답에 placeName 이 노출되면 안 됨');
  await _shot(tester, 'r4_02_room_detail_nonmember');

  // 권한: 비방장(C)이 출석 체크를 호출하면 거부(403)되어야 함.
  final cAtt = await api.submitAttendance(
    TestConfig.room1Id,
    [
      {'userId': TestConfig.userId, 'attended': true},
    ],
  );
  expect(cAtt, isNot(inInclusiveRange(200, 299)),
      reason: '비방장 출석 체크는 거부되어야 함. 실제 status=$cAtt');
  await _shot(tester, 'r4_03_attendance_forbidden');

  // (차단 양방향 검증은 공유 방 멤버십 삭제 부작용 때문에 이 3-user 셋업에서
  //  자동화하지 않는다 — docs/08 BLK-* 참고. 격리 계정/방 셋업 시 자동화 가능.)

  await _shot(tester, '99_done');
}
