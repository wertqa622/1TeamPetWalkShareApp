import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: false, // Android 12+ 알림 오류 방지를 위해 임시로 false로 변경
      notificationChannelId: 'walk_track_channel',
      initialNotificationTitle: '산책 트래킹 작동 중',
      initialNotificationContent: '시간과 경로를 실시간으로 기록하고 있습니다.',
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  WidgetsFlutterBinding.ensureInitialized();

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  double totalDistance = 0.0;
  List<Map<String, double>> pathList = [];
  DateTime startTime = DateTime.now();
  Position? lastRecordedPos;

  // 종료 신호 리스너
  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // [개선]: 1초 타이머를 위치 수신과 무관하게 즉시 가동시켜 5초 딜레이 현상을 방지함
  Timer.periodic(const Duration(seconds: 1), (timer) {
    service.invoke('updateData', {
      "lat": lastRecordedPos?.latitude ?? 0.0,
      "lng": lastRecordedPos?.longitude ?? 0.0,
      "distance": totalDistance,
      "duration": DateTime.now().difference(startTime).inSeconds,
      "path": jsonEncode(pathList),
    });
  });

  // [개선]: 경로 추적(30초 주기)은 비동기로 별도 가동
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    try {
      Position currentPos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high
      );

      if (pathList.isNotEmpty) {
        totalDistance += _calculateDistance(
          pathList.last['lat']!,
          pathList.last['lng']!,
          currentPos.latitude,
          currentPos.longitude,
        );
      }

      lastRecordedPos = currentPos;
      pathList.add({
        'lat': currentPos.latitude,
        'lng': currentPos.longitude
      });

      final String? userId = prefs.getString('current_user_id');
      if (userId != null) {
        FirebaseFirestore.instance.collection('users').doc(userId).update({
          'latitude': currentPos.latitude,
          'longitude': currentPos.longitude,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      prefs.setDouble('temp_distance', totalDistance);
      prefs.setString('temp_path', jsonEncode(pathList));
    } catch (e) {
      debugPrint("GPS 트래킹 에러: $e");
    }
  });
}

double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  double p = 0.017453292519943295;
  double a = 0.5 - math.cos((lat2 - lat1) * p) / 2 +
      math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
  return 12742 * math.asin(math.sqrt(a));
}