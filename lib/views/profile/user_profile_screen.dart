import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/user_viewmodel.dart';
import 'edit_profile_screen.dart';
import 'social_list_screen.dart';
import 'user_search_screen.dart';
import '../../services/storage_service.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  @override
  void initState() {
    super.initState();
    // 화면 진입 시 사용자 정보 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserViewModel>().loadUser();
    });
  }

  void _editProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = viewModel.user;
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('사용자 정보를 불러올 수 없습니다.')),
          );
        }

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
                              user.nickname,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              user.bio,
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
                                GestureDetector(
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SocialListScreen(
                                          type: SocialListType.followers,
                                          userId: user.id,
                                        ),
                                      ),
                                    );
                                    // 화면 복귀 시 사용자 정보(팔로워 수 등) 갱신
                                    if (context.mounted) {
                                      context.read<UserViewModel>().loadUser();
                                    }
                                  },
                                  child: _buildStatItem(
                                    '팔로워',
                                    user.followers.toString(),
                                  ),
                                ),
                                const SizedBox(width: 32),
                                GestureDetector(
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SocialListScreen(
                                          type: SocialListType.following,
                                          userId: user.id,
                                        ),
                                      ),
                                    );
                                    // 화면 복귀 시 사용자 정보(팔로잉 수 등) 갱신
                                    if (context.mounted) {
                                      context.read<UserViewModel>().loadUser();
                                    }
                                  },
                                  child: _buildStatItem(
                                    '팔로잉',
                                    user.following.toString(),
                                  ),
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
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const UserSearchScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.search),
                              label: const Text('프로필 검색'),
                              style: OutlinedButton.styleFrom(
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
                          user.locationPublic ? '공개' : '비공개',
                        ),
                        trailing: Switch(
                          value: user.locationPublic,
                          onChanged: (value) async {
                            // TODO: ViewModel에 위치 공개 설정 업데이트 기능 추가 필요
                            // 현재는 임시로 StorageService 직접 호출 (나중에 리팩토링 대상)
                            final updatedUser = user.copyWith(locationPublic: value);
                            await StorageService.saveCurrentUser(updatedUser);
                            viewModel.loadUser(); // 정보 갱신
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
      },
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
