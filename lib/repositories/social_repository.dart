import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/social_user.dart';

class SocialRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Firestore 컬렉션 참조
  CollectionReference<Map<String, dynamic>> get _usersRef => 
      _firestore.collection('users');

  // 나를 팔로우하는 사람들 (Followers) 가져오기
  Future<List<SocialUser>> getFollowers(String userId) async {
    try {
      // 내 followers 서브컬렉션 조회
      final snapshot = await _usersRef
          .doc(userId)
          .collection('followers')
          .get();

      // 내가 팔로우하고 있는 목록도 가져와야 '맞팔' 여부를 알 수 있음
      // (최적화를 위해 ID 목록만 가져옴)
      final myFollowingSnapshot = await _usersRef
          .doc(userId)
          .collection('following')
          .get();
      
      final myFollowingIds = myFollowingSnapshot.docs.map((doc) => doc.id).toSet();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        // Firestore에 저장된 데이터를 User 객체로 변환
        // 저장 시 User.toJson()을 사용했다고 가정
        final user = User.fromJson(data);
        
        return SocialUser(
          user: user,
          isFollowing: myFollowingIds.contains(user.id),
        );
      }).toList();
    } catch (e) {
      // 에러 처리 또는 빈 리스트 반환
      return [];
    }
  }

  // 내가 팔로우하는 사람들 (Following) 가져오기
  Future<List<SocialUser>> getFollowing(String userId) async {
    try {
      final snapshot = await _usersRef
          .doc(userId)
          .collection('following')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final user = User.fromJson(data);
        
        // 팔로잉 목록에 있다는 것은 이미 내가 팔로우하고 있다는 뜻
        return SocialUser(
          user: user,
          isFollowing: true,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // 유저 검색
  Future<List<SocialUser>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    try {
      // 닉네임으로 검색 (단순 문자열 매칭은 Firestore에서 제한적이므로,
      // 실제로는 Algolia 같은 검색 엔진을 쓰거나, 
      // 여기서는 정확한 일치 또는 범위 쿼리(startAt/endAt)를 사용)
      
      // 편의상 쿼리와 유사한 닉네임을 찾기 위해 범위 쿼리 사용
      // (대소문자 구분 없이 검색하려면 별도 필드 필요하지만 여기서는 단순화)
      final snapshot = await _usersRef
          .where('nickname', isGreaterThanOrEqualTo: query)
          .where('nickname', isLessThan: query + 'z')
          .get();

      // 내 팔로잉 목록 가져오기 (팔로우 여부 확인용)
      // 실제 앱에서는 로그인한 유저 ID를 주입받거나 Provider로 관리해야 함
      // 여기서는 검색 결과를 반환할 때 ViewModel에서 처리하거나, 
      // 현재 로직상으로는 검색 결과의 isFollowing은 false로 두고, 
      // ViewModel에서 내 팔로잉 목록과 비교하여 업데이트하는 것이 좋음.
      // 하지만 Repository 안에서 처리하려면 현재 유저 ID가 필요함.
      // searchUsers 호출 시 myUserId를 인자로 받는 것이 좋으나, 
      // 현재 인터페이스 호환성을 위해 우선 검색 결과만 반환.
      
      // *참고: searchUsers 호출 시 myUserId를 넘겨주는 구조로 ViewModel을 수정해야 완벽함.
      // 임시로 User 객체만 반환하고 isFollowing은 기본 false로 둠.
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final user = User.fromJson(data);
        return SocialUser(user: user, isFollowing: false);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // 팔로우 하기
  Future<void> followUser(String myUserId, String targetUserId) async {
    // 트랜잭션으로 안전하게 처리
    await _firestore.runTransaction((transaction) async {
      final myUserRef = _usersRef.doc(myUserId);
      final targetUserRef = _usersRef.doc(targetUserId);

      final myUserDoc = await transaction.get(myUserRef);
      final targetUserDoc = await transaction.get(targetUserRef);

      // 내 문서가 없으면 생성 (최초 실행 시 등)
      if (!myUserDoc.exists) {
        // 내 정보가 DB에 없어서 발생하는 문제일 수 있음
        // StorageService에서 로컬 데이터를 가져와서 DB에 저장해야 함
        // 여기서는 임시로 에러를 던지지만, 실제로는 UserViewModel에서 
        // 앱 시작 시 syncUserToFirestore 같은 로직이 필요함.
        throw Exception('My user document not found in Firestore. Please restart app to sync.');
      }
      
      if (!targetUserDoc.exists) {
        throw Exception('Target user not found');
      }

      final myUserData = myUserDoc.data()!;
      final targetUserData = targetUserDoc.data()!;

      // 2. 내 팔로잉 목록에 상대방 추가
      final myFollowingRef = myUserRef.collection('following').doc(targetUserId);
      transaction.set(myFollowingRef, targetUserData);

      // 3. 상대방 팔로워 목록에 나 추가
      final targetFollowerRef = targetUserRef.collection('followers').doc(myUserId);
      transaction.set(targetFollowerRef, myUserData);

      // 4. 카운트 업데이트
      transaction.update(myUserRef, {
        'following': FieldValue.increment(1)
      });
      transaction.update(targetUserRef, {
        'followers': FieldValue.increment(1)
      });
    });
  }

  // 언팔로우 하기
  Future<void> unfollowUser(String myUserId, String targetUserId) async {
    await _firestore.runTransaction((transaction) async {
      // 1. 내 팔로잉 목록에서 제거
      final myFollowingRef = _usersRef.doc(myUserId).collection('following').doc(targetUserId);
      transaction.delete(myFollowingRef);

      // 2. 상대방 팔로워 목록에서 제거
      final targetFollowerRef = _usersRef.doc(targetUserId).collection('followers').doc(myUserId);
      transaction.delete(targetFollowerRef);

      // 3. 카운트 업데이트
      transaction.update(_usersRef.doc(myUserId), {
        'following': FieldValue.increment(-1)
      });
      transaction.update(_usersRef.doc(targetUserId), {
        'followers': FieldValue.increment(-1)
      });
    });
  }

  // 팔로워 삭제 (상대방이 나를 팔로우한 것을 끊음)
  Future<void> removeFollower(String myUserId, String targetUserId) async {
    await _firestore.runTransaction((transaction) async {
      // 1. 내 팔로워 목록에서 상대방 제거
      final myFollowerRef = _usersRef.doc(myUserId).collection('followers').doc(targetUserId);
      transaction.delete(myFollowerRef);

      // 2. 상대방 팔로잉 목록에서 나 제거
      final targetFollowingRef = _usersRef.doc(targetUserId).collection('following').doc(myUserId);
      transaction.delete(targetFollowingRef);

      // 3. 카운트 업데이트
      transaction.update(_usersRef.doc(myUserId), {
        'followers': FieldValue.increment(-1)
      });
      transaction.update(_usersRef.doc(targetUserId), {
        'following': FieldValue.increment(-1)
      });
    });
  }

  // 차단 하기 (구현 예시)
  Future<void> blockUser(String myUserId, String targetUserId) async {
    // 차단 로직: 팔로우/팔로잉 끊기 + 차단 목록 추가
    await unfollowUser(myUserId, targetUserId); // 내가 팔로우 중이면 끊기
    await removeFollower(myUserId, targetUserId); // 나를 팔로우 중이면 끊기
    
    // 차단 컬렉션에 추가
    await _usersRef.doc(myUserId).collection('blocked_users').doc(targetUserId).set({
      'blockedAt': FieldValue.serverTimestamp(),
    });
  }

  // 차단 여부 확인 (targetUserId가 myUserId를 차단했는지)
  Future<bool> isBlockedBy(String targetUserId, String myUserId) async {
    try {
      final doc = await _usersRef
          .doc(targetUserId)
          .collection('blocked_users')
          .doc(myUserId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }
}
