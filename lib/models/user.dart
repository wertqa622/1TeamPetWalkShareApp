class User {
  final String id;
  final String email;
  final String nickname;
  final String bio;
  final bool locationPublic;
  final int followers;
  final int following;
  final String createdAt;
  final String walkingStatus;

  User({
    required this.id,
    required this.email,
    required this.nickname,
    required this.bio,
    required this.locationPublic,
    required this.followers,
    required this.following,
    required this.createdAt,
    this.walkingStatus = 'off',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'nickname': nickname,
      'bio': bio,
      'locationPublic': locationPublic,
      'followers': followers,
      'following': following,
      'createdAt': createdAt,
      'walkingStatus': walkingStatus,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      nickname: json['nickname'] as String,
      bio: json['bio'] as String,
      locationPublic: json['locationPublic'] as bool,
      followers: json['followers'] as int,
      following: json['following'] as int,
      createdAt: json['createdAt'] as String,
      walkingStatus: json['walkingStatus'] as String? ?? 'off',
    );
  }

  User copyWith({
    String? id,
    String? email,
    String? nickname,
    String? bio,
    bool? locationPublic,
    int? followers,
    int? following,
    String? createdAt,
    String? walkingStatus,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      nickname: nickname ?? this.nickname,
      bio: bio ?? this.bio,
      locationPublic: locationPublic ?? this.locationPublic,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      createdAt: createdAt ?? this.createdAt,
      walkingStatus: walkingStatus ?? this.walkingStatus,
    );
  }
}


