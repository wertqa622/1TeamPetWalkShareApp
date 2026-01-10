import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// 차단 관련 서비스 클래스
class BlockService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 유저 생성 시 a_user, d_user 서브컬렉션 자동 초기화
  /// Firestore 서브컬렉션은 빈 상태로는 생성되지 않으므로 초기화 문서 생성
  static Future<void> initializeBlockCollections(String userId) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      
      // a_user 컬렉션 초기화 (사용자가 차단한 유저 목록)
      await userRef
          .collection('a_user')
          .doc('.init')
          .set({
        'initialized': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // d_user 컬렉션 초기화 (사용자가 차단당한 유저 목록)
      await userRef
          .collection('d_user')
          .doc('.init')
          .set({
        'initialized': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('차단 컬렉션 초기화 완료: $userId');
    } catch (e) {
      debugPrint('차단 컬렉션 초기화 실패: $e');
      // 초기화 실패해도 계속 진행 (이미 존재할 수 있음)
    }
  }

  /// 사용자 차단
  /// user1이 user2를 차단하면:
  /// - users/user1/a_user/{user2의 nickname} 생성 (user1이 차단한 목록) - 차단당한 유저의 전체 정보 저장
  /// - users/user2/d_user/{user1의 nickname} 생성 (user2가 차단당한 목록)
  static Future<void> blockUser(String blockerId, String blockedId) async {
    try {
      // 차단하는 유저의 컬렉션 초기화 확인
      await _ensureUserInitialized(blockerId);
      // 차단당하는 유저의 컬렉션 초기화 확인
      await _ensureUserInitialized(blockedId);

      // 차단당하는 유저의 전체 정보 가져오기
      final blockedUserDoc = await _firestore
          .collection('users')
          .doc(blockedId)
          .get();

      if (!blockedUserDoc.exists) {
        throw Exception('차단할 유저 정보를 찾을 수 없습니다: $blockedId');
      }

      final blockedUserData = blockedUserDoc.data()!;
      final blockedNicknameRaw = blockedUserData['nickname'] as String? ?? '';
      
      if (blockedNicknameRaw.isEmpty) {
        throw Exception('차단할 유저의 닉네임을 찾을 수 없습니다: $blockedId');
      }

      // Firestore 문서 ID에 사용할 수 없는 문자 제거/치환
      // Firestore 문서 ID는 /, ?, #, [, ], * 문자를 사용할 수 없음
      final blockedNickname = blockedNicknameRaw
          .replaceAll('/', '_')
          .replaceAll('?', '_')
          .replaceAll('#', '_')
          .replaceAll('[', '_')
          .replaceAll(']', '_')
          .replaceAll('*', '_')
          .trim();

      // 차단한 사람(blocker)의 정보도 가져오기
      final blockerUserDoc = await _firestore
          .collection('users')
          .doc(blockerId)
          .get();
      
      if (!blockerUserDoc.exists) {
        throw Exception('차단하는 유저 정보를 찾을 수 없습니다: $blockerId');
      }

      final blockerUserData = blockerUserDoc.data()!;
      final blockerNicknameRaw = blockerUserData['nickname'] as String? ?? '';
      
      if (blockerNicknameRaw.isEmpty) {
        throw Exception('차단하는 유저의 닉네임을 찾을 수 없습니다: $blockerId');
      }

      // Firestore 문서 ID에 사용할 수 없는 문자 제거/치환
      final blockerNickname = blockerNicknameRaw
          .replaceAll('/', '_')
          .replaceAll('?', '_')
          .replaceAll('#', '_')
          .replaceAll('[', '_')
          .replaceAll(']', '_')
          .replaceAll('*', '_')
          .trim();
      
      final batch = _firestore.batch();

      // blockerId의 a_user 컬렉션에 blockedNickname을 문서 ID로 사용 (유저 전체 정보 포함)
      final aUserRef = _firestore
          .collection('users')
          .doc(blockerId)
          .collection('a_user')
          .doc(blockedNickname);
      
      debugPrint('a_user 문서 ID: $blockedNickname (원본: $blockedNicknameRaw)');
      
      // users 컬렉션의 유저 정보를 모두 저장 (nickname을 첫 번째 필드로)
      // 원본 nickname도 저장 (문서 ID는 정규화된 버전 사용)
      batch.set(aUserRef, {
        'nickname': blockedNicknameRaw, // 원본 nickname 저장
        'blockedId': blockedId,
        'id': blockedUserData['id'] ?? blockedId,
        'bio': blockedUserData['bio'] ?? '',
        'email': blockedUserData['email'] ?? '', // 차단당한 유저의 이메일
        'locationPublic': blockedUserData['locationPublic'] ?? true,
        'followers': blockedUserData['followers'] ?? 0,
        'following': blockedUserData['following'] ?? 0,
        'createdAt': blockedUserData['createdAt'] ?? FieldValue.serverTimestamp(),
        'blockedAt': FieldValue.serverTimestamp(), // 차단한 시점
      });

      // blockedId의 d_user 컬렉션에 blockerNickname을 문서 ID로 사용
      final dUserRef = _firestore
          .collection('users')
          .doc(blockedId)
          .collection('d_user')
          .doc(blockerNickname);
      
      debugPrint('d_user 문서 ID: $blockerNickname (원본: $blockerNicknameRaw)');
      
      batch.set(dUserRef, {
        'nickname': blockerNicknameRaw, // 원본 nickname 저장
        'blockerId': blockerId,
        'id': blockerUserData['id'] ?? blockerId,
        'bio': blockerUserData['bio'] ?? '',
        'email': blockerUserData['email'] ?? '', // 차단한 유저의 이메일
        'locationPublic': blockerUserData['locationPublic'] ?? true,
        'followers': blockerUserData['followers'] ?? 0,
        'following': blockerUserData['following'] ?? 0,
        'createdAt': blockerUserData['createdAt'] ?? FieldValue.serverTimestamp(),
        'blockedAt': FieldValue.serverTimestamp(), // 차단당한 시점
      });

      // 차단 시 양방향 팔로우 관계 모두 끊기
      // 차단이 발생하면 무조건 양방향 팔로우 관계를 모두 끊어야 함
      // 1. blockerId가 blockedId를 팔로우하고 있는지 확인
      final blockerFollowingBlockedRef = _firestore
          .collection('users')
          .doc(blockerId)
          .collection('following')
          .doc(blockedId);
      
      final blockerFollowingBlockedDoc = await blockerFollowingBlockedRef.get();
      bool blockerWasFollowingBlocked = blockerFollowingBlockedDoc.exists;
      debugPrint('차단 시 팔로우 확인: $blockerId가 $blockedId를 팔로우 중? $blockerWasFollowingBlocked');

      // 2. blockedId가 blockerId를 팔로우하고 있는지 확인
      final blockedFollowingBlockerRef = _firestore
          .collection('users')
          .doc(blockedId)
          .collection('following')
          .doc(blockerId);
      
      debugPrint('차단 시 팔로우 확인: $blockedId의 following 컬렉션에서 $blockerId 문서 확인 중...');
      final blockedFollowingBlockerDoc = await blockedFollowingBlockerRef.get();
      bool blockedWasFollowingBlocker = blockedFollowingBlockerDoc.exists;
      debugPrint('차단 시 팔로우 확인 결과: $blockedId가 $blockerId를 팔로우 중? $blockedWasFollowingBlocker (문서 ID: ${blockedFollowingBlockerDoc.id}, 존재: ${blockedFollowingBlockerDoc.exists})');
      
      // 3. a_user나 d_user에 상대방이 있는지 확인 (추가 안전장치)
      // blockerId의 a_user에 blockedId가 있는지 확인
      final blockerAUserRef = _firestore
          .collection('users')
          .doc(blockerId)
          .collection('a_user')
          .doc(blockedNickname);
      final blockerAUserDoc = await blockerAUserRef.get();
      bool blockerHasBlockedInAUser = blockerAUserDoc.exists;
      debugPrint('차단 시 a_user 확인: $blockerId의 a_user에 $blockedNickname이 있음? $blockerHasBlockedInAUser');
      
      // blockedId의 d_user에 blockerId가 있는지 확인
      final blockedDUserRef = _firestore
          .collection('users')
          .doc(blockedId)
          .collection('d_user')
          .doc(blockerNickname);
      final blockedDUserDoc = await blockedDUserRef.get();
      bool blockedHasBlockerInDUser = blockedDUserDoc.exists;
      debugPrint('차단 시 d_user 확인: $blockedId의 d_user에 $blockerNickname이 있음? $blockedHasBlockerInDUser');

      // 3. 양방향 팔로우 관계 모두 삭제
      final blockerUserRef = _firestore.collection('users').doc(blockerId);
      final blockedUserRef = _firestore.collection('users').doc(blockedId);
      
      int blockerFollowingDecrement = 0;
      int blockerFollowersDecrement = 0;
      int blockedFollowingDecrement = 0;
      int blockedFollowersDecrement = 0;

      // blockerId가 blockedId를 팔로우하고 있거나, a_user에 blockedId가 있으면 무조건 제거
      if (blockerWasFollowingBlocked || blockerHasBlockedInAUser) {
        // blockerId의 following에서 blockedId 제거 (차단이 발생했으므로 무조건 제거)
        debugPrint('차단 시 팔로우 관계 제거 시작: $blockerId의 following에서 $blockedId 삭제 (팔로우 중: $blockerWasFollowingBlocked, a_user에 있음: $blockerHasBlockedInAUser)');
        
        // 차단이 발생했으므로 무조건 following에서 제거 (존재 여부와 관계없이 시도)
        if (blockerWasFollowingBlocked) {
          batch.delete(blockerFollowingBlockedRef);
          debugPrint('차단 시 팔로우 관계 제거: users/$blockerId/following/$blockedId 문서 삭제를 배치에 추가함');
          blockerFollowingDecrement = 1;
        } else {
          // a_user에 있지만 following에 없을 수도 있으므로, 존재 여부를 다시 확인하고 삭제 시도
          final checkDoc = await blockerFollowingBlockedRef.get();
          if (checkDoc.exists) {
            batch.delete(blockerFollowingBlockedRef);
            debugPrint('차단 시 팔로우 관계 제거: users/$blockerId/following/$blockedId 문서가 존재하여 삭제를 배치에 추가함');
            blockerFollowingDecrement = 1;
          } else {
            debugPrint('차단 시 팔로우 관계 확인: $blockerId의 following에 $blockedId 문서가 실제로 없음');
          }
        }
        
        // blockedId의 followers에서 blockerId 제거
        final blockedFollowersRef = _firestore
            .collection('users')
            .doc(blockedId)
            .collection('followers')
            .doc(blockerId);
        final blockedFollowersDoc = await blockedFollowersRef.get();
        if (blockedFollowersDoc.exists) {
          batch.delete(blockedFollowersRef);
          debugPrint('차단 시 팔로우 관계 제거: users/$blockedId/followers/$blockerId 문서 삭제를 배치에 추가함');
          blockedFollowersDecrement = 1;
        } else {
          debugPrint('차단 시 팔로우 관계 확인: $blockedId의 followers에 $blockerId 문서가 없음');
        }
        
        debugPrint('차단 시 팔로우 관계 제거 완료: $blockerId가 $blockedId를 팔로우하고 있었음 (following 감소: $blockerFollowingDecrement, followers 감소: $blockedFollowersDecrement)');
      } else {
        debugPrint('차단 시 팔로우 관계 확인: $blockerId가 $blockedId를 팔로우하고 있지 않음');
      }

      // blockedId가 blockerId를 팔로우하고 있거나, d_user에 blockerId가 있으면 무조건 제거
      if (blockedWasFollowingBlocker || blockedHasBlockerInDUser) {
        // blockedId의 following에서 blockerId 제거 (차단이 발생했으므로 무조건 제거)
        debugPrint('차단 시 팔로우 관계 제거 시작: $blockedId의 following에서 $blockerId 삭제 (팔로우 중: $blockedWasFollowingBlocker, d_user에 있음: $blockedHasBlockerInDUser)');
        
        // 차단이 발생했으므로 무조건 following에서 제거 (존재 여부와 관계없이 시도)
        if (blockedWasFollowingBlocker) {
          batch.delete(blockedFollowingBlockerRef);
          debugPrint('차단 시 팔로우 관계 제거: users/$blockedId/following/$blockerId 문서 삭제를 배치에 추가함');
          blockedFollowingDecrement = 1;
        } else {
          // d_user에 있지만 following에 없을 수도 있으므로, 존재 여부를 다시 확인하고 삭제 시도
          final checkDoc = await blockedFollowingBlockerRef.get();
          if (checkDoc.exists) {
            batch.delete(blockedFollowingBlockerRef);
            debugPrint('차단 시 팔로우 관계 제거: users/$blockedId/following/$blockerId 문서가 존재하여 삭제를 배치에 추가함');
            blockedFollowingDecrement = 1;
          } else {
            debugPrint('차단 시 팔로우 관계 확인: $blockedId의 following에 $blockerId 문서가 실제로 없음');
          }
        }
        
        // blockerId의 followers에서 blockedId 제거
        final blockerFollowersRef = _firestore
            .collection('users')
            .doc(blockerId)
            .collection('followers')
            .doc(blockedId);
        final blockerFollowersDoc = await blockerFollowersRef.get();
        if (blockerFollowersDoc.exists) {
          batch.delete(blockerFollowersRef);
          debugPrint('차단 시 팔로우 관계 제거: users/$blockerId/followers/$blockedId 문서 삭제를 배치에 추가함');
          blockerFollowersDecrement = 1;
        } else {
          debugPrint('차단 시 팔로우 관계 확인: $blockerId의 followers에 $blockedId 문서가 없음');
        }
        
        debugPrint('차단 시 팔로우 관계 제거 완료: $blockedId가 $blockerId를 팔로우하고 있었음 (following 감소: $blockedFollowingDecrement, followers 감소: $blockerFollowersDecrement)');
      } else {
        debugPrint('차단 시 팔로우 관계 확인: $blockedId가 $blockerId를 팔로우하고 있지 않음');
      }

      // 카운트 업데이트 (각 문서당 한 번만 업데이트)
      if (blockerFollowingDecrement > 0 || blockerFollowersDecrement > 0) {
        final blockerUpdate = <String, dynamic>{};
        if (blockerFollowingDecrement > 0) {
          blockerUpdate['following'] = FieldValue.increment(-blockerFollowingDecrement);
        }
        if (blockerFollowersDecrement > 0) {
          blockerUpdate['followers'] = FieldValue.increment(-blockerFollowersDecrement);
        }
        batch.update(blockerUserRef, blockerUpdate);
      }

      if (blockedFollowingDecrement > 0 || blockedFollowersDecrement > 0) {
        final blockedUpdate = <String, dynamic>{};
        if (blockedFollowingDecrement > 0) {
          blockedUpdate['following'] = FieldValue.increment(-blockedFollowingDecrement);
          debugPrint('차단 시 카운트 업데이트: $blockedId의 following을 ${-blockedFollowingDecrement}만큼 감소');
        }
        if (blockedFollowersDecrement > 0) {
          blockedUpdate['followers'] = FieldValue.increment(-blockedFollowersDecrement);
          debugPrint('차단 시 카운트 업데이트: $blockedId의 followers를 ${-blockedFollowersDecrement}만큼 감소');
        }
        batch.update(blockedUserRef, blockedUpdate);
        debugPrint('차단 시 카운트 업데이트 배치 추가: $blockedId 문서 업데이트');
      } else {
        debugPrint('차단 시 카운트 업데이트: $blockedId의 카운트 변경 없음');
      }

      debugPrint('차단 배치 커밋 시작... (총 ${blockerFollowingDecrement + blockerFollowersDecrement + blockedFollowingDecrement + blockedFollowersDecrement}개의 관계 제거 예정)');
      await batch.commit();
      debugPrint('차단 배치 커밋 완료:');
      debugPrint('  - users/$blockerId/following/$blockedId 삭제: ${blockerFollowingDecrement > 0 ? "예" : "아니오"}');
      debugPrint('  - users/$blockedId/following/$blockerId 삭제: ${blockedFollowingDecrement > 0 ? "예" : "아니오"}');
      debugPrint('  - users/$blockerId/followers/$blockedId 삭제: ${blockerFollowersDecrement > 0 ? "예" : "아니오"}');
      debugPrint('  - users/$blockedId/followers/$blockerId 삭제: ${blockedFollowersDecrement > 0 ? "예" : "아니오"}');
      debugPrint('StreamBuilder가 자동으로 감지하여 UI가 갱신됩니다.');
      debugPrint('차단 완료: $blockerId가 $blockedId를 차단 (a_user 문서 ID: $blockedNickname, d_user 문서 ID: $blockerNickname)');
    } catch (e) {
      debugPrint('차단 실패: $e');
      rethrow;
    }
  }

  /// 유저의 차단 컬렉션이 초기화되어 있는지 확인하고 없으면 초기화
  static Future<void> _ensureUserInitialized(String userId) async {
    try {
      final aUserInitRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('a_user')
          .doc('.init');
      
      final aUserInitDoc = await aUserInitRef.get();
      
      // a_user 컬렉션이 없으면 초기화
      if (!aUserInitDoc.exists) {
        await initializeBlockCollections(userId);
      }
    } catch (e) {
      // 초기화 실패 시 다시 시도
      try {
        await initializeBlockCollections(userId);
      } catch (e2) {
        debugPrint('유저 초기화 실패 (userId: $userId): $e2');
      }
    }
  }

  /// 차단 해제
  static Future<void> unblockUser(String blockerId, String blockedId) async {
    try {
      // blockedId의 nickname 찾기
      final blockedUserDoc = await _firestore
          .collection('users')
          .doc(blockedId)
          .get();
      
      if (!blockedUserDoc.exists) {
        throw Exception('차단 해제할 유저 정보를 찾을 수 없습니다: $blockedId');
      }

      final blockedUserData = blockedUserDoc.data()!;
      final blockedNicknameRaw = blockedUserData['nickname'] as String? ?? '';
      
      if (blockedNicknameRaw.isEmpty) {
        throw Exception('차단 해제할 유저의 닉네임을 찾을 수 없습니다: $blockedId');
      }

      // Firestore 문서 ID에 사용할 수 없는 문자 제거/치환
      final blockedNickname = blockedNicknameRaw
          .replaceAll('/', '_')
          .replaceAll('?', '_')
          .replaceAll('#', '_')
          .replaceAll('[', '_')
          .replaceAll(']', '_')
          .replaceAll('*', '_')
          .trim();

      // blockerId의 nickname 찾기
      final blockerUserDoc = await _firestore
          .collection('users')
          .doc(blockerId)
          .get();
      
      if (!blockerUserDoc.exists) {
        throw Exception('차단 해제하는 유저 정보를 찾을 수 없습니다: $blockerId');
      }

      final blockerUserData = blockerUserDoc.data()!;
      final blockerNicknameRaw = blockerUserData['nickname'] as String? ?? '';
      
      if (blockerNicknameRaw.isEmpty) {
        throw Exception('차단 해제하는 유저의 닉네임을 찾을 수 없습니다: $blockerId');
      }

      // Firestore 문서 ID에 사용할 수 없는 문자 제거/치환
      final blockerNickname = blockerNicknameRaw
          .replaceAll('/', '_')
          .replaceAll('?', '_')
          .replaceAll('#', '_')
          .replaceAll('[', '_')
          .replaceAll(']', '_')
          .replaceAll('*', '_')
          .trim();

      final batch = _firestore.batch();

      // blockerId의 a_user 컬렉션에서 blockedNickname 문서 제거
      final aUserRef = _firestore
          .collection('users')
          .doc(blockerId)
          .collection('a_user')
          .doc(blockedNickname);
      
      batch.delete(aUserRef);

      // blockedId의 d_user 컬렉션에서 blockerNickname 문서 제거
      final dUserRef = _firestore
          .collection('users')
          .doc(blockedId)
          .collection('d_user')
          .doc(blockerNickname);
      
      batch.delete(dUserRef);

      await batch.commit();
      debugPrint('차단 해제 완료: $blockerId가 $blockedId 차단 해제');
    } catch (e) {
      debugPrint('차단 해제 실패: $e');
      rethrow;
    }
  }

  /// 사용자가 차단한 유저 목록 조회 (nickname 리스트 반환)
  static Future<List<String>> getBlockedUsers(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('a_user')
          .get();

      return snapshot.docs
          .where((doc) => doc.id != '.init') // 초기화 문서 제외
          .map((doc) => doc.id) // 문서 ID가 nickname
          .toList();
    } catch (e) {
      debugPrint('차단 목록 조회 실패: $e');
      return [];
    }
  }

  /// 사용자가 차단당한 유저 목록 조회 (nickname 리스트 반환)
  static Future<List<String>> getBlockedByUsers(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('d_user')
          .get();

      return snapshot.docs
          .where((doc) => doc.id != '.init') // 초기화 문서 제외
          .map((doc) => doc.id) // 문서 ID가 nickname
          .toList();
    } catch (e) {
      debugPrint('차단당한 목록 조회 실패: $e');
      return [];
    }
  }

  /// 특정 사용자가 나를 차단했는지 확인
  static Future<bool> isBlockedBy(String userId, String otherUserId) async {
    try {
      // userId의 nickname 찾기
      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) {
        return false;
      }

      final userData = userDoc.data()!;
      final userNicknameRaw = userData['nickname'] as String? ?? '';
      
      if (userNicknameRaw.isEmpty) {
        return false;
      }

      // Firestore 문서 ID에 사용할 수 없는 문자 제거/치환
      final userNickname = userNicknameRaw
          .replaceAll('/', '_')
          .replaceAll('?', '_')
          .replaceAll('#', '_')
          .replaceAll('[', '_')
          .replaceAll(']', '_')
          .replaceAll('*', '_')
          .trim();

      // otherUserId의 a_user 컬렉션에서 userNickname 문서 확인
      final doc = await _firestore
          .collection('users')
          .doc(otherUserId)
          .collection('a_user')
          .doc(userNickname)
          .get();

      return doc.exists;
    } catch (e) {
      debugPrint('차단 확인 실패: $e');
      return false;
    }
  }
}
