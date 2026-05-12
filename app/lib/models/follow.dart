class Follow {
  final String targetUserId;
  final String nickname;
  final String? profileImageUrl;
  final String regionSigungu;
  final double mannerScore;
  final String? followedAt;

  Follow({
    required this.targetUserId,
    required this.nickname,
    this.profileImageUrl,
    required this.regionSigungu,
    this.mannerScore = 36.5,
    this.followedAt,
  });

  factory Follow.fromJson(Map<String, dynamic> json) {
    return Follow(
      targetUserId: json['targetUserId'] ?? '',
      nickname: json['nickname'] ?? '',
      profileImageUrl: json['profileImageUrl'],
      regionSigungu: json['regionSigungu'] ?? '',
      mannerScore: (json['mannerScore'] as num?)?.toDouble() ?? 36.5,
      followedAt: json['followedAt'],
    );
  }

  Map<String, dynamic> toJson() => {
        'targetUserId': targetUserId,
        'nickname': nickname,
        'profileImageUrl': profileImageUrl,
        'regionSigungu': regionSigungu,
        'mannerScore': mannerScore,
        'followedAt': followedAt,
      };
}
