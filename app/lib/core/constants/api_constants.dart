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

  // Children
  static const String children = '/children';

  // Rooms
  static const String rooms = '/rooms';
  static const String myRooms = '/rooms/my';
  static const String roomsMap = '/rooms/map';

  // Notifications
  static const String notifications = '/notifications';
  static const String deviceToken = '/notifications/device-token';
  static const String unreadCount = '/notifications/unread-count';

  // Upload
  static const String uploadImage = '/upload/image';

  // Support
  static const String errorLogs = '/error-logs';
  static const String supportInquiry = '/support/inquiry';
  static const String supportReport = '/support/report';

  // Chat
  static const String chatRooms = '/chat/rooms';
  static String chatMessages(String roomId) => '/chat/rooms/$roomId/messages';

  // Timeouts
  static const int connectTimeout = 10000;
  static const int receiveTimeout = 15000;

  // Pagination
  static const int pageSize = 20;
}
