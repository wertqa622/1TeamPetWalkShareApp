import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/walk.dart';
import 'walk_detail_screen.dart'; // [수정]: 상대 경로 확인 (image_5ecc76 에러 해결)

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
        if (docs.isEmpty) return const Center(child: Text('기록이 없습니다.'));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (ctx, idx) {
            final data = docs[idx].data() as Map<String, dynamic>;
            final walk = Walk.fromJson({...data, 'id': docs[idx].id});
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: Text(walk.mood ?? '😊', style: const TextStyle(fontSize: 24)),
                title: Text("${walk.distance?.toStringAsFixed(2)}km / ${((walk.duration ?? 0) ~/ 60)}분"),
                subtitle: Text(DateFormat('yyyy.MM.dd HH:mm').format(walk.startTime)),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => WalkDetailScreen(walk: walk)));
                },
              ),
            );
          },
        );
      },
    );
  }
}