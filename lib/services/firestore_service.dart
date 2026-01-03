import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pet.dart';

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _petsCollection = 'pets';

  // 반려동물 추가
  static Future<String> addPet(Pet pet) async {
    try {
      final docRef = await _firestore.collection(_petsCollection).add(
            pet.toFirestore(),
          );

      // 생성된 문서 ID로 업데이트
      await docRef.update({'id': docRef.id});

      return docRef.id;
    } catch (e) {
      throw Exception('반려동물 추가 실패: $e');
    }
  }

  // 반려동물 업데이트
  static Future<void> updatePet(String petId, Map<String, dynamic> data) async {
    try {
      final docRef = _firestore.collection(_petsCollection).doc(petId);
      await docRef.update(data);
    } catch (e) {
      throw Exception('반려동물 업데이트 실패: $e');
    }
  }

  // 사용자의 반려동물 목록 가져오기
  static Stream<List<Pet>> getPetsByUserId(String userId) {
    return _firestore
        .collection(_petsCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Pet.fromFirestore(data);
      }).toList();
    });
  }

  // 반려동물 삭제
  static Future<void> deletePet(String petId) async {
    try {
      await _firestore.collection(_petsCollection).doc(petId).delete();
    } catch (e) {
      throw Exception('반려동물 삭제 실패: $e');
    }
  }
}

