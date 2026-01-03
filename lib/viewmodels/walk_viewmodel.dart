import 'package:flutter/foundation.dart';
import '../models/walk.dart';
import '../repositories/walk_repository.dart';
import '../repositories/social_repository.dart';

class WalkViewModel extends ChangeNotifier {
  final WalkRepository _repository;
  final SocialRepository _socialRepository;
  
  List<Walk> _walks = [];
  bool _isLoading = false;
  String? _error;

  WalkViewModel({
    WalkRepository? repository,
    SocialRepository? socialRepository,
  })  : _repository = repository ?? WalkRepository(),
        _socialRepository = socialRepository ?? SocialRepository();

  List<Walk> get walks => _walks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // 특정 유저의 산책 기록 로드 (차단 여부 확인 포함)
  Future<void> loadUserWalks(String targetUserId, String myUserId) async {
    _isLoading = true;
    _error = null;
    _walks = []; // 초기화
    notifyListeners();

    try {
      // 1. 차단 여부 확인 (상대방이 나를 차단했는지)
      final isBlocked = await _socialRepository.isBlockedBy(targetUserId, myUserId);
      if (isBlocked) {
        _error = 'blocked'; // 차단됨 식별자
        return;
      }

      // 2. 산책 기록 가져오기
      _walks = await _repository.getUserWalks(targetUserId);
    } catch (e) {
      debugPrint('Error loading walks: $e');
      _error = 'error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

