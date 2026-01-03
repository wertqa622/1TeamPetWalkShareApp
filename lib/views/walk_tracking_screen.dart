import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../models/walk.dart';
import '../viewmodels/location_viewmodel.dart';

class WalkTrackingScreen extends StatefulWidget {
  final String userId;

  const WalkTrackingScreen({
    super.key,
    required this.userId,
  });

  @override
  State<WalkTrackingScreen> createState() => _WalkTrackingScreenState();
}

class _WalkTrackingScreenState extends State<WalkTrackingScreen> {
  Walk? _currentWalk;
  List<Walk> _walkHistory = [];
  bool _isWalking = false;

  @override
  void initState() {
    super.initState();
    _loadWalkHistory();
  }

  void _loadWalkHistory() {
    setState(() {
      _walkHistory = [];
    });
  }

  Future<void> _startWalk() async {
    // 1. 위치 권한 확인
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    // 2. 백그라운드 서비스 시작
    final service = FlutterBackgroundService();
    var isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
    }
    
    // 유저 ID 전달 (위치 업데이트용)
    service.invoke("setUserId", {"userId": widget.userId});

    // 3. UI 상태 업데이트
    setState(() {
      _isWalking = true;
      // 임시 산책 객체 생성
      _currentWalk = Walk(
        id: DateTime.now().toIso8601String(),
        userId: widget.userId,
        petId: 'temp_pet',
        startTime: DateTime.now(),
        createdAt: DateTime.now().toIso8601String(),
      );
    });

    // 4. LocationViewModel에 공유 상태 알림
    if (mounted) {
      final position = await Geolocator.getCurrentPosition();
      context.read<LocationViewModel>().startSharing(
        widget.userId, 
        position.latitude, 
        position.longitude
      );
    }
  }

  Future<void> _stopWalk() async {
    // 1. 백그라운드 서비스 종료 신호 전송
    final service = FlutterBackgroundService();
    service.invoke("stopService");

    // 2. LocationViewModel 공유 중단
    if (mounted) {
      context.read<LocationViewModel>().stopSharing(widget.userId);
    }

    // 3. UI 상태 업데이트
    setState(() {
      _isWalking = false;
      if (_currentWalk != null) {
        _walkHistory.insert(0, _currentWalk!);
        _currentWalk = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '산책 추적',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_isWalking)
                    Card(
                      color: Colors.blue[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text(
                              '산책 중... 🐾',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '위치를 실시간으로 공유하고 있습니다.',
                              style: TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _stopWalk,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                              ),
                              child: const Text('산책 종료'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.directions_walk,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '산책을 시작해보세요!',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _startWalk,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('산책 시작'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                  const Text(
                    '내 주변 산책 친구',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 주변 유저 마커 표시 영역 (지도 대신 리스트로 임시 표시)
                  // 실제 구현 시에는 GoogleMap 위젯이 여기에 들어가야 함
                  Consumer<LocationViewModel>(
                    builder: (context, viewModel, child) {
                      // 지도 화면이 아니므로 여기서는 리스트로 표시하거나
                      // "지도를 열어 주변 친구 찾기" 버튼을 두는 것이 좋음
                      // 여기서는 현재 공유 중일 때만 주변 유저 수를 표시
                      if (!_isWalking) {
                        return const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('산책을 시작하면 주변 친구들을 볼 수 있어요!'),
                          ),
                        );
                      }
                      
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('실시간 위치 공유 중'),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () {
                                  // TODO: 지도 화면으로 이동 (여기서 마커 표시)
                                  // startListeningNearbyUsers 호출 필요
                                }, 
                                child: const Text('지도에서 보기')
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
