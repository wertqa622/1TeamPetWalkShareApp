import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

import '../services/firebase_storage_service.dart';
import '../services/marker_isolate.dart';

class WalkTrackingTab extends StatefulWidget {
  final String userId;
  const WalkTrackingTab({super.key, required this.userId});

  @override
  State<WalkTrackingTab> createState() => _WalkTrackingTabState();
}

class _WalkTrackingTabState extends State<WalkTrackingTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isWalking = false;
  double _curDistance = 0.0;
  int _curDuration = 0;
  List<LatLng> _curPath = [];
  LatLng? _curLatLng;
  DateTime? _actualStartTime;

  GoogleMapController? _mapController;
  Timer? _uiTimer;
  XFile? _pickedImage;

  Set<Marker> _markers = {};
  BitmapDescriptor? _myPetIcon;
  static final Map<String, BitmapDescriptor> _globalMarkerCache = {};
  static final Map<String, Future<BitmapDescriptor>> _iconFutureCache = {};

  StreamSubscription? _nearbyUsersSub;
  StreamSubscription? _bgUpdateSub;
  bool _isPermissionReady = false;

  @override
  void initState() {
    super.initState();
    _initializeWalkSystem();
  }

  Future<void> _initializeWalkSystem() async {
    await _loadLastWalkLocation();
    await _checkInitialPermission();
    await _syncServiceAndUI();
    _loadMyPetMarker();
    if (_curLatLng == null) _fetchCurrentLocationOnce();
  }

  Future<void> _loadLastWalkLocation() async {
    try {
      final walkSnap = await FirebaseFirestore.instance
          .collection('walks').where('userId', isEqualTo: widget.userId)
          .orderBy('startTime', descending: true).limit(1).get();
      if (walkSnap.docs.isNotEmpty) {
        final data = walkSnap.docs.first.data();
        final String? routeJson = data['route'];
        if (routeJson != null) {
          final List<dynamic> routeList = jsonDecode(routeJson);
          if (routeList.isNotEmpty) {
            setState(() =>
            _curLatLng = LatLng(routeList.last['lat'], routeList.last['lng']));
          }
        }
      }
    } catch (e) {}
  }

  Future<void> _startWalk() async {
    // 기존의 Permission.request() 코드들을 아래 한 줄로 대체하거나 생략 가능합니다.
    final status = await Permission.location.status;

    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('설정에서 위치 권한을 허용해주세요.'))
        );
      }
      return;
    }

    // 1. UI 선반영
    setState(() {
      _isWalking = true;
      _curDuration = 0;
      _curDistance = 0.0;
      _curPath = [];
    });

    // 2. [튕김 방지 핵심] OS 권한 승인 전파를 위한 800ms 대기
    await Future.delayed(const Duration(milliseconds: 800));

    // 3. 지도 레이어 활성화
    if (mounted) setState(() => _isPermissionReady = true);

    final service = FlutterBackgroundService();
    _actualStartTime = DateTime.now();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_walking', true);
    await prefs.setString(
        'walk_start_time', _actualStartTime!.toIso8601String());
    await prefs.setString('current_user_id', widget.userId);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .update({'walkingStatus': 'on'});

    // 서비스에 산책 시작 신호 전달 (알림 내용 변경됨)
    service.invoke('setWalkingStatus', {'isWalking': true});

    _startTimer();
    _listenToBackground();
    _startNearbyUsersListener();

    Geolocator.getCurrentPosition(locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high))
        .then((pos) {
      if (mounted) {
        _curLatLng = LatLng(pos.latitude, pos.longitude);
        _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(_curLatLng!, 17));
      }
    });
  }

  void _stopWalk() {
    _uiTimer?.cancel();

    FlutterBackgroundService().invoke('setWalkingStatus', {'isWalking': false});

    if (_curDuration < 60) {
      showDialog(context: context, builder: (ctx) =>
          AlertDialog(
            title: const Text('산책 종료 확인'),
            content: const Text('산책 시간이 1분 미만입니다. 취소할까요?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx),
                  child: const Text('계속하기')),
              TextButton(onPressed: () async {
                Navigator.pop(ctx);
                await _resetToIdle();
              }, child: const Text('취소', style: TextStyle(color: Colors.red)))
            ],
          ));
    } else {
      _showSaveModal();
    }
  }

  Future<void> _resetToIdle() async {
    _uiTimer?.cancel();
    _nearbyUsersSub?.cancel();
    _bgUpdateSub?.cancel();

    // 서비스는 끄지 않고 '상태'만 종료로 변경 (알림을 '준비중'으로 되돌림)
    FlutterBackgroundService().invoke('setWalkingStatus', {'isWalking': false});

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .update({'walkingStatus': 'off'});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_walking', false);

    if (mounted) setState(() {
      _isWalking = false;
      _curPath = [];
      _curDistance = 0.0;
      _pickedImage = null;
      _markers = {};
      _isPermissionReady = false;
    });
  }

  void _startTimer() {
    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (t) =>
    mounted && _isWalking
        ? setState(() => _curDuration++)
        : null);
  }

  String _formatTime(int totalSeconds) {
    return "${(totalSeconds ~/ 60).toString().padLeft(2, '0')}:${(totalSeconds %
        60).toString().padLeft(2, '0')}";
  }

  Widget _statBox(String label, String value) {
    return Column(children: [
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
      Text(value, style: const TextStyle(
          fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
    ]);
  }

  void _listenToBackground() {
    _bgUpdateSub?.cancel();
    _bgUpdateSub = FlutterBackgroundService().on('updateData').listen((event) {
      if (event != null && mounted && _isWalking) {
        final double newLat = (event['lat'] as num).toDouble();
        final double newLng = (event['lng'] as num).toDouble();
        final LatLng newLatLng = LatLng(newLat, newLng);

        // 1. 거리가 멀면 카메라 이동
        _mapController?.animateCamera(CameraUpdate.newLatLng(newLatLng));

        // 2. 마커 이동 애니메이션 실행 (부드러운 이동 핵심)
        _animateMarkerMove(_curLatLng ?? newLatLng, newLatLng);

        setState(() {
          _curDistance = (event['distance'] as num?)?.toDouble() ?? 0.0;
          _curDuration = (event['duration'] as num?)?.toInt() ?? _curDuration;
          if (event['path'] != null) {
            _curPath = (jsonDecode(event['path']) as List)
                .map((p) => LatLng(p['lat'], p['lng']))
                .toList();
          }
        });
      }
    });
  }

  void _startNearbyUsersListener() {
    if (!_isWalking) return;
    _nearbyUsersSub?.cancel();
    _nearbyUsersSub = FirebaseFirestore.instance.collection('users').where(
        'walkingStatus', isEqualTo: 'on').snapshots().listen((snapshot) async {
      Set<Marker> newMarkers = {};
      if (_curLatLng != null) {
        newMarkers.add(Marker(markerId: const MarkerId('me'),
            position: _curLatLng!,
            icon: _myPetIcon ?? BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure),
            anchor: const Offset(0.5, 0.5),
            zIndex: 2));
      }
      for (var doc in snapshot.docs) {
        if (doc.id == widget.userId) continue;
        final data = doc.data();
        if (data['latitude'] == null) continue;
        double dist = Geolocator.distanceBetween(
            _curLatLng?.latitude ?? 0, _curLatLng?.longitude ?? 0,
            (data['latitude'] as num).toDouble(),
            (data['longitude'] as num).toDouble());
        if (dist <= 1000) {
          final petSnap = await FirebaseFirestore.instance
              .collection('pets')
              .where('userId', isEqualTo: doc.id)
              .where('isRepresentative', isEqualTo: true)
              .limit(1)
              .get();
          BitmapDescriptor icon = BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure);
          if (petSnap.docs.isNotEmpty) {
            String? pUrl = petSnap.docs.first.data()['imageUrl'];
            if (pUrl != null) icon = await _getCircularMarker(pUrl);
          }
          newMarkers.add(Marker(markerId: MarkerId(doc.id),
              position: LatLng((data['latitude'] as num).toDouble(),
                  (data['longitude'] as num).toDouble()),
              icon: icon,
              anchor: const Offset(0.5, 0.5),
              infoWindow: InfoWindow(title: data['nickname'])));
        }
      }
      if (mounted) setState(() => _markers = newMarkers);
    });
  }

  void _showSaveModal() {
    String mood = '😊';
    final memoController = TextEditingController();
    showModalBottomSheet(
        context: context, isScrollControlled: true, builder: (ctx) =>
        StatefulBuilder(builder: (context, setModalState) =>
            Padding(padding: EdgeInsets.only(bottom: MediaQuery
                .of(ctx)
                .viewInsets
                .bottom, left: 24, right: 24, top: 24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('🎉 산책 완료! 거리: ${_curDistance.toStringAsFixed(
                      2)}km / 시간: ${_formatTime(_curDuration)}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  GestureDetector(onTap: () async {
                    final img = await ImagePicker().pickImage(
                        source: ImageSource.gallery);
                    if (img != null) setModalState(() => _pickedImage = img);
                  },
                      child: Container(height: 120,
                          width: double.infinity,
                          color: Colors.grey[100],
                          child: _pickedImage != null
                              ? Image.file(
                              File(_pickedImage!.path), fit: BoxFit.cover)
                              : const Icon(Icons.add_a_photo))),
                  const SizedBox(height: 20),
                  Wrap(alignment: WrapAlignment.center,
                      spacing: 15,
                      children: ['😊', '😑', '😫', '😴', '😡']
                          .map((m) =>
                          GestureDetector(onTap: () =>
                              setModalState(() => mood = m),
                              child: Container(padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: mood == m
                                      ? Colors.blue.withOpacity(0.1)
                                      : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Opacity(opacity: mood == m ? 1.0 : 0.3,
                                      child: Text(m, style: const TextStyle(
                                          fontSize: 32))))))
                          .toList()),
                  const SizedBox(height: 20),
                  TextField(controller: memoController,
                      decoration: const InputDecoration(
                          hintText: '산책 메모를 남겨보세요')),
                  const SizedBox(height: 20),
                  ElevatedButton(
                      onPressed: () => _saveRecord(mood, memoController.text),
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50)),
                      child: const Text('기록 저장')),
                  const SizedBox(height: 30)
                ]))));
  }

  Future<void> _saveRecord(String mood, String memo) async {
    showDialog(context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()));
    try {
      String? imageUrl;
      if (_pickedImage != null) imageUrl =
      await FirebaseStorageService.uploadPetImage(
          userId: widget.userId, petId: 'walk_${DateTime
          .now()
          .millisecondsSinceEpoch}', imageFile: _pickedImage!);
      await FirebaseFirestore.instance.collection('walks').add({
        'userId': widget.userId,
        'startTime': _actualStartTime!.toIso8601String(),
        'endTime': DateTime.now().toIso8601String(),
        'duration': _curDuration,
        'distance': _curDistance,
        'mood': mood,
        'notes': memo,
        'imageUrl': imageUrl,
        'route': jsonEncode(
            _curPath
                .map((p) => {'lat': p.latitude, 'lng': p.longitude})
                .toList()),
        'createdAt': FieldValue.serverTimestamp()
      });
      if (mounted) Navigator.pop(context);
      await _resetToIdle();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(children: [
      if (_isWalking) Padding(padding: const EdgeInsets.all(16),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statBox('⏱️ 시간', _formatTime(_curDuration)),
                _statBox('📏 거리', '${_curDistance.toStringAsFixed(2)} km')
              ])),
      Expanded(child: GoogleMap(
          initialCameraPosition: CameraPosition(
              target: _curLatLng ?? const LatLng(37.5665, 126.9780), zoom: 16),
          onMapCreated: (c) => _mapController = c,
          myLocationEnabled: false,
          // 기본 파란 점 비활성화
          markers: {
            ..._markers, // 주변 사용자들 마커
            if (_curLatLng != null) // 내 위치에 내 대표 펫 마커 추가
              Marker(
                markerId: const MarkerId('me'),
                position: _curLatLng!,
                // 아이콘이 로드 전이면 기본 마커, 로드 후엔 펫 사진
                icon: _myPetIcon ?? BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueAzure),
                anchor: const Offset(0.5, 0.5),
                zIndex: 10, // 다른 마커보다 항상 위에 표시
              ),
          },
          polylines: {
            Polyline(polylineId: const PolylineId('p'),
                points: _curPath,
                color: Colors.blue,
                width: 5)
          }
      )),
      Padding(padding: const EdgeInsets.all(20),
          child: ElevatedButton(onPressed: _isWalking ? _stopWalk : _startWalk,
              style: ElevatedButton.styleFrom(
                  backgroundColor: _isWalking ? Colors.red : Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15))),
              child: Text(_isWalking ? '산책 종료하기' : '산책 시작하기',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)))),
    ]);
  }

  /// 초기 권한 상태 확인 및 UI 반영
  Future<void> _checkInitialPermission() async {
    final status = await Permission.location.status;
    if (status.isGranted && mounted) setState(() => _isPermissionReady = true);
  }

  Future<void> _syncServiceAndUI() async {
    final service = FlutterBackgroundService();
    final prefs = await SharedPreferences.getInstance();
    if (await service.isRunning() && (prefs.getBool('is_walking') ?? false)) {
      final startStr = prefs.getString('walk_start_time');
      if (startStr != null && mounted) {
        setState(() {
          _actualStartTime = DateTime.parse(startStr);
          _isWalking = true;
          _isPermissionReady = true;
        });
        _startTimer();
        _listenToBackground();
        _startNearbyUsersListener();
      }
    }
  }

  Future<void> _fetchCurrentLocationOnce() async {
    try {
      Position pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.low));
      if (mounted) setState(() => _curLatLng = LatLng(pos.latitude, pos.longitude));
    } catch (e) {}
  }

  void _loadMyPetMarker() async {
    final petSnap = await FirebaseFirestore.instance.collection('pets')
        .where('userId', isEqualTo: widget.userId)
        .where('isRepresentative', isEqualTo: true).limit(1).get();

    if (petSnap.docs.isNotEmpty) {
      String? url = petSnap.docs.first.data()['imageUrl'];
      if (url != null) {
        if (_globalMarkerCache.containsKey(url)) {
          if (mounted) setState(() => _myPetIcon = _globalMarkerCache[url]);
          return;
        }
        final icon = await _getCircularMarker(url);
        if (mounted) setState(() => _myPetIcon = icon);
      }
    }
  }

  void _animateMarkerMove(LatLng start, LatLng end) {
    const int steps = 30;
    int currentStep = 0;
    Timer.periodic(const Duration(milliseconds: 33), (timer) {
      if (!mounted || currentStep >= steps) { timer.cancel(); return; }
      currentStep++;
      double fraction = currentStep / steps;
      double lat = (end.latitude - start.latitude) * fraction + start.latitude;
      double lng = (end.longitude - start.longitude) * fraction + start.longitude;
      if (mounted) setState(() => _curLatLng = LatLng(lat, lng));
    });
  }

  Future<BitmapDescriptor> _getCircularMarker(String url) {
    if (_globalMarkerCache.containsKey(url)) return Future.value(_globalMarkerCache[url]!);
    if (_iconFutureCache.containsKey(url)) return _iconFutureCache[url]!;
    final future = _processIconBytes(url);
    _iconFutureCache[url] = future;
    return future;
  }

  Future<BitmapDescriptor> _processIconBytes(String url) async {
    try {
      Uint8List bytes;
      if (url.startsWith('http')) {
        final res = await HttpClient().getUrl(Uri.parse(url)).then((req) => req.close());
        bytes = await consolidateHttpClientResponseBytes(res);
      } else {
        bytes = await File(url).readAsBytes();
      }
      final Uint8List markerBytes = await compute(createCircularMarkerBytes, bytes);
      final icon = BitmapDescriptor.fromBytes(markerBytes);
      _globalMarkerCache[url] = icon;
      return icon;
    } catch (e) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    } finally {
      _iconFutureCache.remove(url);
    }
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _nearbyUsersSub?.cancel();
    _bgUpdateSub?.cancel();
    super.dispose();
  }
}