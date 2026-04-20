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
  final String type; // TEXT, SYSTEM, IMAGE
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderNickname,
    required this.content,
    required this.type,
    required this.createdAt,
  });

  bool get isSystem => type == 'SYSTEM';
  bool get isImage => type == 'IMAGE';

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
    );
  }
}
