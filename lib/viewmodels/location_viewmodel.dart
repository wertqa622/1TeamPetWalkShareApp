import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../repositories/location_repository.dart';

class LocationViewModel extends ChangeNotifier {
  final LocationRepository _repository;
  
  // 주변 유저 위치 목록
  List<Map<String, dynamic>> _nearbyUsers = [];
  StreamSubscription? _nearbyUsersSubscription;
  
  bool _isSharing = false;

  LocationViewModel({LocationRepository? repository})
      : _repository = repository ?? LocationRepository();

  List<Map<String, dynamic>> get nearbyUsers => _nearbyUsers;
  bool get isSharing => _isSharing;

  // 내 위치 공유 시작 (주기적 업데이트는 BackgroundService에서 호출한다고 가정하거나 여기서 Timer 사용)
  // 여기서는 단순히 상태 플래그 관리 및 최초 업데이트 예시
  Future<void> startSharing(String userId, double lat, double lng) async {
    _isSharing = true;
    notifyListeners();
    await _repository.updateMyLocation(userId, lat, lng);
  }

  // 위치 업데이트 (주기적으로 호출됨)
  Future<void> updateLocation(String userId, double lat, double lng) async {
    if (!_isSharing) return;
    await _repository.updateMyLocation(userId, lat, lng);
    
    // 내 위치가 업데이트될 때마다 주변 유저 검색 쿼리 갱신이 필요할 수 있음
    // (GeoQuery는 중심점이 바뀌면 다시 구독해야 함)
    // 여기서는 간단히 하기 위해 '주변 탐색 시작'을 별도로 둠
  }

  // 위치 공유 중단
  Future<void> stopSharing(String userId) async {
    _isSharing = false;
    notifyListeners();
    await _repository.stopSharingLocation(userId);
    _stopListeningNearbyUsers();
  }

  // 주변 유저 탐색 시작 (지도 화면 진입 시)
  void startListeningNearbyUsers(double centerLat, double centerLng) {
    _stopListeningNearbyUsers(); // 기존 구독 취소

    // 1km 반경 탐색
    final stream = _repository.getNearbyUsers(centerLat, centerLng, 1.0);
    
    _nearbyUsersSubscription = stream.listen((List<DocumentSnapshot<Map<String, dynamic>>> docs) {
      _nearbyUsers = docs.map((doc) {
        final data = doc.data()!;
        // 필요한 데이터만 추출
        return {
          'id': doc.id,
          'latitude': (data['geo']['geopoint'] as GeoPoint).latitude,
          'longitude': (data['geo']['geopoint'] as GeoPoint).longitude,
          'userId': data['userId'],
        };
      }).toList();
      notifyListeners();
    });
  }

  void _stopListeningNearbyUsers() {
    _nearbyUsersSubscription?.cancel();
    _nearbyUsersSubscription = null;
  }

  @override
  void dispose() {
    _stopListeningNearbyUsers();
    super.dispose();
  }
}

