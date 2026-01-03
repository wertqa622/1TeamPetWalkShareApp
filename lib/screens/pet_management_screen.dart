import 'package:flutter/material.dart';
import '../models/pet.dart';
import '../services/pet_storage_service.dart';
import 'add_pet_screen.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class PetManagementScreen extends StatefulWidget {
  final String userId;

  const PetManagementScreen({
    super.key,
    required this.userId,
  });

  @override
  State<PetManagementScreen> createState() => _PetManagementScreenState();
}

class _PetManagementScreenState extends State<PetManagementScreen> {
  List<Pet> _pets = [];

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    try {
      final pets = await PetStorageService.getPets(widget.userId);
      setState(() {
        _pets = pets;
      });
    } catch (e) {
      setState(() {
        _pets = [];
      });
    }
  }

  void _addPet() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddPetScreen(userId: widget.userId),
    );

    // 반려동물이 추가되면 목록 새로고침
    if (result == true) {
      _loadPets();
    }
  }

  void _showPetDetail(Pet pet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7, // 화면의 70% 높이
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // 상단 핸들 바 (디자인 요소)
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            // 1. 프로필 사진 (FR-202)
            CircleAvatar(
              radius: 60,
              backgroundColor: const Color(0xFFEFF6FF), // blue-50
              backgroundImage: pet.imageUrl != null && pet.imageUrl!.isNotEmpty
                  ? FileImage(File(pet.imageUrl!))
                  : null,
              child: pet.imageUrl == null || pet.imageUrl!.isEmpty
                  ? const Icon(Icons.pets, size: 60, color: Color(0xFF2563EB))
                  : null,
            ),
            const SizedBox(height: 16),
            // 2. 이름 및 품종
            Text(
              pet.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              '${pet.species} • ${pet.breed}',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            const Divider(indent: 20, endIndent: 20),
            // 3. 상세 정보 목록 (FR-202 필수 데이터들)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _buildDetailRow(
                      Icons.cake,
                      '생년월일',
                      pet.dateOfBirth != null ? DateFormat('yyyy년 MM월 dd일').format(pet.dateOfBirth!) : '정보 없음'
                  ),
                  _buildDetailRow(Icons.wc, '성별', pet.gender ?? '정보 없음'),
                  _buildDetailRow(Icons.monitor_weight, '몸무게', pet.weight != null ? '${pet.weight} kg' : '정보 없음'),
                  _buildDetailRow(Icons.health_and_safety, '중성화 여부', pet.isNeutered ? '완료' : '미완료'),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

// 상세 항목 한 줄을 그리는 헬퍼 위젯
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2563EB), size: 24),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
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
                    '반려동물 관리',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_pets.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.pets,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '등록된 반려동물이 없습니다',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _addPet,
                              icon: const Icon(Icons.add),
                              label: const Text('반려동물 추가하기'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._pets.map((pet) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          child: const Icon(Icons.pets),
                        ),
                        title: Text(pet.name),
                        subtitle: Text('${pet.species} • ${pet.breed}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // TODO: 반려동물 상세 정보
                          _showPetDetail(pet);
                        },
                      ),
                    )),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addPet,
        child: const Icon(Icons.add),
      ),
    );
  }
}



