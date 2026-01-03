import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/social_user.dart';
import '../../viewmodels/social_viewmodel.dart';
import '../../viewmodels/user_viewmodel.dart';

enum SocialListType { followers, following }

class SocialListScreen extends StatefulWidget {
  final SocialListType type;
  final String userId;

  const SocialListScreen({
    super.key,
    required this.type,
    required this.userId,
  });

  @override
  State<SocialListScreen> createState() => _SocialListScreenState();
}

class _SocialListScreenState extends State<SocialListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<SocialViewModel>();
      if (widget.type == SocialListType.followers) {
        viewModel.loadFollowers(widget.userId);
      } else {
        viewModel.loadFollowing(widget.userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.type == SocialListType.followers ? '팔로워' : '팔로잉'),
      ),
      body: Consumer<SocialViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final List<SocialUser> users = widget.type == SocialListType.followers
              ? viewModel.followers
              : viewModel.following;

          if (users.isEmpty) {
            return Center(
              child: Text(
                widget.type == SocialListType.followers
                    ? '팔로워가 없습니다.'
                    : '팔로잉하는 사용자가 없습니다.',
                style: TextStyle(color: Colors.grey[600]),
              ),
            );
          }

          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final socialUser = users[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Text(socialUser.user.nickname[0]),
                ),
                title: Text(socialUser.user.nickname),
                subtitle: Text(
                  socialUser.user.bio,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 팔로워 목록: 나만 팔로우 당함(맞팔X) -> '맞팔로우' 버튼 표시
                    // 팔로워 목록: 서로 팔로우 -> 버튼 없음
                    // 팔로잉 목록: 내가 팔로우 중 -> '언팔로우' 버튼 표시
                    if (!socialUser.isBlocked)
                      _buildActionButton(context, viewModel, socialUser),
                    
                    // 더보기 메뉴 (삭제, 차단 등)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'block') {
                          _showBlockConfirmDialog(context, socialUser);
                        } else if (value == 'remove') {
                          _showRemoveFollowerDialog(context, socialUser);
                        }
                      },
                      itemBuilder: (BuildContext context) {
                        final List<PopupMenuEntry<String>> menuItems = [];
                        
                        // 팔로워 목록일 때만 '삭제' 메뉴 추가
                        if (widget.type == SocialListType.followers) {
                          menuItems.add(
                            const PopupMenuItem(
                              value: 'remove',
                              child: Text('삭제', style: TextStyle(color: Colors.red)),
                            ),
                          );
                        }
                        
                        menuItems.add(
                          const PopupMenuItem(
                            value: 'block',
                            child: Text('차단하기', style: TextStyle(color: Colors.red)),
                          ),
                        );
                        
                        return menuItems;
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, SocialViewModel viewModel, SocialUser socialUser) {
    final myId = context.read<UserViewModel>().user!.id;

    if (widget.type == SocialListType.followers) {
      // 팔로워 목록 로직
      if (!socialUser.isFollowing) {
        // 내가 아직 팔로우하지 않은 상태 -> 맞팔로우 버튼
        return TextButton(
          onPressed: () {
            viewModel.toggleFollow(myId, socialUser);
          },
          child: const Text(
            '맞팔로우',
            style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
          ),
        );
      } else {
        // 이미 맞팔로우 상태 -> 버튼 없음 (빈 공간)
        return const SizedBox.shrink();
      }
    } else {
      // 팔로잉 목록 로직 -> 언팔로우 버튼 (기존 유지)
      return TextButton(
        onPressed: () {
          viewModel.toggleFollow(myId, socialUser);
        },
        child: const Text(
          '언팔로우',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
  }

  void _showRemoveFollowerDialog(BuildContext context, SocialUser socialUser) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${socialUser.user.nickname}님을 팔로워에서 삭제하시겠습니까?'),
        content: const Text('상대방이 더 이상 회원님의 소식을 볼 수 없게 됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              final myId = context.read<UserViewModel>().user!.id;
              context.read<SocialViewModel>().removeFollower(myId, socialUser);
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('팔로워를 삭제했습니다.')),
              );
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showBlockConfirmDialog(BuildContext context, SocialUser socialUser) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${socialUser.user.nickname}님을 차단하시겠습니까?'),
        content: const Text('차단하면 서로의 게시물을 볼 수 없으며, 차단 해제는 설정에서 가능합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              final myId = context.read<UserViewModel>().user!.id;
              context.read<SocialViewModel>().blockUser(myId, socialUser);
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('사용자를 차단했습니다.')),
              );
            },
            child: const Text('차단', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
