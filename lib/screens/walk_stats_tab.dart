import 'package:flutter/material.dart';

class WalkStatsTab extends StatelessWidget {
  const WalkStatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('산책 통계 분석 서비스', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text('데이터가 쌓이면 주간/월간 통계가 표시됩니다.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}