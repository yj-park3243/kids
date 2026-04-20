class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final bool isRead;
  final String createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      data: json['data'] as Map<String, dynamic>?,
      isRead: json['isRead'] ?? false,
      createdAt: json['createdAt'] ?? '',
    );
  }

  String? get roomId => data?['roomId'];
  String? get chatRoomId => data?['chatRoomId'];
}
