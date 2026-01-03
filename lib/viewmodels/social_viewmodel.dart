import 'package:flutter/foundation.dart';
import '../models/social_user.dart';
import '../repositories/social_repository.dart';

class SocialViewModel extends ChangeNotifier {
  final SocialRepository _repository;
  
  List<SocialUser> _followers = [];
  List<SocialUser> _following = [];
  List<SocialUser> _searchResults = [];
  bool _isLoading = false;

  SocialViewModel({SocialRepository? repository})
      : _repository = repository ?? SocialRepository();

  List<SocialUser> get followers => _followers;
  List<SocialUser> get following => _following;
  List<SocialUser> get searchResults => _searchResults;
  bool get isLoading => _isLoading;

  Future<void> loadFollowers(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _followers = await _repository.getFollowers(userId);
    } catch (e) {
      debugPrint('Error loading followers: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadFollowing(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _following = await _repository.getFollowing(userId);
    } catch (e) {
      debugPrint('Error loading following: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 검색 시, 내 팔로잉 상태를 반영하도록 수정
  Future<void> searchUsers(String query) async {
    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final results = await _repository.searchUsers(query);
      
      // 검색된 유저들 중 내가 이미 팔로우한 유저인지 체크
      final followingIds = _following.map((u) => u.user.id).toSet();
      
      for (var user in results) {
        if (followingIds.contains(user.user.id)) {
          user.isFollowing = true;
        }
      }

      _searchResults = results;
    } catch (e) {
      debugPrint('Error searching users: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleFollow(String myUserId, SocialUser socialUser) async {
    try {
      if (socialUser.isFollowing) {
        await _repository.unfollowUser(myUserId, socialUser.user.id);
        socialUser.isFollowing = false;
        
        // 목록 갱신
        _following.removeWhere((u) => u.user.id == socialUser.user.id);
      } else {
        await _repository.followUser(myUserId, socialUser.user.id);
        socialUser.isFollowing = true;
        
        // 목록 갱신 (이미 객체는 업데이트되었으니 리스트에 추가)
        _following.add(socialUser);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling follow: $e');
    }
  }

  Future<void> removeFollower(String myUserId, SocialUser socialUser) async {
    try {
      await _repository.removeFollower(myUserId, socialUser.user.id);
      _followers.removeWhere((u) => u.user.id == socialUser.user.id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error removing follower: $e');
    }
  }

  Future<void> blockUser(String myUserId, SocialUser socialUser) async {
    try {
      await _repository.blockUser(myUserId, socialUser.user.id);
      socialUser.isBlocked = true;
      
      _followers.removeWhere((u) => u.user.id == socialUser.user.id);
      _following.removeWhere((u) => u.user.id == socialUser.user.id);
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error blocking user: $e');
    }
  }
  
  void clearSearchResults() {
    _searchResults = [];
    notifyListeners();
  }
}
