import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/walk.dart';

/// 산책 기록 관련 서비스 클래스
class WalkService {
  /// 차단된 사용자의 산책 기록을 필터링합니다.
  /// 사용자 1이 사용자 2를 차단하면, 사용자 2는 사용자 1의 기록을 볼 수 없습니다.
  /// 조회자의 d_user 컬렉션을 확인하여 차단당한 사용자들의 기록을 필터링합니다.
  /// 
  /// [walkDocs] 조회된 산책 기록 문서 목록
  /// [viewerUserId] 기록을 조회하는 사용자 ID
  /// 
  /// 반환: 필터링된 산책 기록 목록
  static Future<List<Walk>> filterBlockedUsersWalks(
    List<QueryDocumentSnapshot> walkDocs,
    String viewerUserId,
  ) async {
    if (walkDocs.isEmpty) return [];

    // 조회자의 d_user 컬렉션에서 차단당한 사용자 목록 가져오기
    List<String> blockedByNicknames = [];
    try {
      final blockedBySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(viewerUserId)
          .collection('d_user')
          .get();
      
      // 서브컬렉션의 모든 문서 ID(nickname)를 차단당한 목록으로 수집 (.init 제외)
      blockedByNicknames = blockedBySnapshot.docs
          .where((doc) => doc.id != '.init')
          .map((doc) => doc.id) // 문서 ID가 차단한 사용자의 nickname (정규화된 버전)
          .toList();
    } catch (e) {
      debugPrint("차단당한 목록 조회 실패 (userId: $viewerUserId): $e");
      // 에러 발생 시 모든 기록 반환
      return walkDocs.map((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return null;
        final walkData = Map<String, dynamic>.from(data);
        walkData['id'] = doc.id;
        return Walk.fromJson(walkData);
      }).where((walk) => walk != null).cast<Walk>().toList();
    }

    // 차단당한 사용자가 없으면 모든 기록 반환
    if (blockedByNicknames.isEmpty) {
      return walkDocs.map((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return null;
        final walkData = Map<String, dynamic>.from(data);
        walkData['id'] = doc.id;
        return Walk.fromJson(walkData);
      }).where((walk) => walk != null).cast<Walk>().toList();
    }

    // 모든 기록 작성자의 userId와 nickname 매핑 생성
    final Map<String, String> userIdToNicknameMap = {};
    final Set<String> userIds = {};
    
    for (final doc in walkDocs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data != null && data['userId'] != null) {
        userIds.add(data['userId'] as String);
      }
    }

    // 각 기록 작성자의 nickname 가져오기
    for (final userId in userIds) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final nicknameRaw = userData['nickname'] as String? ?? '';
          
          if (nicknameRaw.isNotEmpty) {
            // Firestore 문서 ID에 사용할 수 없는 문자 제거/치환
            final normalizedNickname = nicknameRaw
                .replaceAll('/', '_')
                .replaceAll('?', '_')
                .replaceAll('#', '_')
                .replaceAll('[', '_')
                .replaceAll(']', '_')
                .replaceAll('*', '_')
                .trim();
            
            userIdToNicknameMap[userId] = normalizedNickname;
          }
        }
      } catch (e) {
        debugPrint("유저 정보 조회 실패 (userId: $userId): $e");
      }
    }

    // 조회자의 d_user에 있는 사용자들의 기록 필터링
    // 기록 작성자의 nickname이 조회자의 d_user에 있으면 필터링
    final filteredWalks = <Walk>[];
    for (final doc in walkDocs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;
      
      final walkUserId = data['userId'] as String?;
      if (walkUserId == null) continue;
      
      // 기록 작성자의 정규화된 nickname 가져오기
      final writerNickname = userIdToNicknameMap[walkUserId];
      
      // 기록 작성자의 nickname이 조회자의 d_user에 없으면 포함
      if (writerNickname == null || !blockedByNicknames.contains(writerNickname)) {
        final walkData = Map<String, dynamic>.from(data);
        walkData['id'] = doc.id;
        filteredWalks.add(Walk.fromJson(walkData));
      }
    }

    return filteredWalks;
  }
}
