import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

class LocationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 위치 데이터 컬렉션 (active_walks)
  CollectionReference<Map<String, dynamic>> get _locationsRef => 
      _firestore.collection('active_walks');

  // 내 위치 업데이트 (GeoHash 포함)
  Future<void> updateMyLocation(String userId, double latitude, double longitude) async {
    // GeoFirePoint 생성 (위도, 경도 -> GeoHash)
    final GeoFirePoint geoFirePoint = GeoFirePoint(GeoPoint(latitude, longitude));

    // Firestore에 저장
    await _locationsRef.doc(userId).set({
      'userId': userId,
      'geo': geoFirePoint.data, // 'geohash'와 'geopoint'가 포함됨
      'updatedAt': FieldValue.serverTimestamp(),
      'isWalking': true,
    }, SetOptions(merge: true));
  }

  // 산책 종료 시 내 위치 정보 삭제 (또는 isWalking = false)
  Future<void> stopSharingLocation(String userId) async {
    await _locationsRef.doc(userId).delete();
  }

  // 주변 유저 스트림 (반경 내)
  Stream<List<DocumentSnapshot<Map<String, dynamic>>>> getNearbyUsers(
    double latitude, 
    double longitude, 
    double radiusInKm,
  ) {
    // 검색 중심점
    final GeoFirePoint center = GeoFirePoint(GeoPoint(latitude, longitude));

    // GeoQuery 실행
    return GeoCollectionReference(_locationsRef).subscribeWithin(
      center: center,
      radiusInKm: radiusInKm,
      field: 'geo',
      geopointFrom: (data) => (data['geo'] as Map<String, dynamic>)['geopoint'] as GeoPoint,
      strictMode: true,
    );
  }
}

