class Follow {
  final String targetUserId;
  final String nickname;
  final String? profileImageUrl;
  final double mannerScore;
  final String? followedAt;
  // 팔로워 목록에서만 내려옴 — 내가 이 사람을 맞팔로우 중인지.
  final bool? isFollowing;

  Follow({
    required this.targetUserId,
    required this.nickname,
    this.profileImageUrl,
    this.mannerScore = 20,
    this.followedAt,
    this.isFollowing,
  });

  factory Follow.fromJson(Map<String, dynamic> json) {
    return Follow(
      targetUserId: json['targetUserId'] ?? '',
      nickname: json['nickname'] ?? '',
      profileImageUrl: json['profileImageUrl'],
      mannerScore: double.tryParse('${json['mannerScore'] ?? ''}') ?? 20,
      followedAt: json['followedAt'],
      isFollowing: json['isFollowing'] as bool?,
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
