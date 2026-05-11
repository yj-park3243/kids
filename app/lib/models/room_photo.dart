class RoomPhoto {
  RoomPhoto({
    required this.id,
    required this.roomId,
    required this.uploaderId,
    required this.uploaderNickname,
    required this.url,
    required this.childIds,
    required this.commentCount,
    required this.createdAt,
  });

  final String id;
  final String roomId;
  final String? uploaderId;
  final String uploaderNickname;
  final String url;
  final List<String> childIds;
  final int commentCount;
  final DateTime createdAt;

  factory RoomPhoto.fromJson(Map<String, dynamic> json) => RoomPhoto(
        id: json['id'] as String,
        roomId: json['roomId'] as String,
        uploaderId: json['uploaderId'] as String?,
        uploaderNickname: json['uploaderNickname'] as String? ?? '-',
        url: json['url'] as String,
        childIds: (json['childIds'] as List?)?.cast<String>() ?? const [],
        commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  RoomPhoto copyWith({List<String>? childIds, int? commentCount}) => RoomPhoto(
        id: id,
        roomId: roomId,
        uploaderId: uploaderId,
        uploaderNickname: uploaderNickname,
        url: url,
        childIds: childIds ?? this.childIds,
        commentCount: commentCount ?? this.commentCount,
        createdAt: createdAt,
      );
}

class PhotoComment {
  PhotoComment({
    required this.id,
    required this.userId,
    required this.userNickname,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String? userId;
  final String userNickname;
  final String content;
  final DateTime createdAt;

  factory PhotoComment.fromJson(Map<String, dynamic> json) => PhotoComment(
        id: json['id'] as String,
        userId: json['userId'] as String?,
        userNickname: json['userNickname'] as String? ?? '-',
        content: json['content'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
