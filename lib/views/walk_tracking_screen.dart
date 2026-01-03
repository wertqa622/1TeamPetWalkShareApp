import 'package:flutter/material.dart';
import '../models/walk.dart';

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

  @override
  void initState() {
    super.initState();
    _loadWalkHistory();
  }

  void _loadWalkHistory() {
    // TODO: 실제 데이터 로드 구현
    setState(() {
      _walkHistory = [];
    });
  }

  void _startWalk() {
    // TODO: 산책 시작 기능 구현
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('산책 시작'),
        content: const Text('산책 추적 기능을 구현해주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _stopWalk() {
    // TODO: 산책 종료 기능 구현
    setState(() {
      _currentWalk = null;
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
                  if (_currentWalk != null)
                    Card(
                      color: Colors.blue[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text(
                              '산책 중',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
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
                    '산책 기록',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_walkHistory.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(
                          '아직 산책 기록이 없습니다',
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    )
                  else
                    ..._walkHistory.map((walk) => Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const Icon(Icons.directions_walk),
                            title: Text(
                              '${walk.distance?.toStringAsFixed(1) ?? "0"} km',
                            ),
                            subtitle: Text(
                              walk.startTime.toString().substring(0, 16),
                            ),
                            trailing: Text(
                              walk.duration != null
                                  ? '${walk.duration! ~/ 60}분'
                                  : '-',
                            ),
                          ),
                        )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

