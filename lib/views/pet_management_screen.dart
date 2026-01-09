import 'package:flutter/material.dart';
import '../models/pet.dart';
import '../services/pet_storage_service.dart';
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



