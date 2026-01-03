import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../repositories/user_repository.dart';
import '../repositories/social_repository.dart';

class UserViewModel extends ChangeNotifier {
  final UserRepository _repository;
  final SocialRepository _socialRepository;
  User? _user;
  bool _isLoading = false;

  UserViewModel({
    UserRepository? repository,
    SocialRepository? socialRepository,
  })  : _repository = repository ?? UserRepository(),
        _socialRepository = socialRepository ?? SocialRepository();

  User? get user => _user;
  bool get isLoading => _isLoading;

  Future<void> loadUser() async {
    _isLoading = true;
    notifyListeners();

    try {
      _user = await _repository.getUser();
      
      // 내 정보가 Firestore에 없으면 생성 (최초 실행 시 동기화)
      if (_user != null) {
        try {
          await _repository.updateUser(_user!);
        } catch (e) {
          debugPrint('Failed to sync user to Firestore: $e');
        }

        // 소셜 데이터와 동기화 (팔로워/팔로잉 수 업데이트)
        final followers = await _socialRepository.getFollowers(_user!.id);
        final following = await _socialRepository.getFollowing(_user!.id);
        
        _user = _user!.copyWith(
          followers: followers.length,
          following: following.length,
        );
      }
    } catch (e) {
      debugPrint('Error loading user: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUser(String nickname, String bio) async {
    if (_user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final updatedUser = _user!.copyWith(
        nickname: nickname,
        bio: bio,
      );
      
      await _repository.updateUser(updatedUser);
      _user = updatedUser;
    } catch (e) {
      debugPrint('Error updating user: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
