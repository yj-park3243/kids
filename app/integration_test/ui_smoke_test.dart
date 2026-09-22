// 앱 전 화면 스모크 테스트 — 로그인 후 주요 화면·버튼을 순회하며
// 크래시·렌더 에러 없이 동작하는지 검증한다.
//
// 각 화면 진입 직후 tester.takeException() 으로 예외를 수집한다.
// 실패한 화면은 [SMOKE_FAIL] 로그 + _failures 에 쌓이고, 끝에서 expect 로
// 전체 통과/실패를 판정한다.
//
// 화면 이동은 하단 탭 라벨이 아니라 라우터(goTab)로 한다 — iOS 26+ 는 네이티브
// 탭바(플랫폼 뷰)라 탭이 Flutter 위젯 트리에 없다. 이전 구현은 find.text('지도')
// 로 탭을 찾아 if 로 감쌌기 때문에, 로그인 이후 화면을 한 곳도 못 열고도 항상
// 초록불이었다(찾던 '내방' 라벨은 코드에서 사라진 지 오래다).
//
// finder 는 화면 타입으로 좁혀 쓴다(_in) — StatefulShellRoute.indexedStack 은
// 한 번 방문한 탭을 IndexedStack(=Visibility.maintain) 으로 트리에 남겨 두므로,
// 화면 전체에서 찾으면 다른 탭에 있는 같은 문구·위젯이 잡힌다.
//
// 사전 전제 (orchestrator = run_smoke.sh):
//   - 계정 1개 가입 + 폰인증 우회 + 프로필 + 자녀
//   - HOST 계정이 오늘 날짜 방 1개 사전 생성 → '모임 찾기'(/rooms) 목록에만
//     보인다. 스모크 계정은 참여자가 아니라 '내 모임'(/my-rooms) 은 비어 있다.
//   - dart-define: UI_TEST_EMAIL / UI_TEST_PASSWORD / UI_TEST_LAT / UI_TEST_LNG

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:app/main.dart' as app;
import 'package:app/core/router/app_router.dart';
import 'package:app/features/home/presentation/home_dashboard_screen.dart';
import 'package:app/features/home/presentation/home_screen.dart';
import 'package:app/features/home/presentation/widgets/room_card.dart';
import 'package:app/features/map/presentation/map_screen.dart';
import 'package:app/features/mypage/presentation/blocked_users_screen.dart';
import 'package:app/features/mypage/presentation/my_rooms_screen.dart';
import 'package:app/features/mypage/presentation/mypage_screen.dart';
import 'package:app/features/mypage/presentation/profile_edit_screen.dart';
import 'package:app/features/notification/presentation/notification_screen.dart';
import 'package:app/features/notification/presentation/notification_settings_screen.dart';
import 'package:app/features/room/presentation/room_detail_screen.dart';
import 'package:app/features/support/presentation/inquiry_list_screen.dart';

import 'helpers/ui_helpers.dart';

late IntegrationTestWidgetsFlutterBinding _binding;

final Dio _shotDio = Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 2),
  receiveTimeout: const Duration(seconds: 3),
));

const _email = String.fromEnvironment('UI_TEST_EMAIL', defaultValue: '');
const _password = String.fromEnvironment('UI_TEST_PASSWORD', defaultValue: '');
// 스크린샷 prefix — 디바이스(kids/ip17)별로 구분.
const _deviceTag = String.fromEnvironment('UI_DEVICE_TAG', defaultValue: 'smoke');

final List<String> _failures = [];

void _fail(String msg) {
  _failures.add(msg);
  print('[SMOKE_FAIL] $msg');
}

/// [screen] 서브트리 안에서만 찾는다. screen 이 null 이면 화면 전체.
Finder _in(Type? screen, Finder f) => screen == null
    ? f
    : find.descendant(of: find.byType(screen), matching: f);

/// 현재 라우터 위치 — 탭 이동이 실제로 먹었는지(로그인으로 튕기지 않았는지)
/// 판정한다. 방문한 탭이 트리에 남으므로 위젯 존재만으로는 판정할 수 없다.
String _location() => appRouter.routerDelegate.currentConfiguration.uri.path;

Future<void> _settle(WidgetTester tester, {int fallbackSeconds = 3}) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 6),
    );
  } catch (_) {
    for (var i = 0; i < fallbackSeconds; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }
}

Future<void> _shot(WidgetTester tester, String label) async {
  await _settle(tester, fallbackSeconds: 1);
  await tester.pump(const Duration(milliseconds: 200));
  // Android 는 헬퍼(Flutter 서피스 캡처). iOS 는 takeScreenshot 이 런치 이미지만
  // 돌려주므로 run_smoke.sh 가 띄운 9998 서버가 simctl 로 대신 찍는다.
  // 스크린샷 실패가 테스트를 죽이면 안 된다 — 둘 다 조용히 넘긴다.
  try {
    await shot(_binding, tester, '${_deviceTag}_$label');
  } catch (_) {}
  try {
    await _shotDio.get('http://127.0.0.1:9998/${_deviceTag}_$label');
    await Future.delayed(const Duration(milliseconds: 500));
  } catch (_) {}
}

