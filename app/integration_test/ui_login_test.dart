// UI 자동화 e2e — 이메일 로그인 → 홈 진입.
//
// 사전 전제 (orchestrator 가 미리 처리):
//   - 1 계정 회원가입 (API)
//   - 폰인증 우회 (SSH+psql)
//   - 프로필 + 자녀 1명 (API)
//   - 시뮬에 --dart-define 으로 UI_TEST_EMAIL / UI_TEST_PASSWORD 주입
//
// 흐름:
//   1) 로그인 화면 → "이메일로 시작하기" 탭
//   2) 이메일/비밀번호 enterText
//   3) "로그인" 탭 → 홈 진입
//   각 단계마다 스크린샷 캡처.

import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:app/main.dart' as app;

late IntegrationTestWidgetsFlutterBinding _binding;

const _email = String.fromEnvironment('UI_TEST_EMAIL', defaultValue: '');
const _password = String.fromEnvironment('UI_TEST_PASSWORD', defaultValue: '');

Future<void> _shot(WidgetTester tester, String label) async {
  await tester.pumpAndSettle(const Duration(milliseconds: 400));
  if (Platform.isIOS) {
    await _binding.convertFlutterSurfaceToImage();
  }
  await _binding.takeScreenshot('ui_$label');
}

void main() {
  _binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('UI: 이메일 로그인 → 홈 진입', (tester) async {
    expect(_email.isNotEmpty, true,
        reason: 'UI_TEST_EMAIL 미주입 — orchestrator 실행 여부 확인');

    app.main();
    // splash 2 초 대기 + 화면 안정.
    await tester.pumpAndSettle(const Duration(seconds: 4));
    await _shot(tester, '01_login_screen');

    // "이메일로 시작하기" 탭
    final emailStart = find.byKey(const Key('btn-start-email'));
    expect(emailStart, findsOneWidget,
        reason: '로그인 화면의 "이메일로 시작하기" 버튼이 보이지 않음');
    await tester.tap(emailStart);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await _shot(tester, '02_email_login_form');

    // 이메일/비밀번호 입력
    await tester.enterText(find.byKey(const Key('input-email')), _email);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byKey(const Key('input-password')), _password);
    await tester.pump(const Duration(milliseconds: 200));
    await _shot(tester, '03_credentials_entered');

    // 로그인 버튼 탭
    await tester.tap(find.byKey(const Key('btn-login-submit')));
    // 서버 응답 + 화면 전환 (홈) 대기. pump 만 하고 settle 은 무한 애니메이션
    // 가능성 있어 단순 pump 로 시간만 보낸다.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await _shot(tester, '04_after_login');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
