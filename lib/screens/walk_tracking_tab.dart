import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import '../services/firebase_storage_service.dart';

class WalkTrackingTab extends StatefulWidget {
  final String userId;
  const WalkTrackingTab({super.key, required this.userId});

  @override
  State<WalkTrackingTab> createState() => _WalkTrackingTabState();
}

// [수정]: AutomaticKeepAliveClientMixin을 추가하여 화면 유지 기능 구현
class _WalkTrackingTabState extends State<WalkTrackingTab> with AutomaticKeepAliveClientMixin {

  // [수정]: 탭 이동 시에도 상태를 유지하도록 설정
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

  @override
  void initState() {
    super.initState();
    _checkActiveWalk(); // 화면 복귀 시 진행 중인 산책 확인
    _listenToBackground();
    _fetchCurrentLocationOnce(); // 시작 전이라도 지도를 사용자 위치로 세팅
  }

  // 초기 진입 시 현재 위치를 가져와 지도를 미리 세팅
  Future<void> _fetchCurrentLocationOnce() async {
    try {
      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      if (mounted && _curLatLng == null) {
        setState(() {
          _curLatLng = LatLng(pos.latitude, pos.longitude);
        });
        _mapController?.moveCamera(CameraUpdate.newLatLngZoom(_curLatLng!, 16));
      }
    } catch (e) {
      debugPrint("초기 위치 로드 실패: $e");
    }
  }

  void _listenToBackground() {
    FlutterBackgroundService().on('updateData').listen((event) {
      if (event != null && mounted) {
        setState(() {
          _isWalking = true;
          _curDistance = event['distance'] ?? 0.0;
          if (event['lat'] != null) {
            _curLatLng = LatLng(event['lat'], event['lng']);
          }
          _curPath = (jsonDecode(event['path']) as List)
              .map((p) => LatLng(p['lat'], p['lng']))
              .toList();
        });
      }
    });
  }

  // [기존 유지]: 산책 시작 시 내 위치로 즉시 이동
  void _startWalk() async {
    await [Permission.location, Permission.notification].request();

    Position pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    _curLatLng = LatLng(pos.latitude, pos.longitude);

    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_curLatLng!, 17));

    setState(() {
      _isWalking = true;
      _curDuration = 0;
      _actualStartTime = DateTime.now();
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_walking', true);
    await prefs.setString('walk_start_time', _actualStartTime!.toIso8601String());
    await prefs.setString('current_user_id', widget.userId);

    FlutterBackgroundService().startService();
    _startTimer();
  }

  void _startTimer() {
    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isWalking) setState(() => _curDuration++);
    });
  }

  // [기존 유지]: 1분 미만 종료 확인 및 취소/유지 팝업
  void _stopWalk() {
    if (_curDuration < 60) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('산책 종료 확인'),
          content: const Text('산책 시간이 1분 미만입니다. 산책을 취소하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('산책 유지'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _resetState(save: false);
              },
              child: const Text('산책 취소', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    } else {
      _showSaveModal();
    }
  }

  void _showSaveModal() {
    String mood = '😊';
    final memoController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🎉 산책 완료! 거리: ${_curDistance.toStringAsFixed(2)}km / 시간: ${_formatTime(_curDuration)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () async {
                  final img = await ImagePicker().pickImage(source: ImageSource.gallery);
                  if (img != null) setModalState(() => _pickedImage = img);
                },
                child: Container(
                  height: 120, width: double.infinity, color: Colors.grey[200],
                  child: _pickedImage != null ? Image.file(File(_pickedImage!.path), fit: BoxFit.cover) : const Icon(Icons.add_a_photo),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: ['😊', '🐶', '🏃', '😴', '💩'].map((e) => GestureDetector(
                  onTap: () => setModalState(() => mood = e),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Text(e, style: TextStyle(fontSize: 30, color: Colors.black.withOpacity(mood == e ? 1.0 : 0.3))),
                  ),
                )).toList(),
              ),
              TextField(controller: memoController, decoration: const InputDecoration(hintText: '산책 메모를 남겨보세요')),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _saveRecord(mood, memoController.text),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                child: const Text('기록 저장'),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveRecord(String mood, String memo) async {
    String? imageUrl;
    if (_pickedImage != null) {
      imageUrl = await FirebaseStorageService.uploadPetImage(
          userId: widget.userId, petId: 'walk_${DateTime.now().millisecondsSinceEpoch}', imageFile: _pickedImage!
      );
    }
    await FirebaseFirestore.instance.collection('walks').add({
      'userId': widget.userId,
      'startTime': _actualStartTime!.toIso8601String(),
      'endTime': DateTime.now().toIso8601String(),
      'duration': _curDuration,
      'distance': _curDistance,
      'mood': mood,
      'notes': memo,
      'imageUrl': imageUrl,
      'route': jsonEncode(_curPath.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList()),
      'createdAt': FieldValue.serverTimestamp(),
    });
    _resetState(save: true);
    Navigator.pop(context);
  }

  void _resetState({required bool save}) async {
    _uiTimer?.cancel();
    FlutterBackgroundService().invoke('stopService');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_walking', false);
    setState(() {
      _isWalking = false;
      _curPath = [];
      _curDistance = 0.0;
      _pickedImage = null;
    });
  }

  Future<void> _checkActiveWalk() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('is_walking') ?? false) {
      final start = DateTime.parse(prefs.getString('walk_start_time')!);
      setState(() {
        _actualStartTime = start;
        _isWalking = true;
        _curDuration = DateTime.now().difference(start).inSeconds;
      });
      _startTimer();
    }
  }

  String _formatTime(int s) => "${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    super.build(context); // [수정]: mixin 사용 시 필수 호출
    return Column(
      children: [
        if (_isWalking)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statBox('⏱️ 시간', _formatTime(_curDuration)),
                _statBox('📏 거리', '${_curDistance.toStringAsFixed(2)} km'),
              ],
            ),
          ),
        Expanded(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: _curLatLng ?? const LatLng(37.56, 126.97), zoom: 16),
            onMapCreated: (c) => _mapController = c,
            myLocationEnabled: true,
            polylines: {Polyline(polylineId: const PolylineId('p'), points: _curPath, color: Colors.blue, width: 5)},
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: ElevatedButton(
            onPressed: _isWalking ? _stopWalk : _startWalk,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isWalking ? Colors.red : Colors.blue,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            child: Text(_isWalking ? '산책 종료하기' : '산책 시작하기', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _statBox(String l, String v) => Column(children: [
    Text(l, style: const TextStyle(color: Colors.grey, fontSize: 13)),
    Text(v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
  ]);

  @override
  void dispose() { _uiTimer?.cancel(); super.dispose(); }
}