import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../firebase_options.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  final notificationsPlugin = FlutterLocalNotificationsPlugin();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'walk_channel_v7', '산책 기록 서비스',
    importance: Importance.low,
  );

  await notificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'walk_channel_v7',
      initialNotificationTitle: '산책 준비 중',
      initialNotificationContent: 'GPS를 연결하고 있습니다...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: (ServiceInstance service) async {
        onStart(service);
        return true;
      },
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();
  if (service is AndroidServiceInstance) service.setAsForegroundService();

  try { await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); } catch (e) {}

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  // 저장된 유저 ID 가져오기
  final String? userId = prefs.getString('current_user_id');

  double totalDistance = 0.0;
  List<Map<String, double>> pathList = [];
  DateTime startTime = DateTime.now();

  // 서비스 종료 리스너 (종료 시 알림 확실히 제거 및 상태 'off' 보장)
  service.on('stopService').listen((event) async {
    if (userId != null) {
      // [로직 추가]: 백그라운드 서비스 정지 시 Firestore 상태 업데이트
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'walkingStatus': 'off'});
    }
    await prefs.setBool('is_walking', false);
    service.stopSelf();
  });

  service.invoke('ready');

  Timer.periodic(const Duration(seconds: 30), (timer) async {
    try {
      Position pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));

      if (pathList.isNotEmpty) {
        double dist = Geolocator.distanceBetween(
            pathList.last['lat']!, pathList.last['lng']!, pos.latitude, pos.longitude);
        totalDistance += (dist / 1000);
      }
      pathList.add({'lat': pos.latitude, 'lng': pos.longitude});

      // [핵심 수정 유지]: 타입 에러 방지용 double/int 명시적 변환
      service.invoke('updateData', {
        "lat": pos.latitude.toDouble(),
        "lng": pos.longitude.toDouble(),
        "distance": totalDistance.toDouble(),
        "path": jsonEncode(pathList),
        "duration": DateTime.now().difference(startTime).inSeconds.toInt(),
      });

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "반려동물과 산책 중입니다 🐕",
          content: "현재 거리: ${totalDistance.toStringAsFixed(2)}km 기록 중",
        );
      }
    } catch (e) {}
  });
}