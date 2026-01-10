import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/walk.dart';
import 'walk_detail_screen.dart';

class WalkHistoryTab extends StatelessWidget {
  final String userId;
  const WalkHistoryTab({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('walks')
          .where('userId', isEqualTo: userId)
          .orderBy('startTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const Center(child: Text('저장된 산책 기록이 없습니다.'));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (ctx, idx) {
            final data = docs[idx].data() as Map<String, dynamic>;
            final walk = Walk.fromJson({...data, 'id': docs[idx].id});

            return GestureDetector(
              onTap: () {
                // 상세 화면으로 이동
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => WalkDetailScreen(walk: walk)),
                );
              },
              child: Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. 날짜, 시간 및 이모지 영역
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                // 날짜 및 시간 표시
                                DateFormat('MM.dd (E) HH:mm', 'ko_KR').format(walk.startTime),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 10),
                              // 이모지 표시
                              Text(walk.mood ?? '😊', style: const TextStyle(fontSize: 24)),
                            ],
                          ),
                          // 삭제 버튼 (선택 사항)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                            onPressed: () => _confirmDelete(context, docs[idx].id),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 2. 산책 거리 및 시간 정보
                      Row(
                        children: [
                          // 산책 시간 표시
                          Text(
                            '총 ${((walk.duration ?? 0) ~/ 60)}분',
                            style: const TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          const SizedBox(width: 12),
                          // 산책 거리 배지
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDBEAFE),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${walk.distance?.toStringAsFixed(2)}km',
                              style: const TextStyle(
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // 3. 메모 내용 일부분 표시
                      if (walk.notes != null && walk.notes!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            walk.notes!,
                            maxLines: 1, // 메모 간소화 (한 줄만 표시)
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey[700], fontSize: 14),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 삭제 확인 다이얼로그
  void _confirmDelete(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기록 삭제'),
        content: const Text('이 산책 기록을 영구적으로 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('walks').doc(docId).delete();
              Navigator.pop(ctx);
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}