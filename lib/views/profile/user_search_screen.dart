import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/social_viewmodel.dart';
import 'other_user_profile_screen.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // 화면 진입 시 검색 결과 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SocialViewModel>().clearSearchResults();
    });
  }

  void _onSearch() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      context.read<SocialViewModel>().searchUsers(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '닉네임 검색...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey),
          ),
          style: const TextStyle(fontSize: 18),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _onSearch(),
        ),
        actions: [
          IconButton(
            onPressed: _onSearch,
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: Consumer<SocialViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (viewModel.searchResults.isEmpty) {
            // 검색어가 있는데 결과가 없는 경우와, 처음 진입한 경우 구분 가능
            // 여기서는 단순하게 처리
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    _searchController.text.isEmpty 
                        ? '닉네임을 입력하여 친구를 찾아보세요'
                        : '검색 결과가 없습니다',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: viewModel.searchResults.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final socialUser = viewModel.searchResults[index];
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
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OtherUserProfileScreen(
                        socialUser: socialUser,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

