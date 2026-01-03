import 'package:flutter/material.dart';
import '../models/pet.dart';

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
    // TODO: 실제 데이터 로드 구현
    setState(() {
      _pets = [];
    });
  }

  void _addPet() {
    // TODO: 반려동물 추가 기능 구현
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('반려동물 추가'),
        content: const Text('반려동물 추가 기능을 구현해주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
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


