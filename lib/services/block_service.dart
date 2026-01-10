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

      await batch.commit();
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
