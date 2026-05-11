/// e2e 테스트용 상수.
///
/// 모든 값은 --dart-define 환경변수로 override 가능.
/// orchestrator 쉘 스크립트가 회원가입/본인인증 우회 후 토큰을 주입.
class TestConfig {
  TestConfig._();

  /// 테스트 대상 서버. 보통 stg 또는 별도 e2e 환경을 권장.
  /// prod를 가리키면 실제 사용자 데이터에 영향 갈 수 있으니 주의.
  static const String apiBaseUrl = String.fromEnvironment(
    'TEST_API_BASE_URL',
    defaultValue: 'https://api.growtogether.kr/v1',
  );

  /// 역할: 'A'(방장) 또는 'B'(참여자). 시뮬레이터별로 다른 값을 주입.
  static const String role = String.fromEnvironment('TEST_USER_ROLE', defaultValue: 'A');

  /// orchestrator가 회원가입 후 발급받아 주입.
  static const String accessToken = String.fromEnvironment('TEST_ACCESS_TOKEN', defaultValue: '');
  static const String refreshToken = String.fromEnvironment('TEST_REFRESH_TOKEN', defaultValue: '');
  static const String userId = String.fromEnvironment('TEST_USER_ID', defaultValue: '');

  /// 상대 유저(B 입장에서 A, A 입장에서 B). 신고/차단 시나리오에 필요.
  static const String peerUserId = String.fromEnvironment('TEST_PEER_USER_ID', defaultValue: '');

  /// A가 만든 방의 id. B 진입 시 환경변수로 받아옴.
  static const String sharedRoomId = String.fromEnvironment('TEST_ROOM_ID', defaultValue: '');

  /// 시뮬레이터에서 스크린샷 저장할 경로.
  static const String screenshotDir = String.fromEnvironment(
    'TEST_SCREENSHOT_DIR',
    defaultValue: '/tmp/kids_e2e_screenshots',
  );

  /// 화면 폴링 최대 횟수 (1회당 500ms).
  static const int uiPollIterations = 60;
  static const Duration uiPollInterval = Duration(milliseconds: 500);

  static bool get isUserA => role == 'A';
  static bool get isUserB => role == 'B';
}