/// 화면 진입 직후 호출 — 예외 또는 에러 상태면 실패로 기록한다.
/// [scope] 를 주면 그 화면 안에서만 에러 문구를 찾는다(다른 탭 잔여 위젯 배제).
Future<void> _check(WidgetTester tester, String label, {Type? scope}) async {
  await _settle(tester);
  final ex = tester.takeException();
  if (ex != null) {
    _fail('$label → 예외: $ex');
  } else if (has(_in(scope, find.textContaining('불러올 수 없'))) ||
      has(_in(scope, find.textContaining('다시 시도')))) {
    _fail('$label → 화면 로딩 실패(에러 상태)');
  } else {
    print('[SMOKE_OK] $label');
  }
  await _shot(tester, label);
}

/// 뒤로가기 — CustomAppBar 의 back 아이콘.
Future<void> _back(WidgetTester tester) async {
  final back = find.byIcon(Icons.arrow_back_ios_new_rounded);
  if (back.evaluate().isNotEmpty) {
    await tester.tap(back.first, warnIfMissed: false);
    await _settle(tester);
  }
}

/// 하단 탭 이동 — 라우터로 옮기고 실제로 그 위치에 섰는지 확인한다.
/// 이동에 실패하면 이후 단계가 통째로 무의미해지므로 실패로 기록한다.
Future<bool> _navTab(
    WidgetTester tester, String path, Type screen, String label) async {
  await goTab(tester, path);
  final ok = await waitFor(
    tester,
    () => _location() == path && has(find.byType(screen)),
    seconds: 15,
  );
  if (!ok) _fail('$label → 탭 이동 실패($path, 현재 ${_location()})');
  return ok;
}

/// 버튼을 눌러 push 되는 화면을 열고 검사한 뒤 돌아온다.
/// 이 테스트의 존재 이유가 '화면이 실제로 열리는가' 라 조용히 넘어가지 않는다.
Future<void> _openPushed(
  WidgetTester tester,
  Finder trigger,
  Type screen,
  String label, {
  required String backTo,
  Future<void> Function()? onOpen,
}) async {
  if (!await tapSafely(tester, trigger)) {
    _fail('$label → 진입 버튼을 찾지 못함');
  } else if (!await waitFor(tester, () => has(find.byType(screen)),
      seconds: 15)) {
    _fail('$label → 화면이 열리지 않음');
  } else {
    await _check(tester, label, scope: screen);
    if (onOpen != null) await onOpen();
  }
  await _back(tester);
  // 뒤로가기가 빗나가면 다음 단계가 엉뚱한 화면을 누른다 — 남아 있으면 탭 복귀.
  if (has(find.byType(screen))) await goTab(tester, backTo);
}

/// '모임 찾기' 기간 포스트잇('오늘'·'내일'·'이번 주'). 붙였다 떼는 토글이라
/// 같은 것을 두 번 누르면 원래(기간 전체)로 돌아간다.
Finder _dateChip(String label) => _in(HomeScreen, find.text(label)).first;

