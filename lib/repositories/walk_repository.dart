import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/walk.dart';

class WalkRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _walksRef => 
      _firestore.collection('walks');

  // 특정 유저의 산책 기록 가져오기
  Future<List<Walk>> getUserWalks(String userId) async {
    try {
      final snapshot = await _walksRef
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => Walk.fromJson(doc.data())).toList();
    } catch (e) {
      return [];
    }
  }

  // 산책 기록 저장
  Future<void> saveWalk(Walk walk) async {
    await _walksRef.doc(walk.id).set(walk.toJson());
  }
}

