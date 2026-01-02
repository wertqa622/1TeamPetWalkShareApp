import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false, // 산책 시작 버튼 누를 때만 실행
      isForegroundMode: true,
      notificationChannelId: 'walk_track_channel',
      initialNotificationTitle: '산책 기록 중',
      initialNotificationContent: '반려동물과 즐거운 산책을 기록하고 있어요!',
    ),
    iosConfiguration: IosConfiguration(),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // 위치 스트림 설정
  Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5)
  ).listen((Position position) {
    // 1. UI로 좌표 전송 (지도에 선 그리기용)
    service.invoke('updateLocation', {
      "lat": position.latitude,
      "lng": position.longitude,
    });

    // 2. 서버에 내 위치 업데이트 (FR-104용)
    // updateMyLocationToFirestore(position);
  });
}