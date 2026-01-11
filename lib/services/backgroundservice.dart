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
    'walk_channel_v9', '실시간 산책 트래킹',
    importance: Importance.low,
  );

  await notificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true, // 앱 구동 시 즉시 알림 생성
      isForegroundMode: true,
      notificationChannelId: 'walk_channel_v9',
      initialNotificationTitle: '반려동물 산책 다이어리',
      initialNotificationContent: '산책을 시작할 준비가 되었습니다.',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(autoStart: true, onForeground: onStart),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  if (service is AndroidServiceInstance) service.setAsForegroundService();

  try { await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); } catch (e) {}

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  double totalDistance = 0.0;
  List<Map<String, double>> pathList = [];
  DateTime startTime = DateTime.now();
  bool isWalkingActive = false;

  // UI로부터 산책 상태를 전달받음
  service.on('setWalkingStatus').listen((event) {
    if (event != null) {
      isWalkingActive = event['isWalking'] ?? false;
      if (isWalkingActive) {
        startTime = DateTime.now();
        totalDistance = 0.0;
        pathList = [];
      } else {
        // 산책 종료 시 알림 초기화
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "반려동물 산책 다이어리",
            content: "산책을 시작할 준비가 되었습니다.",
          );
        }
      }
    }
  });

  service.on('stopService').listen((event) async {
    service.stopSelf();
  });

  Timer.periodic(const Duration(seconds: 10), (timer) async {
    if (!isWalkingActive) return;

    try {
      final String? userId = prefs.getString('current_user_id');
      Position pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)
      );

      if (pathList.isNotEmpty) {
        double dist = Geolocator.distanceBetween(
            pathList.last['lat']!, pathList.last['lng']!, pos.latitude, pos.longitude
        );
        if (dist > 2) totalDistance += (dist / 1000);
      }
      pathList.add({'lat': pos.latitude, 'lng': pos.longitude});

      if (userId != null) {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'latitude': pos.latitude, 'longitude': pos.longitude,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "산책 중 🐕",
          content: "거리: ${totalDistance.toStringAsFixed(2)}km | 시간: ${DateTime.now().difference(startTime).inMinutes}분",
        );
      }

      service.invoke('updateData', {
        "lat": pos.latitude.toDouble(), "lng": pos.longitude.toDouble(),
        "distance": totalDistance.toDouble(), "path": jsonEncode(pathList),
        "duration": DateTime.now().difference(startTime).inSeconds.toInt(),
      });
    } catch (e) {}
  });
}