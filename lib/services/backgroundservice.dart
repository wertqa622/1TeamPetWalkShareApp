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

const String walkNotificationChannelId = 'walk_secure_channel_v6';
const int walkNotificationId = 999;

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    walkNotificationChannelId,
    '반려동물 산책 서비스',
    importance: Importance.low,
  );

  await notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: walkNotificationChannelId,
      initialNotificationTitle: '산책 준비 중',
      initialNotificationContent: 'GPS 연결 확인 중...',
      foregroundServiceNotificationId: walkNotificationId,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      // [수정]: FutureOr<bool> 타입을 맞추기 위해 async와 return true 추가
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
  double totalDistance = 0.0;
  List<Map<String, double>> pathList = [];
  DateTime startTime = DateTime.now();

  Timer.periodic(const Duration(seconds: 30), (timer) async {
    try {
      Position currentPos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));

      if (pathList.isNotEmpty) {
        double dist = Geolocator.distanceBetween(pathList.last['lat']!, pathList.last['lng']!, currentPos.latitude, currentPos.longitude);
        totalDistance += (dist / 1000);
      }
      pathList.add({'lat': currentPos.latitude, 'lng': currentPos.longitude});

      // [수정]: invoke는 void를 반환하므로 await 제거
      service.invoke('updateData', {
        "lat": currentPos.latitude, "lng": currentPos.longitude,
        "distance": totalDistance, "path": jsonEncode(pathList),
        "duration": DateTime.now().difference(startTime).inSeconds,
      });

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(title: "산책 중 🐕", content: "거리: ${totalDistance.toStringAsFixed(2)}km");
      }
    } catch (e) { debugPrint("에러: $e"); }
  });
}