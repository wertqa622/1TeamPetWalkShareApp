import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import 'block_service.dart';

/// 팔로우 관련 서비스 클래스
class FollowService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 사용자 A가 사용자 B를 팔로우
  /// - users/B/followers/A 생성 (B를 팔로우하는 사람 목록에 A 추가) - A(팔로워)의 정보 저장
  /// - users/A/following/B 생성 (A가 팔로우하는 사람 목록에 B 추가) - B(팔로우당한 사람)의 정보 저장
  /// - users/B 문서의 followers 카운트 증가
  /// - users/A 문서의 following 카운트 증가
  static Future<void> followUser(String followerId, String followingId) async {
    try {
      // 차단 관계 확인 (양방향)
      final isBlocked = await BlockService.isBlockedBetween(followerId, followingId);
      if (isBlocked) {
        throw Exception('차단된 사용자는 팔로우할 수 없습니다.');
      }

      // 팔로우할 유저(팔로우당한 사람)의 전체 정보 가져오기
      final followingUserDoc = await _firestore
          .collection('users')
          .doc(followingId)
          .get();

      if (!followingUserDoc.exists) {
        throw Exception('팔로우할 유저 정보를 찾을 수 없습니다: $followingId');
      }

      final followingUserData = followingUserDoc.data()!;
      
      // 팔로워(팔로우하는 사람)의 전체 정보 가져오기
      final followerUserDoc = await _firestore
          .collection('users')
          .doc(followerId)
          .get();

      if (!followerUserDoc.exists) {
        throw Exception('팔로워 유저 정보를 찾을 수 없습니다: $followerId');
      }

      final followerUserData = followerUserDoc.data()!;
      
      final batch = _firestore.batch();

      // users/{followingId}/followers/{followerId} 생성 (팔로우당한 유저의 팔로워 목록)
      // 여기에는 팔로워(follower)의 정보를 저장해야 함
      final followersRef = _firestore
          .collection('users')
          .doc(followingId)
          .collection('followers')
          .doc(followerId);
      
      batch.set(followersRef, {
        'followerId': followerId,
        'id': followerUserData['id'] ?? followerId, // 팔로워의 ID
        'nickname': followerUserData['nickname'] ?? '', // 팔로워의 닉네임
        'bio': followerUserData['bio'] ?? '', // 팔로워의 소개
        'email': followerUserData['email'] ?? '', // 팔로워의 이메일
        'locationPublic': followerUserData['locationPublic'] ?? true,
        'followers': followerUserData['followers'] ?? 0, // 팔로워의 팔로워 수
        'following': followerUserData['following'] ?? 0, // 팔로워의 팔로잉 수
        'createdAt': followerUserData['createdAt'] ?? FieldValue.serverTimestamp(),
        'followedAt': FieldValue.serverTimestamp(), // 팔로우한 시점
      });

      // users/{followerId}/following/{followingNickname} 생성 (팔로우한 유저의 팔로잉 목록)
      // 문서 ID를 nickname으로 사용 (Firestore 문서 ID에 사용할 수 없는 문자 제거/치환)
      final followingNicknameRaw = followingUserData['nickname'] as String? ?? '';
      if (followingNicknameRaw.isEmpty) {
        throw Exception('팔로우할 유저의 닉네임을 찾을 수 없습니다: $followingId');
      }
      
      final followingNickname = followingNicknameRaw
          .replaceAll('/', '_')
          .replaceAll('?', '_')
          .replaceAll('#', '_')
          .replaceAll('[', '_')
          .replaceAll(']', '_')
          .replaceAll('*', '_')
          .trim();
      
      final followingRef = _firestore
          .collection('users')
          .doc(followerId)
          .collection('following')
          .doc(followingNickname);
      
      batch.set(followingRef, {
        'followingId': followingId,
        'id': followingUserData['id'] ?? followingId, // 팔로우당한 사람의 ID
        'nickname': followingNicknameRaw, // 원본 nickname 저장
        'bio': followingUserData['bio'] ?? '', // 팔로우당한 사람의 소개
        'email': followingUserData['email'] ?? '', // 팔로우당한 사람의 이메일
        'locationPublic': followingUserData['locationPublic'] ?? true,
        'followers': followingUserData['followers'] ?? 0, // 팔로우당한 사람의 팔로워 수
        'following': followingUserData['following'] ?? 0, // 팔로우당한 사람의 팔로잉 수
        'createdAt': followingUserData['createdAt'] ?? FieldValue.serverTimestamp(),
        'followedAt': FieldValue.serverTimestamp(),
      });

      // users/{followingId} 문서의 followers 카운트 증가
      final followingUserRef = _firestore.collection('users').doc(followingId);
      batch.update(followingUserRef, {
        'followers': FieldValue.increment(1),
      });

      // users/{followerId} 문서의 following 카운트 증가
      final followerUserRef = _firestore.collection('users').doc(followerId);
      batch.update(followerUserRef, {
        'following': FieldValue.increment(1),
      });

      await batch.commit();
      debugPrint('팔로우 완료: $followerId가 $followingId를 팔로우');
    } catch (e) {
      debugPrint('팔로우 실패: $e');
      rethrow;
    }
  }

  /// 사용자 A가 사용자 B를 언팔로우
  static Future<void> unfollowUser(String followerId, String followingId) async {
    try {
      final batch = _firestore.batch();

      // users/{followingId}/followers/{followerId} 삭제
      final followersRef = _firestore
          .collection('users')
          .doc(followingId)
          .collection('followers')
          .doc(followerId);
      
      batch.delete(followersRef);

      // users/{followerId}/following/{followingNickname} 또는 {followingId} 삭제
      // 기존 데이터 호환성을 위해 nickname과 userId 둘 다 시도
      final followingUserDoc = await _firestore
          .collection('users')
          .doc(followingId)
          .get();
      
      if (!followingUserDoc.exists) {
        throw Exception('언팔로우할 유저 정보를 찾을 수 없습니다: $followingId');
      }
      
      final followingUserData = followingUserDoc.data()!;
      final followingNicknameRaw = followingUserData['nickname'] as String? ?? '';
      
      if (followingNicknameRaw.isEmpty) {
        throw Exception('언팔로우할 유저의 닉네임을 찾을 수 없습니다: $followingId');
      }
      
      final followingNickname = followingNicknameRaw
          .replaceAll('/', '_')
          .replaceAll('?', '_')
          .replaceAll('#', '_')
          .replaceAll('[', '_')
          .replaceAll(']', '_')
          .replaceAll('*', '_')
          .trim();
      
      // nickname으로 된 문서 삭제 시도
      final followingRefByNickname = _firestore
          .collection('users')
          .doc(followerId)
          .collection('following')
          .doc(followingNickname);
      
      final followingRefByNicknameDoc = await followingRefByNickname.get();
      if (followingRefByNicknameDoc.exists) {
        batch.delete(followingRefByNickname);
        debugPrint('언팔로우: nickname 기반 문서 삭제 ($followingNickname)');
      } else {
        // 기존 userId 기반 문서 삭제 시도 (호환성)
        final followingRefByUserId = _firestore
            .collection('users')
            .doc(followerId)
            .collection('following')
            .doc(followingId);
        
        final followingRefByUserIdDoc = await followingRefByUserId.get();
        if (followingRefByUserIdDoc.exists) {
          batch.delete(followingRefByUserId);
          debugPrint('언팔로우: userId 기반 문서 삭제 ($followingId)');
        } else {
          // 둘 다 없으면 following 컬렉션 전체를 확인하여 followingId 필드로 찾기
          final followingSnapshot = await _firestore
              .collection('users')
              .doc(followerId)
              .collection('following')
              .get();
          
          for (final doc in followingSnapshot.docs) {
            final docData = doc.data();
            final docFollowingId = docData['followingId'] ?? docData['id'] ?? '';
            if (docFollowingId == followingId) {
              batch.delete(doc.reference);
              debugPrint('언팔로우: followingId 필드로 문서 찾아서 삭제 (${doc.id})');
              break;
            }
          }
        }
      }

      // users/{followingId} 문서의 followers 카운트 감소
      final followingUserRef = _firestore.collection('users').doc(followingId);
      batch.update(followingUserRef, {
        'followers': FieldValue.increment(-1),
      });

      // users/{followerId} 문서의 following 카운트 감소
      final followerUserRef = _firestore.collection('users').doc(followerId);
      batch.update(followerUserRef, {
        'following': FieldValue.increment(-1),
      });

      await batch.commit();
      debugPrint('언팔로우 완료: $followerId가 $followingId를 언팔로우');
    } catch (e) {
      debugPrint('언팔로우 실패: $e');
      rethrow;
    }
  }

  /// 특정 사용자의 팔로워 목록 조회
  static Future<List<User>> getFollowers(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('followers')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        
        // createdAt 필드 처리
        String createdAtStr;
        if (data['createdAt'] != null) {
          if (data['createdAt'] is Timestamp) {
            createdAtStr = (data['createdAt'] as Timestamp).toDate().toIso8601String();
          } else {
            createdAtStr = data['createdAt'].toString();
          }
        } else {
          createdAtStr = DateTime.now().toIso8601String();
        }

        return User(
          id: doc.id,
          nickname: data['nickname'] ?? '',
          bio: data['bio'] ?? '',
          email: data['email'] ?? '',
          locationPublic: data['locationPublic'] ?? true,
          followers: (data['followers'] ?? 0) as int,
          following: (data['following'] ?? 0) as int,
          createdAt: createdAtStr,
        );
      }).toList();
    } catch (e) {
      debugPrint('팔로워 목록 조회 실패: $e');
      return [];
    }
  }

  /// 특정 사용자의 팔로잉 목록 조회
  static Future<List<User>> getFollowing(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('following')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        
        // createdAt 필드 처리
        String createdAtStr;
        if (data['createdAt'] != null) {
          if (data['createdAt'] is Timestamp) {
            createdAtStr = (data['createdAt'] as Timestamp).toDate().toIso8601String();
          } else {
            createdAtStr = data['createdAt'].toString();
          }
        } else {
          createdAtStr = DateTime.now().toIso8601String();
        }

        // 문서 ID는 nickname이므로, followingId 필드를 사용
        return User(
          id: data['followingId'] ?? data['id'] ?? doc.id,
          nickname: data['nickname'] ?? '',
          bio: data['bio'] ?? '',
          email: data['email'] ?? '',
          locationPublic: data['locationPublic'] ?? true,
          followers: (data['followers'] ?? 0) as int,
          following: (data['following'] ?? 0) as int,
          createdAt: createdAtStr,
        );
      }).toList();
    } catch (e) {
      debugPrint('팔로잉 목록 조회 실패: $e');
      return [];
    }
  }

  /// 특정 사용자가 다른 사용자를 팔로우하고 있는지 확인
  static Future<bool> isFollowing(String followerId, String followingId) async {
    try {
      // followingId로 사용자 정보를 가져와서 nickname 찾기
      final followingUserDoc = await _firestore
          .collection('users')
          .doc(followingId)
          .get();
      
      if (!followingUserDoc.exists) {
        return false;
      }
      
      final followingUserData = followingUserDoc.data()!;
      final followingNicknameRaw = followingUserData['nickname'] as String? ?? '';
      
      if (followingNicknameRaw.isEmpty) {
        return false;
      }
      
      final followingNickname = followingNicknameRaw
          .replaceAll('/', '_')
          .replaceAll('?', '_')
          .replaceAll('#', '_')
          .replaceAll('[', '_')
          .replaceAll(']', '_')
          .replaceAll('*', '_')
          .trim();
      
      final doc = await _firestore
          .collection('users')
          .doc(followerId)
          .collection('following')
          .doc(followingNickname)
          .get();

      return doc.exists;
    } catch (e) {
      debugPrint('팔로우 확인 실패: $e');
      return false;
    }
  }

  /// 특정 사용자의 팔로워 ID 목록만 조회 (빠른 확인용)
  static Future<Set<String>> getFollowerIds(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('followers')
          .get();

      return snapshot.docs.map((doc) => doc.id).toSet();
    } catch (e) {
      debugPrint('팔로워 ID 목록 조회 실패: $e');
      return {};
    }
  }

  /// 특정 사용자의 팔로잉 ID 목록만 조회 (빠른 확인용)
  static Future<Set<String>> getFollowingIds(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('following')
          .get();

      // 문서 ID는 nickname이므로, followingId 필드를 사용
      return snapshot.docs
          .map((doc) => doc.data()['followingId'] ?? doc.data()['id'] ?? doc.id)
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toSet();
    } catch (e) {
      debugPrint('팔로잉 ID 목록 조회 실패: $e');
      return {};
    }
  }
}
