class User {
  final String id;
  final String? nickname;
  final String? email;
  final String? profileImageUrl;
  final String? introduction;
  final String? regionSido;
  final String? regionSigungu;
  final String? regionDong;
  final bool isProfileComplete;
  final bool isPhoneVerified;
  final String? authProvider;
  final List<Child>? children;
  final String? createdAt;

  User({
    required this.id,
    this.nickname,
    this.email,
    this.profileImageUrl,
    this.introduction,
    this.regionSido,
    this.regionSigungu,
    this.regionDong,
    this.isProfileComplete = false,
    this.isPhoneVerified = false,
    this.authProvider,
    this.children,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      nickname: json['nickname'],
      email: json['email'],
      profileImageUrl: json['profileImageUrl'],
      introduction: json['introduction'],
      regionSido: json['regionSido'],
      regionSigungu: json['regionSigungu'],
      regionDong: json['regionDong'],
      isProfileComplete: json['isProfileComplete'] ?? false,
      isPhoneVerified: json['isPhoneVerified'] ?? false,
      authProvider: json['authProvider'],
      children: json['children'] != null
          ? (json['children'] as List).map((e) => Child.fromJson(e)).toList()
          : null,
      createdAt: json['createdAt'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nickname': nickname,
        'email': email,
        'profileImageUrl': profileImageUrl,
        'introduction': introduction,
        'regionSido': regionSido,
        'regionSigungu': regionSigungu,
        'regionDong': regionDong,
        'isProfileComplete': isProfileComplete,
        'isPhoneVerified': isPhoneVerified,
        'authProvider': authProvider,
      };

  User copyWith({
    String? id,
    String? nickname,
    String? email,
    String? profileImageUrl,
    String? introduction,
    String? regionSido,
    String? regionSigungu,
    String? regionDong,
    bool? isProfileComplete,
    bool? isPhoneVerified,
    String? authProvider,
    List<Child>? children,
    String? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      introduction: introduction ?? this.introduction,
      regionSido: regionSido ?? this.regionSido,
      regionSigungu: regionSigungu ?? this.regionSigungu,
      regionDong: regionDong ?? this.regionDong,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      authProvider: authProvider ?? this.authProvider,
      children: children ?? this.children,
      createdAt: createdAt ?? this.createdAt,
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
