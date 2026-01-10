import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/walk.dart';
import '../../services/walk_service.dart';

class WalkStatsTab extends StatefulWidget {
  const WalkStatsTab({super.key});

  @override
  State<WalkStatsTab> createState() => _WalkStatsTabState();
}

class _WalkStatsTabState extends State<WalkStatsTab> {
  bool _isLoading = true;
  List<Walk> _myWalks = [];

  // 통계 변수들
  double _totalDistance = 0.0; // km
  int _totalDuration = 0; // seconds
  int _totalCount = 0;
  Map<String, double> _weeklyDistance = {}; // 최근 7일 데이터

  @override
  void initState() {
    super.initState();
    _loadWalkData();
  }

  Future<void> _loadWalkData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // 1. 데이터 가져오기
    final walks = await WalkService.fetchUserWalks(user.uid);

    if (!mounted) return;

    // 2. 통계 계산
    double totalDist = 0;
    int totalTime = 0;

    // 최근 7일 날짜 키 생성 (오늘부터 6일 전까지)
    Map<String, double> weeklyMap = {};
    DateTime now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      DateTime day = now.subtract(Duration(days: i));
      String dateKey = DateFormat('MM/dd').format(day);
      weeklyMap[dateKey] = 0.0;
    }

    for (var walk in walks) {
      totalDist += (walk.distance ?? 0.0);
      totalTime += (walk.duration ?? 0);

      // 주간 통계용 데이터 집계
      String dateKey = DateFormat('MM/dd').format(walk.startTime);
      if (weeklyMap.containsKey(dateKey)) {
        weeklyMap[dateKey] = (weeklyMap[dateKey]! + (walk.distance ?? 0.0));
      }
    }

    setState(() {
      _myWalks = walks;
      _totalDistance = totalDist;
      _totalDuration = totalTime;
      _totalCount = walks.length;
      _weeklyDistance = weeklyMap;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_myWalks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pets, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('아직 산책 기록이 없어요!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('반려동물과 함께 첫 산책을 시작해보세요.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('나의 산책 요약', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // 1. 종합 통계 카드
          Row(
            children: [
              _buildStatCard('총 거리', '${_totalDistance.toStringAsFixed(1)}', 'km', Icons.map),
              const SizedBox(width: 12),
              _buildStatCard('총 시간', _formatDuration(_totalDuration), '', Icons.timer),
              const SizedBox(width: 12),
              _buildStatCard('산책 횟수', '$_totalCount', '회', Icons.directions_walk),
            ],
          ),

          const SizedBox(height: 32),

          // 2. 주간 그래프
          const Text('최근 7일 활동량 (km)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 2, blurRadius: 8)],
            ),
            child: _buildWeeklyChart(),
          ),

          const SizedBox(height: 32),

          // 3. 최근 기록 리스트 (간략히)
          const Text('최근 기록', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: _myWalks.length > 5 ? 5 : _myWalks.length, // 최대 5개만 노출
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final walk = _myWalks[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    image: walk.imageUrl != null
                        ? DecorationImage(image: NetworkImage(walk.imageUrl!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: walk.imageUrl == null ? const Icon(Icons.pets, color: Colors.grey) : null,
                ),
                title: Text(DateFormat('yyyy년 MM월 dd일').format(walk.startTime)),
                subtitle: Text('${_formatDuration(walk.duration ?? 0)} · ${(walk.distance ?? 0).toStringAsFixed(2)}km'),
                trailing: walk.mood != null ? Text(walk.mood!, style: const TextStyle(fontSize: 20)) : null,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String unit, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 4)],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.blueAccent, size: 28),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (unit.isNotEmpty) Text(unit, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyChart() {
    if (_weeklyDistance.isEmpty) return const Center(child: Text("데이터 없음"));

    // 최대값 찾기 (그래프 높이 비율 계산용)
    double maxDist = _weeklyDistance.values.reduce((a, b) => a > b ? a : b);
    if (maxDist == 0) maxDist = 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: _weeklyDistance.entries.map((entry) {
        double heightRatio = entry.value / maxDist;
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (entry.value > 0)
              Text(entry.value.toStringAsFixed(1), style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 12,
              height: 100 * heightRatio + 4, // 최소 높이 보정
              decoration: BoxDecoration(
                color: entry.value > 0 ? Colors.blueAccent : Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Text(entry.key, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        );
      }).toList(),
    );
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    if (duration.inHours > 0) {
      return '${duration.inHours}시간';
    } else {
      return '${duration.inMinutes}분';
    }
  }
}