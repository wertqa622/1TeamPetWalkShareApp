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
  // 내가 팔로우 중인 사용자 ID 목록 (상태 유지)
  final Set<String> _myFollowingIds = {'4', '5'}; // TODO: 실제 데이터로 교체
  // 팔로잉 목록 (상태 유지)
  List<User> _followingList = []; // TODO: 실제 데이터로 교체

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _initializeFollowCounts();
  }

  void _initializeFollowCounts() {
    // 팔로워 목록 가져오기 (TODO: 실제 데이터로 교체)
    final followers = <User>[
      User(
        id: '2',
        nickname: '강아지조아',
        bio: '강아지와 함께하는 일상',
        locationPublic: true,
        followers: 5,
        following: 3,
        createdAt: DateTime.now().toIso8601String(),
      ),
      User(
        id: '3',
        nickname: '냥냥펀치',
        bio: '고양이도 좋아해요',
        locationPublic: true,
        followers: 8,
        following: 5,
        createdAt: DateTime.now().toIso8601String(),
      ),
    ];

    // 초기 팔로잉 목록 설정
    if (_followingList.isEmpty) {
      _followingList = [
        User(
          id: '4',
          nickname: '산책마스터',
          bio: '매일 산책하는 것이 취미입니다',
          locationPublic: true,
          followers: 15,
          following: 10,
          createdAt: DateTime.now().toIso8601String(),
        ),
        User(
          id: '5',
          nickname: '펫러버',
          bio: '반려동물과 함께하는 삶',
          locationPublic: true,
          followers: 20,
          following: 12,
          createdAt: DateTime.now().toIso8601String(),
        ),
      ];
    }

    // 팔로워/팔로잉 수 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _currentUser = _currentUser.copyWith(
            followers: followers.length,
            following: _myFollowingIds.length,
          );
        });
        widget.onUserUpdate(_currentUser);
      }
    });
  }

  void _showSearchModal() {
    final searchController = TextEditingController();
    List<User> searchResults = [];
    bool isSearching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // 헤더
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '프로필 검색',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 검색 입력 필드
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: '닉네임을 입력하세요',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              searchController.clear();
                              setModalState(() {
                                searchResults = [];
                                isSearching = false;
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    setModalState(() {
                      if (value.trim().isEmpty) {
                        searchResults = [];
                        isSearching = false;
                      }
                    });
                  },
                  onSubmitted: (value) {
                    _performSearch(value.trim(), setModalState, (results) {
                      setModalState(() {
                        searchResults = results;
                        isSearching = true;
                      });
                    });
                  },
                ),
              ),
              // 검색 결과
              Expanded(
                child: isSearching
                    ? searchResults.isEmpty
                        ? Center(
                            child: Text(
                              '검색 결과가 없습니다',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: searchResults.length,
                            itemBuilder: (context, index) {
                              final user = searchResults[index];
                              final isFollowing = _myFollowingIds.contains(user.id);
                              
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 8.0,
                                ),
                                child: Row(
                                  children: [
                                    // 프로필 이미지
                                    CircleAvatar(
                                      backgroundColor: Colors.blue[100],
                                      child: const Icon(
                                        Icons.person,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // 사용자 정보
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            user.nickname,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            user.bio,
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    // 팔로우/언팔로우 버튼
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: ElevatedButton(
                                        onPressed: () {
                                          if (isFollowing) {
                                            _unfollowUserFromSearch(user, setModalState);
                                          } else {
                                            _followUserFromSearch(user, setModalState);
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isFollowing
                                              ? Colors.grey[300]
                                              : const Color(0xFF2563EB),
                                          foregroundColor: isFollowing
                                              ? Colors.black
                                              : Colors.white,
                                        ),
                                        child: Text(isFollowing ? '언팔로우' : '팔로우'),
                                      ),
                                    ),
                                    // 점3개 메뉴
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onSelected: (value) {
                                        if (value == 'block') {
                                          _blockUserFromSearch(user, setModalState, searchResults);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'block',
                                          child: Row(
                                            children: [
                                              Icon(Icons.block, color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('차단하기', style: TextStyle(color: Colors.red)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          )
                    : Center(
                        child: Text(
                          '닉네임을 입력하고 검색해주세요',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _performSearch(String query, StateSetter setModalState, Function(List<User>) onResults) {
    if (query.isEmpty) {
      setModalState(() {
        onResults([]);
      });
      return;
    }

    // TODO: 실제 검색 로직으로 교체 필요 (Firestore 등)
    // 현재는 더미 데이터로 검색
    final allUsers = <User>[
      User(
        id: '2',
        nickname: '강아지조아',
        bio: '강아지와 함께하는 일상',
        locationPublic: true,
        followers: 5,
        following: 3,
        createdAt: DateTime.now().toIso8601String(),
      ),
      User(
        id: '3',
        nickname: '냥냥펀치',
        bio: '고양이도 좋아해요',
        locationPublic: true,
        followers: 8,
        following: 5,
        createdAt: DateTime.now().toIso8601String(),
      ),
      User(
        id: '4',
        nickname: '산책마스터',
        bio: '매일 산책하는 것이 취미입니다',
        locationPublic: true,
        followers: 15,
        following: 10,
        createdAt: DateTime.now().toIso8601String(),
      ),
      User(
        id: '5',
        nickname: '펫러버',
        bio: '반려동물과 함께하는 삶',
        locationPublic: true,
        followers: 20,
        following: 12,
        createdAt: DateTime.now().toIso8601String(),
      ),
    ];

    final results = allUsers
        .where((user) => user.nickname.toLowerCase().contains(query.toLowerCase()))
        .toList();

    setModalState(() {
      onResults(results);
    });
  }

  void _followUserFromSearch(User user, StateSetter setModalState) {
    setModalState(() {
      _myFollowingIds.add(user.id);
      if (!_followingList.any((u) => u.id == user.id)) {
        _followingList.add(user);
      }
    });
    // 팔로잉 수 업데이트
    setState(() {
      _currentUser = _currentUser.copyWith(
        following: _currentUser.following + 1,
      );
    });
    widget.onUserUpdate(_currentUser);
    // Storage에 저장
    StorageService.saveCurrentUser(_currentUser);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${user.nickname}님을 팔로우했습니다'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _unfollowUserFromSearch(User user, StateSetter setModalState) {
    setModalState(() {
      _myFollowingIds.remove(user.id);
      _followingList.removeWhere((u) => u.id == user.id);
    });
    // 팔로잉 수 업데이트
    setState(() {
      _currentUser = _currentUser.copyWith(
        following: _currentUser.following - 1,
      );
    });
    widget.onUserUpdate(_currentUser);
    // Storage에 저장
    StorageService.saveCurrentUser(_currentUser);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${user.nickname}님을 언팔로우했습니다'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _blockUserFromSearch(User user, StateSetter setModalState, List<User> searchResults) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('차단하기'),
        content: Text('${user.nickname}님을 차단하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              // 팔로잉 수 업데이트 (팔로우 중이었다면)
              final wasFollowing = _myFollowingIds.contains(user.id);
              if (wasFollowing) {
                setState(() {
                  _currentUser = _currentUser.copyWith(
                    following: _currentUser.following - 1,
                  );
                });
              }
              // 차단 처리
              setModalState(() {
                searchResults.remove(user);
                _myFollowingIds.remove(user.id);
                _followingList.removeWhere((u) => u.id == user.id);
              });
              widget.onUserUpdate(_currentUser);
              // Storage에 저장
              StorageService.saveCurrentUser(_currentUser);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${user.nickname}님을 차단했습니다'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: const Text(
              '차단',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _editProfile() {
    final nicknameController = TextEditingController(text: _currentUser.nickname);
    final bioController = TextEditingController(text: _currentUser.bio);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '프로필 수정',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 16),
                // 닉네임 입력 필드
                TextFormField(
                  controller: nicknameController,
                  decoration: InputDecoration(
                    labelText: '닉네임',
                    hintText: '닉네임을 입력하세요',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '닉네임을 입력해주세요';
                    }
                    if (value.trim().length > 20) {
                      return '닉네임은 20자 이하여야 합니다';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // 한줄소개 입력 필드
                TextFormField(
                  controller: bioController,
                  decoration: InputDecoration(
                    labelText: '한줄소개',
                    hintText: '자신을 소개해주세요',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.description),
                  ),
                  maxLines: 3,
                  maxLength: 100,
                  validator: (value) {
                    if (value != null && value.trim().length > 100) {
                      return '한줄소개는 100자 이하여야 합니다';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // 저장 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        final updatedUser = _currentUser.copyWith(
                          nickname: nicknameController.text.trim(),
                          bio: bioController.text.trim(),
                        );
                        
                        setState(() {
                          _currentUser = updatedUser;
                        });
                        
                        await StorageService.saveCurrentUser(updatedUser);
                        widget.onUserUpdate(updatedUser);
                        
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('프로필이 수정되었습니다'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      '저장',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
                              _showFollowersModal,
                            ),
                            const SizedBox(width: 32),
                            _buildStatItem(
                              '팔로잉',
                              _currentUser.following.toString(),
                              _showFollowingModal,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
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
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _showSearchModal,
                              icon: const Icon(Icons.search),
                              label: const Text('프로필 검색'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
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

  Widget _buildStatItem(String label, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
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
      ),
    );
  }

  void _showFollowersModal() {
    // TODO: 실제 팔로워 데이터를 가져오는 로직으로 교체 필요
    final followers = <User>[
      User(
        id: '2',
        nickname: '강아지조아',
        bio: '강아지와 함께하는 일상',
        locationPublic: true,
        followers: 5,
        following: 3,
        createdAt: DateTime.now().toIso8601String(),
      ),
      User(
        id: '3',
        nickname: '냥냥펀치',
        bio: '고양이도 좋아해요',
        locationPublic: true,
        followers: 8,
        following: 5,
        createdAt: DateTime.now().toIso8601String(),
      ),
    ];

    // 팔로워 수는 실제 데이터 길이로 업데이트
    final newFollowersCount = followers.length;
    if (_currentUser.followers != newFollowersCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _currentUser = _currentUser.copyWith(followers: newFollowersCount);
        });
        widget.onUserUpdate(_currentUser);
      });
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // 헤더
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '팔로워',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 1),
              // 목록
              Expanded(
                child: followers.isEmpty
                    ? Center(
                        child: Text(
                          '팔로워가 없습니다',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: followers.length,
                        itemBuilder: (context, index) {
                          final user = followers[index];
                          final isFollowing = _myFollowingIds.contains(user.id);
                          
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Row(
                              children: [
                                // 프로필 이미지
                                CircleAvatar(
                                  backgroundColor: Colors.blue[100],
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // 사용자 정보
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.nickname,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        user.bio,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                // 맞팔로우 버튼 (팔로우하지 않은 경우만 표시)
                                if (!isFollowing)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: TextButton(
                                      onPressed: () {
                                        // TODO: 실제 팔로우 로직 구현
                                        setModalState(() {
                                          _myFollowingIds.add(user.id);
                                          // 팔로잉 목록에 추가 (중복 체크)
                                          if (!_followingList.any((u) => u.id == user.id)) {
                                            _followingList.add(user);
                                          }
                                        });
                                        // 팔로잉 수 업데이트
                                        setState(() {
                                          _currentUser = _currentUser.copyWith(
                                            following: _currentUser.following + 1,
                                          );
                                        });
                                        widget.onUserUpdate(_currentUser);
                                        // Storage에 저장
                                        StorageService.saveCurrentUser(_currentUser);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('${user.nickname}님을 팔로우했습니다'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      },
                                      child: const Text('맞팔로우'),
                                    ),
                                  ),
                                // 점3개 메뉴 (헤더 x버튼과 같은 높이)
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onSelected: (value) {
                                    if (value == 'block') {
                                      _blockUser(user, setModalState, followers, isFollowersList: true);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'block',
                                      child: Row(
                                        children: [
                                          Icon(Icons.block, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('차단하기', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        );
      },
    );
  }

  void _unfollowUser(User user, StateSetter setModalState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('언팔로우'),
        content: Text('${user.nickname}님을 언팔로우하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              // 언팔로우 처리
              setModalState(() {
                _myFollowingIds.remove(user.id);
                _followingList.removeWhere((u) => u.id == user.id);
              });
              // 팔로잉 수 업데이트
              setState(() {
                _currentUser = _currentUser.copyWith(
                  following: _currentUser.following - 1,
                );
              });
              widget.onUserUpdate(_currentUser);
              // Storage에 저장
              StorageService.saveCurrentUser(_currentUser);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${user.nickname}님을 언팔로우했습니다'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            child: const Text(
              '언팔로우',
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  void _blockUser(User user, StateSetter setModalState, List<User> userList, {required bool isFollowersList}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('차단하기'),
        content: Text('${user.nickname}님을 차단하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              // TODO: 실제 차단 로직 구현
              setModalState(() {
                userList.remove(user);
              });
              // 팔로워/팔로잉 수 업데이트
              setState(() {
                if (isFollowersList) {
                  _currentUser = _currentUser.copyWith(followers: userList.length);
                } else {
                  _currentUser = _currentUser.copyWith(following: userList.length);
                  // 팔로잉 목록에서 제거된 경우 _myFollowingIds와 _followingList에서도 제거
                  _myFollowingIds.remove(user.id);
                  _followingList.removeWhere((u) => u.id == user.id);
                }
              });
              widget.onUserUpdate(_currentUser);
              // Storage에 저장
              StorageService.saveCurrentUser(_currentUser);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${user.nickname}님을 차단했습니다'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: const Text(
              '차단',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showFollowingModal() {
    // TODO: 실제 팔로잉 데이터를 가져오는 로직으로 교체 필요
    // 초기 팔로잉 목록 설정 (한 번만)
    if (_followingList.isEmpty) {
      _followingList = [
        User(
          id: '4',
          nickname: '산책마스터',
          bio: '매일 산책하는 것이 취미입니다',
          locationPublic: true,
          followers: 15,
          following: 10,
          createdAt: DateTime.now().toIso8601String(),
        ),
        User(
          id: '5',
          nickname: '펫러버',
          bio: '반려동물과 함께하는 삶',
          locationPublic: true,
          followers: 20,
          following: 12,
          createdAt: DateTime.now().toIso8601String(),
        ),
      ];
    }

    // _myFollowingIds에 있는 모든 사용자가 _followingList에 있는지 확인하고 추가
    // 팔로워에서 맞팔로우한 사용자도 포함되도록
    for (final followingId in _myFollowingIds) {
      if (!_followingList.any((user) => user.id == followingId)) {
        // 팔로워 목록에서 찾기
        final followers = [
          User(
            id: '2',
            nickname: '강아지조아',
            bio: '강아지와 함께하는 일상',
            locationPublic: true,
            followers: 5,
            following: 3,
            createdAt: DateTime.now().toIso8601String(),
          ),
          User(
            id: '3',
            nickname: '냥냥펀치',
            bio: '고양이도 좋아해요',
            locationPublic: true,
            followers: 8,
            following: 5,
            createdAt: DateTime.now().toIso8601String(),
          ),
        ];
        final userFromFollowers = followers.firstWhere(
          (user) => user.id == followingId,
          orElse: () => User(
            id: followingId,
            nickname: '사용자 $followingId',
            bio: '',
            locationPublic: true,
            followers: 0,
            following: 0,
            createdAt: DateTime.now().toIso8601String(),
          ),
        );
        _followingList.add(userFromFollowers);
      }
    }

    // _myFollowingIds에 없는 사용자는 _followingList에서 제거
    _followingList.removeWhere((user) => !_myFollowingIds.contains(user.id));

    // 팔로잉 수는 _myFollowingIds의 개수로 업데이트
    final newFollowingCount = _myFollowingIds.length;
    if (_currentUser.following != newFollowingCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _currentUser = _currentUser.copyWith(following: newFollowingCount);
        });
        widget.onUserUpdate(_currentUser);
      });
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // 헤더
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '팔로잉',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 1),
              // 목록
              Expanded(
                child: _followingList.isEmpty
                    ? Center(
                        child: Text(
                          '팔로잉한 사용자가 없습니다',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _followingList.length,
                        itemBuilder: (context, index) {
                          final user = _followingList[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Row(
                              children: [
                                // 프로필 이미지
                                CircleAvatar(
                                  backgroundColor: Colors.blue[100],
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // 사용자 정보
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.nickname,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        user.bio,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                // 점3개 메뉴 (헤더 x버튼과 같은 높이)
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onSelected: (value) {
                                    if (value == 'unfollow') {
                                      _unfollowUser(user, setModalState);
                                    } else if (value == 'block') {
                                      _blockUser(user, setModalState, _followingList, isFollowersList: false);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'unfollow',
                                      child: Row(
                                        children: [
                                          Icon(Icons.person_remove, color: Colors.blue),
                                          SizedBox(width: 8),
                                          Text('언팔로우'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'block',
                                      child: Row(
                                        children: [
                                          Icon(Icons.block, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('차단하기', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        );
      },
    );
  }
}

