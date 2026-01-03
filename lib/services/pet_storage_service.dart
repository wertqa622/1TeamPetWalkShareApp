import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pet.dart';

class PetStorageService {
  static const String _petsKey = 'pets';

  // 반려동물 목록 가져오기
  static Future<List<Pet>> getPets(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final petsJson = prefs.getString(_petsKey);
    
    if (petsJson == null) {
      return [];
    }

    try {
      final List<dynamic> petsList = json.decode(petsJson) as List<dynamic>;
      final allPets = petsList
          .map((json) => Pet.fromJson(json as Map<String, dynamic>))
          .toList();
      
      // 해당 사용자의 반려동물만 필터링
      return allPets.where((pet) => pet.userId == userId).toList();
    } catch (e) {
      return [];
    }
  }

  // 반려동물 추가
  static Future<String> addPet(Pet pet) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final petsJson = prefs.getString(_petsKey);
      
      List<Pet> pets = [];
      if (petsJson != null) {
        final List<dynamic> petsList = json.decode(petsJson) as List<dynamic>;
        pets = petsList
            .map((json) => Pet.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      // ID 생성 (타임스탬프 기반)
      final petId = DateTime.now().millisecondsSinceEpoch.toString();
      final newPet = Pet(
        id: petId,
        userId: pet.userId,
        name: pet.name,
        species: pet.species,
        breed: pet.breed,
        age: pet.age,
        imageUrl: pet.imageUrl,
        createdAt: pet.createdAt,
        dateOfBirth: pet.dateOfBirth,
        gender: pet.gender,
        weight: pet.weight,
        isNeutered: pet.isNeutered,
      );

      pets.add(newPet);
      
      await prefs.setString(_petsKey, json.encode(
        pets.map((p) => p.toJson()).toList(),
      ));

      return petId;
    } catch (e) {
      throw Exception('반려동물 추가 실패: $e');
    }
  }

  // 반려동물 업데이트
  static Future<void> updatePet(String petId, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final petsJson = prefs.getString(_petsKey);
      
      if (petsJson == null) {
        throw Exception('반려동물을 찾을 수 없습니다.');
      }

      final List<dynamic> petsList = json.decode(petsJson) as List<dynamic>;
      final pets = petsList
          .map((json) => Pet.fromJson(json as Map<String, dynamic>))
          .toList();

      final index = pets.indexWhere((pet) => pet.id == petId);
      if (index == -1) {
        throw Exception('반려동물을 찾을 수 없습니다.');
      }

      // 기존 데이터와 병합
      final existingPet = pets[index];
      final updatedPet = Pet(
        id: existingPet.id,
        userId: existingPet.userId,
        name: data['name'] ?? existingPet.name,
        species: data['species'] ?? existingPet.species,
        breed: data['breed'] ?? existingPet.breed,
        age: data['age'] ?? existingPet.age,
        imageUrl: data['imageUrl'] ?? existingPet.imageUrl,
        createdAt: existingPet.createdAt,
        dateOfBirth: data['dateOfBirth'] ?? existingPet.dateOfBirth,
        gender: data['gender'] ?? existingPet.gender,
        weight: data['weight'] ?? existingPet.weight,
        isNeutered: data['isNeutered'] ?? existingPet.isNeutered,
      );

      pets[index] = updatedPet;
      
      await prefs.setString(_petsKey, json.encode(
        pets.map((p) => p.toJson()).toList(),
      ));
    } catch (e) {
      throw Exception('반려동물 업데이트 실패: $e');
    }
  }

  // 반려동물 삭제
  static Future<void> deletePet(String petId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final petsJson = prefs.getString(_petsKey);
      
      if (petsJson == null) {
        return;
      }

      final List<dynamic> petsList = json.decode(petsJson) as List<dynamic>;
      final pets = petsList
          .map((json) => Pet.fromJson(json as Map<String, dynamic>))
          .toList();

      pets.removeWhere((pet) => pet.id == petId);
      
      await prefs.setString(_petsKey, json.encode(
        pets.map((p) => p.toJson()).toList(),
      ));
    } catch (e) {
      throw Exception('반려동물 삭제 실패: $e');
    }
  }
}


