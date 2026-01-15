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

// 알림 플러그인 전역 인스턴스
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  // 0. 알림 플러그인 초기화
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      debugPrint('알림 클릭: ${response.payload}');
    },
  );

  // 1. 산책 기록용 채널 (조용함)
  const AndroidNotificationChannel trackingChannel = AndroidNotificationChannel(
    'walk_channel_v9',
    '실시간 산책 트래킹',
    description: '산책 중 위치를 추적합니다.',
    importance: Importance.low,
  );

  // 2. 주변 이웃 알림용 채널 (진동/소리 강화)
  const AndroidNotificationChannel alertChannel = AndroidNotificationChannel(
    'nearby_alert_channel_v2',
    '주변 산책 친구 알림',
    description: '근처에 산책 중인 이웃이 있으면 알려줍니다.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(trackingChannel);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(alertChannel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'walk_channel_v9',
      initialNotificationTitle: '반려동물 산책 다이어리',
      initialNotificationContent: '산책 서비스를 준비중입니다...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(autoStart: false, onForeground: onStart),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  if (service is AndroidServiceInstance) service.setAsForegroundService();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  double totalDistance = 0.0;
  List<Map<String, double>> pathList = [];
  DateTime startTime = DateTime.now();
  bool isWalkingActive = false;

  Map<String, DateTime> alertCooldowns = {};

  // UI로부터 신호 수신
  service.on('setWalkingStatus').listen((event) {
    if (event != null) {
      isWalkingActive = event['isWalking'] ?? false;
      if (isWalkingActive) {
        // [산책 시작]
        startTime = DateTime.now();
        totalDistance = 0.0;
        pathList = [];
        alertCooldowns.clear();

        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "산책 중 🐕",
            content: "즐거운 산책 되세요!",
          );
        }
      } else {
        // [산책 종료]
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "산책 종료",
            content: "수고하셨습니다! (대기 중)", // 문구 변경
          );
        }
        // ❌ [중요 수정] 여기서 service.stopSelf()를 호출하면 안 됩니다!
        // 서비스를 죽이면 다음에 시작 버튼을 눌러도 반응하지 않습니다.
        // service.stopSelf();  <-- 삭제됨
      }
    }
  });

  // 앱이 완전히 종료될 때 호출되는 리스너 (여기서만 죽입니다)
  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  Timer.periodic(const Duration(seconds: 10), (timer) async {
    if (!isWalkingActive) return; // 산책 중이 아니면 로직 수행 안 함 (배터리 절약)

    try {
      final String? myUserId = prefs.getString('current_user_id');

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

      if (myUserId != null) {
        await FirebaseFirestore.instance.collection('users').doc(myUserId).update({
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'walkingStatus': 'on',
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        await _checkProximityAndNotify(
            myUserId,
            pos.latitude,
            pos.longitude,
            alertCooldowns
        );
      }

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "산책 중 🐕",
          content: "거리: ${totalDistance.toStringAsFixed(2)}km | 시간: ${DateTime.now().difference(startTime).inMinutes}분",
        );
      }

      service.invoke('updateData', {
        "lat": pos.latitude.toDouble(),
        "lng": pos.longitude.toDouble(),
        "distance": totalDistance.toDouble(),
        "path": jsonEncode(pathList),
        "duration": DateTime.now().difference(startTime).inSeconds.toInt(),
      });

    } catch (e) {
      debugPrint("백그라운드 에러: $e");
    }
  });
}

// [기존 유지] 주변 유저 체크 및 알림 로직
Future<void> _checkProximityAndNotify(
    String myId,
    double myLat,
    double myLng,
    Map<String, DateTime> cooldowns
    ) async {

  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('walkingStatus', isEqualTo: 'on')
        .get();

    for (var doc in snapshot.docs) {
      if (doc.id == myId) continue;

      final data = doc.data();
      if (data['latitude'] == null || data['longitude'] == null) continue;

      double otherLat = (data['latitude'] as num).toDouble();
      double otherLng = (data['longitude'] as num).toDouble();

      double distanceMeters = Geolocator.distanceBetween(
          myLat, myLng, otherLat, otherLng
      );

      if (distanceMeters <= 1000) {
        String nickname = data['nickname'] ?? '이웃 산책러';

        bool canNotify = true;
        if (cooldowns.containsKey(doc.id)) {
          final lastAlert = cooldowns[doc.id]!;
          if (DateTime.now().difference(lastAlert).inMinutes < 5) {
            canNotify = false;
          }
        }

        if (canNotify) {
          await _showProximityNotification(doc.id.hashCode, nickname, distanceMeters.toInt());
          cooldowns[doc.id] = DateTime.now();
        }
      }
    }
  } catch (e) {
    debugPrint("주변 유저 체크 실패: $e");
  }
}

// [기존 유지] 알림 표시 함수
Future<void> _showProximityNotification(int id, String nickname, int distance) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'nearby_alert_channel_v2',
    '주변 산책 친구 알림',
    channelDescription: '근처에 산책 중인 이웃이 있으면 알려줍니다.',
    importance: Importance.max,
    priority: Priority.max,
    showWhen: true,
    enableVibration: true,
    color: Colors.blue,
    icon: '@mipmap/ic_launcher',
    ticker: '근처에 산책 친구가 있어요!',
    category: AndroidNotificationCategory.social,
    fullScreenIntent: true,
  );

  const NotificationDetails details = NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    id,
    '🐶 근처에 산책 친구 발견!',
    '$nickname님이 약 ${distance}m 근처에서 산책 중입니다.',
    details,
  );
}