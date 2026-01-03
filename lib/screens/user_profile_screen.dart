import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/storage_service.dart';

class UserProfileScreen extends StatefulWidget {
  final User user;
  final Function(User) onUserUpdate;

  const UserProfileScreen({
    super.key,
    required this.user,
    required this.onUserUpdate,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late User _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
  }

  void _editProfile() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('프로필 수정'),
        content: const Text('프로필 수정 기능을 구현해주세요.'),
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
                    '프로필',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.blue[100],
                          child: const Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _currentUser.nickname,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentUser.bio,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildStatItem(
                              '팔로워',
                              _currentUser.followers.toString(),
                            ),
                            const SizedBox(width: 32),
                            _buildStatItem(
                              '팔로잉',
                              _currentUser.following.toString(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _editProfile,
                          icon: const Icon(Icons.edit),
                          label: const Text('프로필 수정'),
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
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.location_on),
                    title: const Text('위치 공개'),
                    subtitle: Text(
                      _currentUser.locationPublic ? '공개' : '비공개',
                    ),
                    trailing: Switch(
                      value: _currentUser.locationPublic,
                      onChanged: (value) async {
                        setState(() {
                          _currentUser = _currentUser.copyWith(
                            locationPublic: value,
                          );
                        });
                        await StorageService.saveCurrentUser(_currentUser);
                        widget.onUserUpdate(_currentUser);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

