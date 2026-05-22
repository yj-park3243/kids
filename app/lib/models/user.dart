class User {
  final String id;
  final String? nickname;
  final String? email;
  final String? profileImageUrl;
  final String? introduction;
  final bool isProfileComplete;
  final bool isPhoneVerified;
  final String? authProvider;
  final List<Child>? children;
  final String? createdAt;
  final String? parentGender; // 'MOM' | 'DAD' | null
  final bool isSingleParent;
  final double mannerScore;
  final List<String>? mannerTags; // 타 유저 프로필 조회 시만
  final String? noShowLevel; // 'NONE' | 'OCCASIONAL' | 'FREQUENT'
  final bool? isFollowing; // 타 유저 프로필 조회 시만
  final bool? isBlocked; // 타 유저 프로필 조회 시만
  final String? regionSigungu; // 타 유저 프로필 조회 시
  final int? roomCount; // 타 유저 프로필 조회 시 — 참여한 모임 수
  final String status; // ACTIVE | SUSPENDED | BANNED | WITHDRAWN

  User({
    required this.id,
    this.nickname,
    this.email,
    this.profileImageUrl,
    this.introduction,
    this.isProfileComplete = false,
    this.isPhoneVerified = false,
    this.authProvider,
    this.children,
    this.createdAt,
    this.parentGender,
    this.isSingleParent = false,
    this.mannerScore = 36.5,
    this.mannerTags,
    this.noShowLevel,
    this.isFollowing,
    this.isBlocked,
    this.regionSigungu,
    this.roomCount,
    this.status = 'ACTIVE',
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      nickname: json['nickname'],
      email: json['email'],
      profileImageUrl: json['profileImageUrl'],
      introduction: json['introduction'],
      isProfileComplete: json['isProfileComplete'] ?? false,
      isPhoneVerified: json['isPhoneVerified'] ?? false,
      authProvider: json['authProvider'],
      children: json['children'] != null
          ? (json['children'] as List).map((e) => Child.fromJson(e)).toList()
          : null,
      createdAt: json['createdAt'],
      parentGender: json['parentGender'],
      isSingleParent: json['isSingleParent'] ?? false,
      mannerScore: (json['mannerScore'] as num?)?.toDouble() ?? 36.5,
      mannerTags: json['mannerTags'] != null
          ? (json['mannerTags'] as List).map((e) => e.toString()).toList()
          : null,
      noShowLevel: json['noShowLevel'],
      isFollowing: json['isFollowing'],
      isBlocked: json['isBlocked'],
      regionSigungu: json['regionSigungu'],
      roomCount: (json['roomCount'] as num?)?.toInt(),
      status: json['status'] ?? 'ACTIVE',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nickname': nickname,
        'email': email,
        'profileImageUrl': profileImageUrl,
        'introduction': introduction,
        'isProfileComplete': isProfileComplete,
        'isPhoneVerified': isPhoneVerified,
        'authProvider': authProvider,
        'parentGender': parentGender,
        'isSingleParent': isSingleParent,
        'mannerScore': mannerScore,
        'mannerTags': mannerTags,
        'noShowLevel': noShowLevel,
        'isFollowing': isFollowing,
        'isBlocked': isBlocked,
        'regionSigungu': regionSigungu,
        'roomCount': roomCount,
        'status': status,
      };

  User copyWith({
    String? id,
    String? nickname,
    String? email,
    String? profileImageUrl,
    String? introduction,
    bool? isProfileComplete,
    bool? isPhoneVerified,
    String? authProvider,
    List<Child>? children,
    String? createdAt,
    String? parentGender,
    bool? isSingleParent,
    double? mannerScore,
    List<String>? mannerTags,
    String? noShowLevel,
    bool? isFollowing,
    bool? isBlocked,
    String? regionSigungu,
    int? roomCount,
    String? status,
  }) {
    return User(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      introduction: introduction ?? this.introduction,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      authProvider: authProvider ?? this.authProvider,
      children: children ?? this.children,
      createdAt: createdAt ?? this.createdAt,
      parentGender: parentGender ?? this.parentGender,
      isSingleParent: isSingleParent ?? this.isSingleParent,
      mannerScore: mannerScore ?? this.mannerScore,
      mannerTags: mannerTags ?? this.mannerTags,
      noShowLevel: noShowLevel ?? this.noShowLevel,
      isFollowing: isFollowing ?? this.isFollowing,
      isBlocked: isBlocked ?? this.isBlocked,
      regionSigungu: regionSigungu ?? this.regionSigungu,
      roomCount: roomCount ?? this.roomCount,
      status: status ?? this.status,
    );
  }
}

class Child {
  final String id;
  final String nickname;
  final int birthYear;
  final int birthMonth;
  final int? ageMonths;
  final String? gender;
  final String? createdAt;

  Child({
    required this.id,
    required this.nickname,
    required this.birthYear,
    required this.birthMonth,
    this.ageMonths,
    this.gender,
    this.createdAt,
  });

  factory Child.fromJson(Map<String, dynamic> json) {
    return Child(
      id: json['id'] ?? '',
      nickname: json['nickname'] ?? '',
      birthYear: json['birthYear'] ?? 0,
      birthMonth: json['birthMonth'] ?? 0,
      ageMonths: json['ageMonths'],
      gender: json['gender'],
      createdAt: json['createdAt'],
    );
  }

  Map<String, dynamic> toJson() => {
        'nickname': nickname,
        'birthYear': birthYear,
        'birthMonth': birthMonth,
        'gender': gender,
      };
}
