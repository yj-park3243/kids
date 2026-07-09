/// 홈 탭 "우리 아이 활동 일지" 단일 응답 모델.
/// GET /dashboard/me 의 결과를 그대로 매핑한다.
class DashboardSummary {
  final DashboardStats stats;
  final List<FrequentFriend> frequentFriends;
  final List<RecentPhoto> recentPhotos;
  final List<String> activeDates; // 'YYYY-MM-DD', 전체 기간 참여 날짜(예정 포함)

  const DashboardSummary({
    required this.stats,
    required this.frequentFriends,
    required this.recentPhotos,
    required this.activeDates,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      stats: DashboardStats.fromJson(
        (json['stats'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      frequentFriends: (json['frequentFriends'] as List? ?? const [])
          .map((e) => FrequentFriend.fromJson(e as Map<String, dynamic>))
          .toList(),
      recentPhotos: (json['recentPhotos'] as List? ?? const [])
          .map((e) => RecentPhoto.fromJson(e as Map<String, dynamic>))
          .toList(),
      // 구서버엔 activeDates 가 없으므로 monthlyDates(이번 달만)로 폴백.
      activeDates:
          ((json['activeDates'] ?? json['monthlyDates']) as List? ?? const [])
              .map((e) => e.toString())
              .toList(),
    );
  }

  static const empty = DashboardSummary(
    stats: DashboardStats(totalRooms: 0, uniqueFriends: 0, uniquePlaces: 0),
    frequentFriends: [],
    recentPhotos: [],
    activeDates: [],
  );
}

class DashboardStats {
  final int totalRooms; // 누적 참여 모임 수 (취소 제외, 오늘까지)
  final int uniqueFriends; // 같이 모임한 부모 수 (distinct)
  final int uniquePlaces; // 다녀온 장소 수 (distinct)

  const DashboardStats({
    required this.totalRooms,
    required this.uniqueFriends,
    required this.uniquePlaces,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) => DashboardStats(
    totalRooms: (json['totalRooms'] as num?)?.toInt() ?? 0,
    uniqueFriends: (json['uniqueFriends'] as num?)?.toInt() ?? 0,
    uniquePlaces: (json['uniquePlaces'] as num?)?.toInt() ?? 0,
  );
}

class FrequentFriend {
  final String userId;
  final String nickname;
  final String? profileImageUrl;
  final String? childPhotoUrl; // 같이 다닌 부모의 첫째 아이 프로필 사진
  final int jointCount;

  const FrequentFriend({
    required this.userId,
    required this.nickname,
    required this.profileImageUrl,
    required this.childPhotoUrl,
    required this.jointCount,
  });

  factory FrequentFriend.fromJson(Map<String, dynamic> json) => FrequentFriend(
    userId: json['userId'] as String? ?? '',
    nickname: json['nickname'] as String? ?? '',
    profileImageUrl: json['profileImageUrl'] as String?,
    childPhotoUrl: json['childPhotoUrl'] as String?,
    jointCount: (json['jointCount'] as num?)?.toInt() ?? 0,
  );
}

class RecentPhoto {
  final String id;
  final String url;
  final String roomId;
  final String? createdAt;

  const RecentPhoto({
    required this.id,
    required this.url,
    required this.roomId,
    required this.createdAt,
  });

  factory RecentPhoto.fromJson(Map<String, dynamic> json) => RecentPhoto(
    id: json['id'] as String? ?? '',
    url: json['url'] as String? ?? '',
    roomId: json['roomId'] as String? ?? '',
    createdAt: json['createdAt']?.toString(),
  );
}
