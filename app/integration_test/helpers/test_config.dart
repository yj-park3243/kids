/// e2e 테스트용 상수.
///
/// 모든 값은 --dart-define 환경변수로 override 가능.
/// orchestrator(run_e2e.sh)가 회원가입/본인인증 우회 후 토큰을 주입.
class TestConfig {
  TestConfig._();

  /// 테스트 대상 서버. 보통 stg 또는 별도 e2e 환경을 권장.
  static const String apiBaseUrl = String.fromEnvironment(
    'TEST_API_BASE_URL',
    defaultValue: 'https://api.growtogether.kr/v1',
  );

  /// 역할: 'A'(방장) | 'B'(참여자 1, 한부모) | 'C'(참여자 2, 거부 케이스).
  static const String role = String.fromEnvironment('TEST_USER_ROLE', defaultValue: 'A');

  /// orchestrator가 회원가입 후 발급받아 주입.
  static const String accessToken = String.fromEnvironment('TEST_ACCESS_TOKEN', defaultValue: '');
  static const String refreshToken = String.fromEnvironment('TEST_REFRESH_TOKEN', defaultValue: '');
  static const String userId = String.fromEnvironment('TEST_USER_ID', defaultValue: '');

  /// 각 round 의 다른 두 사용자 id (후기/신고 대상).
  static const String otherUserId1 = String.fromEnvironment('TEST_OTHER_USER_ID_1', defaultValue: '');
  static const String otherUserId2 = String.fromEnvironment('TEST_OTHER_USER_ID_2', defaultValue: '');

  /// Round 1/2/3 의 roomId (orchestrator 가 사전 생성).
  static const String room1Id = String.fromEnvironment('TEST_ROOM_ID_1', defaultValue: '');
  static const String room2Id = String.fromEnvironment('TEST_ROOM_ID_2', defaultValue: '');
  static const String room3Id = String.fromEnvironment('TEST_ROOM_ID_3', defaultValue: '');

  /// 본인의 parentGender (B/C 는 MOM/DAD, A 는 MOM).
  static const String parentGender = String.fromEnvironment('TEST_PARENT_GENDER', defaultValue: 'MOM');

  /// 본인 isSingleParent (A/B 는 true, C 는 false).
  static const bool isSingleParent =
      bool.fromEnvironment('TEST_IS_SINGLE_PARENT', defaultValue: false);

  static bool get isUserA => role == 'A';
  static bool get isUserB => role == 'B';
  static bool get isUserC => role == 'C';
}
