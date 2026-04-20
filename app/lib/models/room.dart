import 'user.dart';

class Room {
  final String id;
  final String title;
  final String? description;
  final String date;
  final String startTime;
  final String? endTime;
  final String? regionSido;
  final String? regionSigungu;
  final String regionDong;
  final int ageMonthMin;
  final int ageMonthMax;
  final String placeType;
  final String? placeName;
  final String? placeAddress;
  final double? latitude;
  final double? longitude;
  final int maxMembers;
  final int currentMembers;
  final String joinType;
  final int cost;
  final String? costDescription;
  final List<String> tags;
  final String status;
  final RoomHost host;
  final List<RoomMember>? members;
  final String? myStatus;
  final bool? canJoin;
  final String? canJoinReason;
  final String? chatRoomId;
  final String? createdAt;

  Room({
    required this.id,
    required this.title,
    this.description,
    required this.date,
    required this.startTime,
    this.endTime,
    this.regionSido,
    this.regionSigungu,
    required this.regionDong,
    required this.ageMonthMin,
    required this.ageMonthMax,
    required this.placeType,
    this.placeName,
    this.placeAddress,
    this.latitude,
    this.longitude,
    required this.maxMembers,
    required this.currentMembers,
    required this.joinType,
    this.cost = 0,
    this.costDescription,
    this.tags = const [],
    required this.status,
    required this.host,
    this.members,
    this.myStatus,
    this.canJoin,
    this.canJoinReason,
    this.chatRoomId,
    this.createdAt,
  });

  bool get isRecruiting => status == 'RECRUITING';
  bool get isFull => currentMembers >= maxMembers;
  bool get isFree => cost == 0;
  bool get isApprovalRequired => joinType == 'APPROVAL';

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      date: json['date'] ?? '',
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'],
      regionSido: json['regionSido'],
      regionSigungu: json['regionSigungu'],
      regionDong: json['regionDong'] ?? '',
      ageMonthMin: json['ageMonthMin'] ?? 0,
      ageMonthMax: json['ageMonthMax'] ?? 0,
      placeType: json['placeType'] ?? 'OTHER',
      placeName: json['placeName'],
      placeAddress: json['placeAddress'],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      maxMembers: json['maxMembers'] ?? 5,
      currentMembers: json['currentMembers'] ?? 0,
      joinType: json['joinType'] ?? 'FREE',
      cost: json['cost'] ?? 0,
      costDescription: json['costDescription'],
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      status: json['status'] ?? 'RECRUITING',
      host: RoomHost.fromJson(json['host'] ?? {}),
      members: json['members'] != null
          ? (json['members'] as List)
              .map((e) => RoomMember.fromJson(e))
              .toList()
          : null,
      myStatus: json['myStatus'],
      canJoin: json['canJoin'],
      canJoinReason: json['canJoinReason'],
      chatRoomId: json['chatRoomId'],
      createdAt: json['createdAt'],
    );
  }
}

class RoomHost {
  final String id;
  final String nickname;
  final String? profileImageUrl;
  final String? regionSigungu;

  RoomHost({
    required this.id,
    required this.nickname,
    this.profileImageUrl,
    this.regionSigungu,
  });

  factory RoomHost.fromJson(Map<String, dynamic> json) {
    return RoomHost(
      id: json['id'] ?? '',
      nickname: json['nickname'] ?? '',
      profileImageUrl: json['profileImageUrl'],
      regionSigungu: json['regionSigungu'],
    );
  }
}

class RoomMember {
  final String id;
  final String nickname;
  final String? profileImageUrl;
  final List<Child>? children;
  final bool isHost;

  RoomMember({
    required this.id,
    required this.nickname,
    this.profileImageUrl,
    this.children,
    this.isHost = false,
  });

  factory RoomMember.fromJson(Map<String, dynamic> json) {
    return RoomMember(
      id: json['id'] ?? '',
      nickname: json['nickname'] ?? '',
      profileImageUrl: json['profileImageUrl'],
      children: json['children'] != null
          ? (json['children'] as List).map((e) => Child.fromJson(e)).toList()
          : null,
      isHost: json['isHost'] ?? false,
    );
  }
}

class JoinRequest {
  final String id;
  final RoomMember user;
  final String status;
  final String? createdAt;

  JoinRequest({
    required this.id,
    required this.user,
    required this.status,
    this.createdAt,
  });

  factory JoinRequest.fromJson(Map<String, dynamic> json) {
    return JoinRequest(
      id: json['id'] ?? '',
      user: RoomMember.fromJson(json['user'] ?? {}),
      status: json['status'] ?? 'PENDING',
      createdAt: json['createdAt'],
    );
  }
}

class MapCluster {
  final String regionDong;
  final int count;
  final double latitude;
  final double longitude;

  MapCluster({
    required this.regionDong,
    required this.count,
    required this.latitude,
    required this.longitude,
  });

  factory MapCluster.fromJson(Map<String, dynamic> json) {
    return MapCluster(
      regionDong: json['regionDong'] ?? '',
      count: json['count'] ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
    );
  }
}

class MapPin {
  final String id;
  final String title;
  final String date;
  final String startTime;
  final int ageMonthMin;
  final int ageMonthMax;
  final int currentMembers;
  final int maxMembers;
  final double latitude;
  final double longitude;

  MapPin({
    required this.id,
    required this.title,
    required this.date,
    required this.startTime,
    required this.ageMonthMin,
    required this.ageMonthMax,
    required this.currentMembers,
    required this.maxMembers,
    required this.latitude,
    required this.longitude,
  });

  factory MapPin.fromJson(Map<String, dynamic> json) {
    return MapPin(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      date: json['date'] ?? '',
      startTime: json['startTime'] ?? '',
      ageMonthMin: json['ageMonthMin'] ?? 0,
      ageMonthMax: json['ageMonthMax'] ?? 0,
      currentMembers: json['currentMembers'] ?? 0,
      maxMembers: json['maxMembers'] ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
    );
  }
}
