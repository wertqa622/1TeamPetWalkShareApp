class User {
  final String id;
  final String email;
  final String nickname;
  final String bio;
  final bool locationPublic;
  final int followers;
  final int following;
  final String createdAt;

  User({
    required this.id,
    required this.email,
    required this.nickname,
    required this.bio,
    required this.locationPublic,
    required this.followers,
    required this.following,
    required this.createdAt,
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
    );
  }
}


