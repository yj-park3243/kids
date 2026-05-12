class Review {
  final String id;
  final String roomId;
  final String targetUserId;
  final int score;
  final List<String> tags;
  final String? comment;
  final String? createdAt;

  Review({
    required this.id,
    required this.roomId,
    required this.targetUserId,
    required this.score,
    this.tags = const [],
    this.comment,
    this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] ?? '',
      roomId: json['roomId'] ?? '',
      targetUserId: json['targetUserId'] ?? '',
      score: json['score'] ?? 0,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      comment: json['comment'],
      createdAt: json['createdAt'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'roomId': roomId,
        'targetUserId': targetUserId,
        'score': score,
        'tags': tags,
        'comment': comment,
        'createdAt': createdAt,
      };
}
