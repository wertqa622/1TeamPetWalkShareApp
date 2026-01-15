import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore Timestamp를 ISO8601 문자열로 변환하는 유틸리티 클래스
class TimestampConverter {
  /// Firestore Timestamp 또는 문자열을 ISO8601 문자열로 변환
  /// 
  /// [timestamp] Firestore Timestamp, String, 또는 null
  /// 
  /// Returns ISO8601 형식의 문자열 (변환 실패 시 현재 시간 반환)
  static String toIso8601String(dynamic timestamp) {
    if (timestamp == null) {
      return DateTime.now().toIso8601String();
    }
    
    if (timestamp is Timestamp) {
      return timestamp.toDate().toIso8601String();
    }
    
    if (timestamp is String) {
      return timestamp;
    }
    
    // 기타 타입은 문자열로 변환
    return timestamp.toString();
  }
}
