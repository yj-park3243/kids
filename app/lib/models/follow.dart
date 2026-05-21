class Follow {
  final String targetUserId;
  final String nickname;
  final String? profileImageUrl;
  final double mannerScore;
  final String? followedAt;

  Follow({
    required this.targetUserId,
    required this.nickname,
    this.profileImageUrl,
    this.mannerScore = 36.5,
    this.followedAt,
  });

  factory Follow.fromJson(Map<String, dynamic> json) {
    return Follow(
      targetUserId: json['targetUserId'] ?? '',
      nickname: json['nickname'] ?? '',
      profileImageUrl: json['profileImageUrl'],
      mannerScore: (json['mannerScore'] as num?)?.toDouble() ?? 36.5,
      followedAt: json['followedAt'],
    );
  }

  Map<String, dynamic> toJson() => {
        'targetUserId': targetUserId,
        'nickname': nickname,
        'profileImageUrl': profileImageUrl,
        'mannerScore': mannerScore,
        'followedAt': followedAt,
      };
}
