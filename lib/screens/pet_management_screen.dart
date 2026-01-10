import 'dart:io';
import 'package:flutter/material.dart';
import '../models/pet.dart';
import '../services/firestore_service.dart';
import 'add_pet_screen.dart';

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

  void _loadPets() {
    // Firestore Stream을 사용하여 실시간 업데이트
    FirestoreService.getPetsByUserId(widget.userId).listen((pets) {
      if (mounted) {
        setState(() {
          // 대표 반려동물을 맨 위로 정렬
          _pets = pets..sort((a, b) {
            if (a.isRepresentative && !b.isRepresentative) return -1;
            if (!a.isRepresentative && b.isRepresentative) return 1;
            return 0;
          });
        });
      }
    });
  }

  void _addPet() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddPetScreen(userId: widget.userId),
    );

    // Stream을 사용하므로 자동으로 업데이트됨 (새로고침 불필요)
  }

  void _editPet(Pet pet) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddPetScreen(
        userId: widget.userId,
        pet: pet,
      ),
    );

    // Stream을 사용하므로 자동으로 업데이트됨 (새로고침 불필요)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
                  if (_pets.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
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
                      ),
                    )
                  else
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final pet = _pets[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: _buildPetCard(pet),
                    );
                  },
                  childCount: _pets.length,
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

  Widget _buildPetCard(Pet pet) {
    final bool hasImage = pet.imageUrl != null && pet.imageUrl!.isNotEmpty;
    final bool isLocalFile = hasImage && !pet.imageUrl!.startsWith('http');

    return Card(
      margin: const EdgeInsets.only(top: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.blue.shade300,
          width: 1,
        ),

      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단: 프로필 이미지, 이름, 별, 수정/삭제 버튼
            Row(
              children: [
                // 원형 프로필 이미지
                ClipOval(
                  child: Container(
                    width: 60,
                    height: 60,
                    color: Colors.teal.shade700,
                    child: hasImage && isLocalFile
                        ? Image.file(
                            File(pet.imageUrl!),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildPlaceholderAvatar();
                            },
                          )
                        : hasImage && !isLocalFile
                            ? Image.network(
                                pet.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildPlaceholderAvatar();
                                },
                              )
                            : _buildPlaceholderAvatar(),
                  ),
                ),
                const SizedBox(width: 12),
                // 이름, 별, 품종
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            pet.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (pet.isRepresentative) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.star,
                              size: 20,
                              color: Colors.blue.shade700,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pet.breed,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // 수정/삭제 버튼
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        color: Colors.grey[700],
                      ),
                      onPressed: () {
                        _editPet(pet);
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: Colors.red.shade400,
                      ),
                      onPressed: () {
                        _showDeleteDialog(pet);
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 하단: 나이, 몸무게, 성별, 중성화 여부
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '나이: ${pet.calculateAge()}살',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '몸무게: ${pet.weight != null ? "${pet.weight}kg" : "-"}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '성별: ${pet.gender ?? "-"}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '중성화: ${pet.isNeutered ? "O" : "X"}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // 대표 반려동물 설정 버튼 (대표 반려동물이 아닐 때만 표시)
            if (!pet.isRepresentative) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    _setRepresentativePet(pet);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    side: BorderSide(
                      color: Colors.grey[400]!,
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    '대표 반려동물로 설정',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderAvatar() {
    return Container(
      color: Colors.teal.shade700,
      child: Center(
        child: Icon(
          Icons.pets,
          size: 30,
          color: Colors.white,
        ),
      ),
    );
  }

  void _setRepresentativePet(Pet pet) async {
    try {
      await FirestoreService.setRepresentativePet(widget.userId, pet.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${pet.name}을(를) 대표 반려동물로 설정했습니다'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('대표 반려동물 설정 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteDialog(Pet pet) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('반려동물 삭제'),
        content: Text('${pet.name}을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirestoreService.deletePet(pet.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('반려동물이 삭제되었습니다'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('삭제 실패: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}