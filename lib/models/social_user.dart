import 'user.dart';

class SocialUser {
  final User user;
  bool isFollowing;
  bool isBlocked;

  SocialUser({
    required this.user,
    this.isFollowing = false,
    this.isBlocked = false,
  });
}