void main() {
  _binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('앱 전 화면 스모크', (tester) async {
    expect(_email.isNotEmpty, true, reason: 'UI_TEST_EMAIL 미주입');

    // ─── 로그인 ─────────────────────────────────────────────
    // iOS 키체인은 앱을 지워도 남는다 — 이전 실행 토큰으로 자동 로그인되면
    // 로그인 화면이 아예 안 뜬다. main() 전에 비운다.
    await resetAuthState();
    app.main();
    expect(await waitForAppStart(tester), isTrue,
        reason: '앱이 로그인 화면까지 뜨지 않았다');
    await _check(tester, '01_login');

    final loggedIn =
        await loginWithEmail(tester, email: _email, password: _password);
    // 로그인은 이후 모든 단계의 전제 — 실패하면 나머지 결과가 무의미하다.
    expect(loggedIn, isTrue, reason: '이메일 로그인 실패(홈 대시보드 미도달)');
    await _check(tester, '02_home', scope: HomeDashboardScreen);

    // ─── 모임 찾기 — 날짜 필터 칩 ───────────────────────────
    // 필터 칩은 대시보드(/home)가 아니라 HomeScreen(/rooms)에만 있다.
    await _navTab(tester, '/rooms', HomeScreen, '03_home_date_today');
    if (await tapSafely(tester, _dateChip('오늘'))) {
      await _check(tester, '03_home_date_today', scope: HomeScreen);
      // 다시 눌러 떼기 — 이후 단계(방 상세 진입)는 기간 전체 목록이 필요하다.
      await tapSafely(tester, _dateChip('오늘'));
    } else {
      _fail('03_home_date_today → 기간 포스트잇(오늘) 없음');
    }

    // ─── 홈 — 알림 진입 ─────────────────────────────────────
    // 알림 아이콘은 대시보드 상단바에만 있다.
    await _navTab(tester, '/home', HomeDashboardScreen, '04_notifications');
    await _openPushed(
      tester,
      _in(HomeDashboardScreen, find.byIcon(Icons.notifications_outlined)),
      NotificationScreen,
      '04_notifications',
      backTo: '/home',
    );

    // ─── 지도 탭 ────────────────────────────────────────────
    await _navTab(tester, '/map', MapScreen, '05_map');
    await _check(tester, '05_map', scope: MapScreen);
    if (await tapSafely(tester, _in(MapScreen, find.text('펼치기')))) {
      await _check(tester, '06_map_filter_expanded', scope: MapScreen);
      await tapSafely(tester, _in(MapScreen, find.text('접기')));
    } else {
      _fail('06_map_filter_expanded → 필터 펼치기 버튼 없음');
    }

    // ─── 내 모임 탭 ─────────────────────────────────────────
    await _navTab(tester, '/my-rooms', MyRoomsScreen, '07_myrooms');
    await _check(tester, '07_myrooms', scope: MyRoomsScreen);

    // ─── 마이 탭 ────────────────────────────────────────────
    await _navTab(tester, '/mypage', MyPageScreen, '08_mypage');
    await _check(tester, '08_mypage', scope: MyPageScreen);

    // ─── 마이 — 프로필 수정 ─────────────────────────────────
    await _openPushed(
      tester,
      _in(MyPageScreen, find.text('프로필 수정')),
      ProfileEditScreen,
      '09_profile_edit',
      backTo: '/mypage',
    );

    // ─── 마이 — 알림 설정 ───────────────────────────────────
    await _openPushed(
      tester,
      _in(MyPageScreen, find.text('알림 설정')),
      NotificationSettingsScreen,
      '10_notification_settings',
      backTo: '/mypage',
      onOpen: () async {
        // 토글 동작 — 보조 검증이라 스위치가 없으면 로그만 남긴다.
        if (await tapSafely(
            tester, _in(NotificationSettingsScreen, find.byType(Switch)))) {
          await _check(tester, '11_noti_toggle',
              scope: NotificationSettingsScreen);
        } else {
          debugPrint('[SMOKE_SKIP] 11_noti_toggle → 스위치 없음');
        }
      },
    );

    // ─── 마이 — 차단한 유저 ─────────────────────────────────
    await _openPushed(
      tester,
      _in(MyPageScreen, find.text('차단한 유저')),
      BlockedUsersScreen,
      '12_blocked_users',
      backTo: '/mypage',
    );

    // ─── 마이 — 1:1 문의 ────────────────────────────────────
    await _openPushed(
      tester,
      // 마이 → 문의함(목록). 작성 화면은 문의함 안의 '문의하기'로 들어간다.
      _in(MyPageScreen, find.text('1:1 문의')),
      InquiryListScreen,
      '13_inquiry',
      backTo: '/mypage',
    );

    // ─── 모임 찾기 — 방 상세 진입 ───────────────────────────
    // 방 카드는 /rooms 의 RoomCard 다(/my-rooms 의 RoomCard 는 참여한
    // 방만 나오는데 스모크 계정은 참여자가 아니다).
    await _navTab(tester, '/rooms', HomeScreen, '14_room_detail');
    // 03 단계에서 '오늘' 포스트잇을 다시 눌러 떼어 뒀으므로 기간 전체 목록이다.
    // 목록은 시머 → 카드. 카드 API 가 늦게 오므로 그려질 때까지 기다린다.
    final cards = _in(HomeScreen, find.byType(RoomCard));
    if (!await waitFor(tester, () => has(cards), seconds: 40)) {
      _fail('14_room_detail → 모임 찾기 목록에 방 카드가 없음');
    } else {
      await tapSafely(tester, cards);
      if (await waitFor(tester, () => has(find.byType(RoomDetailScreen)),
          seconds: 30)) {
        await _check(tester, '14_room_detail', scope: RoomDetailScreen);
      } else {
        _fail('14_room_detail → 방 상세가 열리지 않음');
      }
      await _back(tester);
    }

    // ─── 마이 — 로그아웃 다이얼로그 (취소) ──────────────────
    await _navTab(tester, '/mypage', MyPageScreen, '15_logout_dialog');
    if (!await tapSafely(tester, _in(MyPageScreen, find.text('로그아웃')))) {
      _fail('15_logout_dialog → 로그아웃 메뉴 없음');
    } else if (!await waitFor(
        tester, () => has(find.text('정말로 로그아웃 하시겠습니까?')),
        seconds: 10)) {
      _fail('15_logout_dialog → 확인 다이얼로그가 뜨지 않음');
    } else {
      // 다이얼로그 자체는 위에서 확인했다 — 여기서는 예외/에러 상태만 본다.
      await _check(tester, '15_logout_dialog', scope: MyPageScreen);
      await tapSafely(tester, find.text('취소'));
    }

    // ─── 결과 판정 ──────────────────────────────────────────
    print('[SMOKE_RESULT] 실패 ${_failures.length}건');
    for (final f in _failures) {
      print('[SMOKE_RESULT]   - $f');
    }
    expect(_failures, isEmpty,
        reason: '스모크 실패 화면: ${_failures.join(" | ")}');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
