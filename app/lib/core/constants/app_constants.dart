class AppConstants {
  AppConstants._();

  static const String appName = '같이크자';
  static const double cardBorderRadius = 16.0;
  static const double buttonBorderRadius = 12.0;
  static const double inputBorderRadius = 12.0;
  static const double bottomSheetRadius = 24.0;

  static const double horizontalPadding = 20.0;
  static const double verticalPadding = 16.0;
  static const double cardPadding = 16.0;

  static const int splashDuration = 2; // seconds
  static const int maxChildren = 5;
  static const int maxRoomMembers = 10;
  static const int minRoomMembers = 2;
  static const int maxTags = 5;
  static const int maxTagLength = 10;

  static const String naverMapClientId = 'vwcyomo2zx';

  // TODO: 카카오 디벨로퍼 콘솔에서 발급받은 네이티브 앱 키로 교체.
  // dart-define 로 주입하는 것을 권장: --dart-define=KAKAO_NATIVE_APP_KEY=xxx
  static const String kakaoNativeAppKey = String.fromEnvironment(
    'KAKAO_NATIVE_APP_KEY',
    defaultValue: 'TODO_KAKAO_NATIVE_APP_KEY',
  );

  // Place types
  static const Map<String, String> placeTypes = {
    'PLAYGROUND': '놀이터',
    'KIDS_CAFE': '키즈카페',
    'PARTY_ROOM': '파티룸',
    'PARK': '공원',
    'OTHER': '기타',
  };

  // Place type icons (Material icons code points)
  static const Map<String, int> placeTypeIcons = {
    'PLAYGROUND': 0xe543, // park
    'KIDS_CAFE': 0xe541, // local_cafe
    'PARTY_ROOM': 0xe7fc, // celebration
    'PARK': 0xe3e8, // nature_people
    'OTHER': 0xe55f, // place
  };

  // Room status
  static const Map<String, String> roomStatus = {
    'RECRUITING': '모집중',
    'CLOSED': '모집완료',
    'IN_PROGRESS': '진행중',
    'COMPLETED': '완료',
    'CANCELLED': '취소',
  };

  // Gender
  static const Map<String, String> genderLabels = {
    'MALE': '남아',
    'FEMALE': '여아',
  };
}
