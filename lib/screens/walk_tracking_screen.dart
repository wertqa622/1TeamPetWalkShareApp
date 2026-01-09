import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/walk.dart';
import 'dart:async';
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;

class WalkTrackingScreen extends StatefulWidget {
  final String userId;
  const WalkTrackingScreen({super.key, required this.userId});

  @override
  State<WalkTrackingScreen> createState() => _WalkTrackingScreenState();
}

class _WalkTrackingScreenState extends State<WalkTrackingScreen> with SingleTickerProviderStateMixin {

  // ---------------------------------------------------------------------------
  // [Section 1] 상태 변수 정의
  // ---------------------------------------------------------------------------
  List<Walk> _walkHistory = [];
  bool _isWalking = false;

  double _curDistance = 0.0;
  int _curDuration = 0;
  List<LatLng> _curPath = [];
  LatLng? _curLatLng;
  DateTime? _actualStartTime;

  GoogleMapController? _mapController;
  Timer? _uiTimer;
  Set<Marker> _nearbyMarkers = {};
  StreamSubscription? _usersSubscription;

  // ---------------------------------------------------------------------------
  // [Section 2] 초기화 및 리스너
  // ---------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await [Permission.location, Permission.notification].request();
    _loadWalkHistory();
    _listenToBackgroundData();
    _checkActiveWalkStatus();
    _startNearbyUsersListener();
  }

  void _listenToBackgroundData() {
    FlutterBackgroundService().on('updateData').listen((event) {
      if (event != null && mounted) {
        setState(() {
          _isWalking = true;
          _curDistance = event['distance'] ?? 0.0;
          _curDuration = event['duration'] ?? 0;

          if (event['lat'] != 0.0) {
            _curLatLng = LatLng(event['lat'], event['lng']);
          }

          Iterable list = jsonDecode(event['path'] ?? '[]');
          _curPath = list.map((p) {
            return LatLng(p['lat'], p['lng']);
          }).toList();
        });

        if (_curLatLng != null && _isWalking) {
          _mapController?.animateCamera(
              CameraUpdate.newLatLng(_curLatLng!)
          );
        }
      }
    });
  }

  void _startNearbyUsersListener() {
    _usersSubscription = FirebaseFirestore.instance.collection('users').snapshots().listen((snapshot) {
      Set<Marker> markers = {};
      for (var doc in snapshot.docs) {
        if (doc.id == widget.userId) {
          continue;
        }
        final data = doc.data();
        if (data['latitude'] != null && _curLatLng != null) {
          double dist = _calculateDistance(_curLatLng!.latitude, _curLatLng!.longitude, data['latitude'], data['longitude']);
          if (dist <= 1.0) {
            markers.add(
                Marker(
                    markerId: MarkerId(doc.id),
                    position: LatLng(data['latitude'], data['longitude']),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure)
                )
            );
          }
        }
      }
      setState(() {
        _nearbyMarkers = markers;
      });
    });
  }

  Future<void> _checkActiveWalkStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('is_walking') ?? false) {
      String? startStr = prefs.getString('walk_start_time');
      if (startStr != null) {
        _actualStartTime = DateTime.parse(startStr);
        _isWalking = true;
        _startLocalUITimer();
      }
    }
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _usersSubscription?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // [Section 3] 산책 제어 로직 (딜레이 개선본)
  // ---------------------------------------------------------------------------

  void _startLocalUITimer() {
    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isWalking && _actualStartTime != null) {
        setState(() {
          _curDuration = DateTime.now().difference(_actualStartTime!).inSeconds;
        });
      }
    });
  }

  // [수정]: 5초 딜레이를 제거한 즉시 응답형 산책 시작 로직
  void _startWalk() {
    // 1. UI 상태 즉시 변경 (사용자가 버튼을 누른 순간 바로 화면을 전환함)
    setState(() {
      _isWalking = true;
      _curDuration = 0;
      _actualStartTime = DateTime.now();
    });

    // 2. 타이머 즉시 시작
    _startLocalUITimer();

    // 3. 무거운 백그라운드 작업 및 GPS 수신은 비동기로 처리 (UI를 멈추지 않음)
    _initializeBackgroundProcesses();
  }

  Future<void> _initializeBackgroundProcesses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_walking', true);
    await prefs.setString('walk_start_time', _actualStartTime!.toIso8601String());
    await prefs.setString('current_user_id', widget.userId);

    // 서비스 실행
    FlutterBackgroundService().startService();

    // 초기 지도 위치 잡기: 딜레이 방지를 위해 마지막으로 확인된 위치를 먼저 사용
    Position? lastPos = await Geolocator.getLastKnownPosition();
    if (lastPos != null) {
      _curLatLng = LatLng(lastPos.latitude, lastPos.longitude);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_curLatLng!, 16));
    }

    // 이후 고정밀 위치를 비동기로 받아 지도를 정확히 보정
    Position currentPos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _curLatLng = LatLng(currentPos.latitude, currentPos.longitude);
    });
    _mapController?.animateCamera(CameraUpdate.newLatLng(_curLatLng!));
  }

  Future<void> _deleteWalkRecord(String walkId) async {
    try {
      await FirebaseFirestore.instance.collection('walks').doc(walkId).delete();
      _loadWalkHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('산책 기록이 삭제되었습니다.'))
        );
      }
    } catch (e) {
      debugPrint("기록 삭제 오류: $e");
    }
  }

  void _stopWalk() {
    if (_curDuration < 60) {
      _showCancelConfirmDialog();
    } else {
      _showWalkSummaryModal();
    }
  }

  Future<void> _saveFinalRecord(String memo, String mood) async {
    final endTime = DateTime.now();
    String routeJson = jsonEncode(_curPath.map((p) {
      return {'lat': p.latitude, 'lng': p.longitude};
    }).toList());

    await FirebaseFirestore.instance.collection('walks').add({
      'userId': widget.userId,
      'petId': 'primary_pet',
      'startTime': _actualStartTime!.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'duration': _curDuration,
      'distance': _curDistance,
      'route': routeJson,
      'notes': memo,
      'mood': mood,
      'createdAt': FieldValue.serverTimestamp(),
    });

    _resetScreenState();
  }

  void _resetScreenState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('walk_start_time');
    await prefs.setBool('is_walking', false);
    _uiTimer?.cancel();

    setState(() {
      _isWalking = false;
      _curDistance = 0.0;
      _curDuration = 0;
      _curPath.clear();
    });

    FlutterBackgroundService().invoke('stopService');
    _loadWalkHistory();
  }

  Future<void> _loadWalkHistory() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('walks')
          .where('userId', isEqualTo: widget.userId)
          .orderBy('startTime', descending: true)
          .get();

      setState(() {
        _walkHistory = snapshot.docs.map((doc) {
          return Walk.fromJson({...doc.data(), 'id': doc.id});
        }).toList();
      });
    } catch (e) {
      debugPrint("목록 로드 실패: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // [Section 4] 메인 화면 레이아웃 (Tabs)
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('반려동물 산책 다이어리',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          bottom: const TabBar(
            labelColor: Colors.blue,
            indicatorColor: Colors.blue,
            tabs: [
              Tab(text: '시작'),
              Tab(text: '기록'),
              Tab(text: '통계')
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildStartTabContent(),
            _buildHistoryTabContent(),
            const Center(child: Text('통계 데이터 수집 중')),
          ],
        ),
      ),
    );
  }

  Widget _buildStartTabContent() {
    if (_isWalking) {
      return _buildActiveTrackingView();
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoBanner(),
          const SizedBox(height: 24),
          _buildReadyCard(),
          const SizedBox(height: 24),
          _buildWalkSafetyTips(),
        ],
      ),
    );
  }

  Widget _buildHistoryTabContent() {
    if (_isWalking) {
      return const Center(child: Text('산책 종료 후 기록 확인이 가능합니다.'));
    }
    if (_walkHistory.isEmpty) {
      return const Center(child: Text('저장된 산책 기록이 없습니다.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _walkHistory.length,
      itemBuilder: (ctx, idx) {
        return _buildHistoryItemCard(_walkHistory[idx]);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // [Section 5] 상세 UI 위젯 빌더 (정규 구조)
  // ---------------------------------------------------------------------------

  Widget _buildHistoryItemCard(Walk walk) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 2,
      child: InkWell(
        onTap: () {
          _showWalkDetailDialog(walk);
        },
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        DateFormat('MM.dd (E)', 'ko_KR').format(walk.startTime),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(walk.mood ?? '😊', style: const TextStyle(fontSize: 24)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () {
                      _showDeleteConfirmDialog(walk.id);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '총 ${(walk.duration ?? 0) ~/ 60}분',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      '${walk.distance?.toStringAsFixed(2)}km',
                      style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
              if (walk.notes != null && walk.notes!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Text(
                      walk.notes!,
                      style: TextStyle(color: Colors.grey[700]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTrackingView() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatBox('시간', _formatDuration(Duration(seconds: _curDuration))),
              _buildStatBox('거리', '${_curDistance.toStringAsFixed(2)} km'),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: _curLatLng ?? const LatLng(35.17, 129.07), zoom: 16),
                onMapCreated: (c) { _mapController = c; },
                myLocationEnabled: true,
                markers: _nearbyMarkers,
                polylines: {
                  Polyline(polylineId: const PolylineId('live'), points: _curPath, color: Colors.blue, width: 5)
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () { _stopWalk(); },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            child: const Text('산책 종료하기',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
            ),
          )
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // [Section 6] 다이얼로그 및 유틸리티 (정규 구조)
  // ---------------------------------------------------------------------------

  void _showDeleteConfirmDialog(String walkId) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('기록 삭제 확인'),
          content: const Text('이 산책 기록을 영구적으로 삭제하시겠습니까? 삭제된 데이터는 복구할 수 없습니다.'),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                },
                child: const Text('취소')
            ),
            TextButton(
                onPressed: () {
                  _deleteWalkRecord(walkId);
                  Navigator.pop(ctx);
                },
                child: const Text('영구 삭제', style: TextStyle(color: Colors.red))
            ),
          ],
        );
      },
    );
  }

  void _showWalkDetailDialog(Walk walk) {
    List<LatLng> points = [];
    if (walk.route != null && walk.route!.isNotEmpty) {
      try {
        List<dynamic> decoded = jsonDecode(walk.route!);
        points = decoded.map((p) {
          return LatLng(p['lat'], p['lng']);
        }).toList();
      } catch (_) {}
    }
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('산책 정보 상세', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 200,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                        target: points.isNotEmpty ? points.first : const LatLng(35.17, 129.07),
                        zoom: 15
                    ),
                    polylines: {
                      Polyline(polylineId: const PolylineId('route'), points: points, color: Colors.blue, width: 5)
                    },
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildDetailRow('시작 시간', DateFormat('yyyy.MM.dd HH:mm').format(walk.startTime)),
              _buildDetailRow('이동 거리', '${walk.distance?.toStringAsFixed(2)} km'),
              _buildDetailRow('산책 시간', '${(walk.duration ?? 0) ~/ 60}분'),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () { Navigator.pop(ctx); },
                child: const Text('닫기')
            )
          ],
        );
      },
    );
  }

  void _showWalkSummaryModal() {
    final memoController = TextEditingController();
    String selectedMood = '😊';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: Text('오늘의 산책 기록하기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildModalStatBlock('총 시간', _formatDuration(Duration(seconds: _curDuration))),
                        _buildModalStatBlock('총 거리', '${_curDistance.toStringAsFixed(2)} km'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('산책 후 기분은 어떤가요?', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12, runSpacing: 12,
                    children: ['😊', '😬', '😍', '😎', '😴', '😐', '🤩', '🧐'].map((mood) {
                      return GestureDetector(
                        onTap: () { setModalState(() { selectedMood = mood; }); },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: selectedMood == mood ? Colors.blue[50] : Colors.white,
                              border: Border.all(color: selectedMood == mood ? Colors.blue : Colors.grey[200]!),
                              borderRadius: BorderRadius.circular(12)
                          ),
                          child: Text(mood, style: const TextStyle(fontSize: 24)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  const Text('산책 메모', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: memoController,
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: '오늘 산책에 대해 기록해주세요...', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                      onPressed: () {
                        _saveFinalRecord(memoController.text, selectedMood).then((_) {
                          Navigator.pop(ctx);
                        });
                      },
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                      child: const Text('산책 기록 저장')
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // [Section 7] 공통 UI 헬퍼 및 유틸리티 (정규 구조화)
  // ---------------------------------------------------------------------------

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildModalStatBlock(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _formatDuration(Duration d) {
    String t(int n) {
      return n.toString().padLeft(2, '0');
    }
    return "${t(d.inHours)}:${t(d.inMinutes.remainder(60))}:${t(d.inSeconds.remainder(60))}";
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green[100]!)),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 18),
          SizedBox(width: 8),
          Text('산책 시스템 계정 연동 완료', style: TextStyle(color: Colors.green, fontSize: 13))
        ],
      ),
    );
  }

  Widget _buildReadyCard() {
    return Container(
      padding: const EdgeInsets.all(40),
      width: double.infinity,
      decoration: BoxDecoration(color: const Color(0xFFF8F9FE), borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          const Icon(Icons.location_on, size: 60, color: Colors.blue),
          const SizedBox(height: 12),
          const Text('산책을 시작할 준비가 되셨나요?', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              _startWalk();
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('산책 시작하기'),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8E44AD),
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalkSafetyTips() {
    return Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey[100]!), borderRadius: BorderRadius.circular(15)),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('산책 팁 💡', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          Text('• GPS 위치 권한을 항상 허용으로 설정해주세요', style: TextStyle(fontSize: 13, color: Colors.grey)),
          Text('• 산책 중에는 반려동물의 안전을 항상 확인하세요', style: TextStyle(fontSize: 13, color: Colors.grey)),
          Text('• 배변봉투를 지참하는 펫티켓을 지켜주세요', style: TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }

  double _calculateDistance(double la1, double lo1, double la2, double lo2) {
    double p = 0.017453292519943295;
    double a = 0.5 - math.cos((la2 - la1) * p) / 2 + math.cos(la1 * p) * math.cos(la2 * p) * (1 - math.cos((lo2 - lo1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a));
  }

  void _showCancelConfirmDialog() {
    showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
              title: const Text('산책 기록 취소'),
              content: const Text('1분 미만의 짧은 산책은 자동으로 저장되지 않습니다. 종료하시겠습니까?'),
              actions: [
                TextButton(
                    onPressed: () { Navigator.pop(ctx); },
                    child: const Text('취소')
                ),
                TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _resetScreenState();
                    },
                    child: const Text('산책 종료', style: TextStyle(color: Colors.red))
                )
              ]
          );
        }
    );
  }
}