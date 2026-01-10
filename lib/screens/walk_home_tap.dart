import 'package:flutter/material.dart';
import 'walk_tracking_tab.dart';
import 'walk_history_tap.dart';
import 'walk_stats_tab.dart';

class WalkHomeTab extends StatefulWidget {
  final String userId;
  const WalkHomeTab({super.key, required this.userId});
  @override
  State<WalkHomeTab> createState() => _WalkHomeTabState();
}

class _WalkHomeTabState extends State<WalkHomeTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 60, bottom: 20),
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFFA855F7)]),
            ),
            child: const Center(child: Text('🐾 산책 다이어리', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
          ),
          TabBar(
            controller: _tabController,
            tabs: const [Tab(text: '시작'), Tab(text: '기록'), Tab(text: '통계')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              // [요구사항]: 화면 이동 후 돌아와도 상태 유지 (AutomaticKeepAliveClientMixin 사용 권장)
              children: [
                WalkTrackingTab(userId: widget.userId),
                WalkHistoryTab(userId: widget.userId),
                const WalkStatsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}