class ApiConstants {
  ApiConstants._();

  // Base URLs
  static const String devBaseUrl = 'http://localhost:3000';
  static const String prodBaseUrl = 'https://api.growtogether.kr';

  static const String _environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  // API_BASE_URL이 주어지면 그것을 우선, 없으면 ENVIRONMENT로 분기
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _environment == 'production' ? prodBaseUrl : devBaseUrl,
  );

  // API version prefix
  static const String apiPrefix = '/v1';
  static String get apiUrl => '$baseUrl$apiPrefix';

  // WebSocket (NestJS gateway namespace)
  static String get chatWsUrl => '$baseUrl/chat';

  // Auth
  static const String socialLogin = '/auth/social';
  static const String emailLogin = '/auth/email/login';
  static const String emailRegister = '/auth/email/register';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String kcpForm = '/auth/kcp/form';

  // User
  static const String userProfile = '/users/profile';
  static const String userMe = '/users/me';
  static const String checkNickname = '/users/check-nickname';
  static String userById(String userId) => '/users/$userId';

  // Children
  static const String children = '/children';

  // Rooms
  static const String rooms = '/rooms';
  static const String myRooms = '/rooms/my';
  static const String roomsMap = '/rooms/map';
  static const String roomsGeocode = '/rooms/geocode';

  // Notifications
  static const String notifications = '/notifications';
  static const String deviceToken = '/notifications/device-token';
  static const String unreadCount = '/notifications/unread-count';

  // App bootstrap / version
  static const String appVersion = '/app-version';

  // Upload
  static const String uploadImage = '/upload/image';

  // Support
  static const String errorLogs = '/error-logs';
  static const String supportInquiry = '/support/inquiry';
  static const String supportReport = '/support/report';

  // Chat
  static const String chatRooms = '/chat/rooms';
  static String chatMessages(String roomId) => '/chat/rooms/$roomId/messages';
  static String chatRoomRead(String roomId) => '/chat/rooms/$roomId/read';

  // Block
  static const String blocks = '/blocks';
  static String blockTarget(String targetUserId) => '/blocks/$targetUserId';

  // Reviews
  static String roomReviews(String roomId) => '/rooms/$roomId/reviews';
  static String reviewById(String reviewId) => '/reviews/$reviewId';
  static String userReviews(String userId) => '/users/$userId/reviews';

  // Follows
  static const String follows = '/follows';
  static const String myFollows = '/follows/me';
  static String followByTarget(String targetUserId) =>
      '/follows/$targetUserId';

  // Growth guide
  static const String guides = '/guides';
  static String guide(int ageMonth) => '/guides/$ageMonth';

  // Notice
  static const String notices = '/notices';
  static const String noticesPinned = '/notices/pinned';
  static String noticeById(String id) => '/notices/$id';

  // Timeouts
  static const int connectTimeout = 10000;
  static const int receiveTimeout = 15000;

  // Pagination
  static const int pageSize = 20;
}
