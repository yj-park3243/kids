import 'dart:convert' show jsonDecode;

dynamic _jsonDecode(String s) => jsonDecode(s);

class ChatRoom {
  final String id;
  final String roomId;
  final String? roomTitle;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  ChatRoom({
    required this.id,
    required this.roomId,
    this.roomTitle,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'] as String,
      roomId: json['roomId'] as String,
      roomTitle: json['roomTitle'] as String?,
      lastMessage: json['lastMessage'] as String?,
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.parse(json['lastMessageAt'] as String)
          : null,
      unreadCount: (json['unreadCount'] as int?) ?? 0,
    );
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderNickname;
  final String content;
  final String type; // TEXT, SYSTEM, IMAGE, LOCATION
  final DateTime createdAt;
  final int unreadCount;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderNickname,
    required this.content,
    required this.type,
    required this.createdAt,
    this.unreadCount = 0,
  });

  bool get isSystem => type == 'SYSTEM';
  bool get isImage => type == 'IMAGE';
  bool get isLocation => type == 'LOCATION';

  /// LOCATION 메시지의 좌표/라벨 파싱. content 는 `{"lat":..,"lng":..,"label":""}`.
  ({double lat, double lng, String label})? get location {
    if (!isLocation) return null;
    try {
      final m = _tryParseJson(content);
      if (m == null) return null;
      final lat = (m['lat'] as num?)?.toDouble();
      final lng = (m['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      return (lat: lat, lng: lng, label: (m['label'] as String?) ?? '');
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _tryParseJson(String s) {
    try {
      return _jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  ChatMessage copyWith({int? unreadCount}) {
    return ChatMessage(
      id: id,
      senderId: senderId,
      senderNickname: senderNickname,
      content: content,
      type: type,
      createdAt: createdAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      senderId: (json['senderId'] as String?) ?? '',
      senderNickname: (json['senderNickname'] as String?) ?? '',
      content: (json['content'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'TEXT',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      unreadCount: (json['unreadCount'] as int?) ?? 0,
    );
  }
}
