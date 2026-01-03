import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/social_user.dart';
import '../../viewmodels/social_viewmodel.dart';
import '../../viewmodels/user_viewmodel.dart';
import '../../viewmodels/walk_viewmodel.dart';

class OtherUserProfileScreen extends StatefulWidget {
  final SocialUser socialUser;

  const OtherUserProfileScreen({
    super.key,
    required this.socialUser,
  });

  @override
  State<OtherUserProfileScreen> createState() => _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState extends State<OtherUserProfileScreen> {
  @override
  void initState() {
    super.initState();
    // 화면 진입 시 산책 기록 로드 (차단 여부 확인 포함)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final myId = context.read<UserViewModel>().user!.id;
      final targetId = widget.socialUser.user.id;
      context.read<WalkViewModel>().loadUserWalks(targetId, myId);
    });
  }

  @override
  Widget build(BuildContext context) {
    // ViewModel에서 최신 상태의 SocialUser 객체를 가져오기 위해 Consumer 사용은 리스트 갱신 시 필요하지만,
    // 여기서는 단일 객체의 상태 변화(팔로우 여부)를 반영해야 함.
    // 간단하게 ViewModel의 상태를 구독하여 UI 갱신.
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.socialUser.user.nickname),
      ),
      body: Consumer<SocialViewModel>(
        builder: (context, viewModel, child) {
          // 리스트 내 객체와 현재 화면의 객체 동기화 (간단한 방법)
          // 실제로는 ID로 검색해서 최신 상태를 가져오는 것이 좋음
          final currentUserState = widget.socialUser; 

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 32),
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
                  currentUserState.user.nickname,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  currentUserState.user.bio,
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
                    _buildStatItem('팔로워', currentUserState.user.followers.toString()),
                    const SizedBox(width: 32),
                    _buildStatItem('팔로잉', currentUserState.user.following.toString()),
                  ],
                ),
                const SizedBox(height: 32),
                
                // 팔로우/언팔로우 버튼
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final myId = context.read<UserViewModel>().user!.id;
                        viewModel.toggleFollow(myId, currentUserState);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: currentUserState.isFollowing 
                            ? Colors.grey[300] 
                            : Colors.blue,
                        foregroundColor: currentUserState.isFollowing 
                            ? Colors.black 
                            : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        currentUserState.isFollowing ? '언팔로우' : '팔로우',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                const Divider(),
                
                // 산책 기록 목록 (차단 시 표시 안 함)
                Consumer<WalkViewModel>(
                  builder: (context, walkViewModel, child) {
                    if (walkViewModel.isLoading) {
                      return const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (walkViewModel.error == 'blocked') {
                      return Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(Icons.block, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              '접근 권한이 없습니다.',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      );
                    }

                    final walks = walkViewModel.walks;
                    if (walks.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(
                          '아직 산책 기록이 없습니다.',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: walks.length,
                      itemBuilder: (context, index) {
                        final walk = walks[index];
                        return ListTile(
                          leading: const Icon(Icons.directions_walk),
                          title: Text('${walk.createdAt.substring(0, 10)} 산책'),
                          subtitle: Text(
                            '${(walk.distance ?? 0 / 1000).toStringAsFixed(1)}km • ${walk.duration ?? 0 ~/ 60}분',
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
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

