import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import 'timestamp_converter.dart';

/// Firestore 데이터를 User 객체로 변환하는 유틸리티 클래스
class UserConverter {
  /// Firestore 문서 데이터를 User 객체로 변환
  /// 
  /// [data] Firestore 문서 데이터 (Map)
  /// [userId] 사용자 ID (문서 ID 또는 데이터의 id 필드)
  /// 
  /// Returns User 객체
  static User fromFirestore(Map<String, dynamic> data, String userId) {
    return User(
      id: data['id'] as String? ?? userId,
      email: data['email'] as String? ?? '',
      nickname: data['nickname'] as String? ?? '',
      bio: data['bio'] as String? ?? '',
      locationPublic: data['locationPublic'] as bool? ?? true,
      followers: (data['followers'] ?? 0) as int,
      following: (data['following'] ?? 0) as int,
      createdAt: TimestampConverter.toIso8601String(data['createdAt']),
      walkingStatus: data['walkingStatus'] as String? ?? 'off',
    );
  }

  /// Firestore 문서 스냅샷을 User 객체로 변환
  /// 
  /// [doc] Firestore 문서 스냅샷
  /// 
  /// Returns User 객체
  static User fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return fromFirestore(data, doc.id);
  }
}
