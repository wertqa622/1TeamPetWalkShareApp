import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../models/user.dart';
import '../services/storage_service.dart';
import '../services/follow_service.dart';
import '../services/block_service.dart';

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
  Set<String> _myFollowingIds = {};
  // 팔로잉 목록 (상태 유지)
  List<User> _followingList = [];

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _loadUserDataFromFirestore();
    _initializeFollowCounts();
  }

  Future<void> _loadUserDataFromFirestore() async {
    try {
      // Firestore에서 최신 사용자 데이터 로드
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.id)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        
        // createdAt 필드 처리
        String createdAtStr;
        if (data['createdAt'] != null) {
          if (data['createdAt'] is Timestamp) {
            createdAtStr = (data['createdAt'] as Timestamp).toDate().toIso8601String();
          } else {
            createdAtStr = data['createdAt'].toString();
          }
        } else {
          createdAtStr = _currentUser.createdAt;
        }

        if (mounted) {
          setState(() {
            _currentUser = User(
              id: _currentUser.id,
              email: data['email'] ?? _currentUser.email,
              nickname: data['nickname'] ?? _currentUser.nickname,
              bio: data['bio'] ?? _currentUser.bio,
              locationPublic: data['locationPublic'] ?? _currentUser.locationPublic,
              followers: (data['followers'] ?? _currentUser.followers) as int,
              following: (data['following'] ?? _currentUser.following) as int,
              createdAt: createdAtStr,
            );
          });
          widget.onUserUpdate(_currentUser);
        }
      }
    } catch (e) {
      debugPrint('사용자 데이터 로드 실패: $e');
    }
  }

  Future<void> _initializeFollowCounts() async {
    try {
      // Firestore에서 실제 팔로워/팔로잉 목록 가져오기
      final followers = await FollowService.getFollowers(_currentUser.id);
      final following = await FollowService.getFollowing(_currentUser.id);
      
      // 팔로잉 ID 목록 업데이트
      _myFollowingIds = following.map((user) => user.id).toSet();
      _followingList = following;

      // 팔로워/팔로잉 수 초기화
      if (mounted) {
        setState(() {
          _currentUser = _currentUser.copyWith(
            followers: followers.length,
            following: following.length,
          );
        });
        widget.onUserUpdate(_currentUser);
      }
    } catch (e) {
      debugPrint('팔로워/팔로잉 수 초기화 실패: $e');
      // 에러 발생 시 0으로 설정
      if (mounted) {
        setState(() {
          _currentUser = _currentUser.copyWith(
            followers: 0,
            following: 0,
          );
        });
        widget.onUserUpdate(_currentUser);
      }
    }
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

  Future<void> _performSearch(String query, StateSetter setModalState, Function(List<User>) onResults) async {
    if (query.isEmpty) {
      setModalState(() {
        onResults([]);
      });
      return;
    }

    try {
      // Firestore에서 모든 사용자 가져오기
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      final results = <User>[];
      
      for (final doc in snapshot.docs) {
        // 현재 사용자는 제외
        if (doc.id == _currentUser.id) continue;
        
        final data = doc.data();
        final nickname = data['nickname'] as String? ?? '';
        
        // 닉네임에 검색어가 포함되어 있는지 확인
        if (nickname.toLowerCase().contains(query.toLowerCase())) {
          // createdAt 필드 처리
          String createdAtStr;
          if (data['createdAt'] != null) {
            if (data['createdAt'] is Timestamp) {
              createdAtStr = (data['createdAt'] as Timestamp).toDate().toIso8601String();
            } else {
              createdAtStr = data['createdAt'].toString();
            }
          } else {
            createdAtStr = DateTime.now().toIso8601String();
          }

          results.add(User(
            id: doc.id,
            nickname: nickname,
            bio: data['bio'] ?? '',
            email: data['email'] ?? '',
            locationPublic: data['locationPublic'] ?? true,
            followers: (data['followers'] ?? 0) as int,
            following: (data['following'] ?? 0) as int,
            createdAt: createdAtStr,
          ));
        }
      }

      setModalState(() {
        onResults(results);
      });
    } catch (e) {
      debugPrint('검색 실패: $e');
      setModalState(() {
        onResults([]);
      });
    }
  }

  Future<void> _followUserFromSearch(User user, StateSetter setModalState) async {
    try {
      await FollowService.followUser(_currentUser.id, user.id);
      
      setModalState(() {
        _myFollowingIds.add(user.id);
        if (!_followingList.any((u) => u.id == user.id)) {
          _followingList.add(user);
        }
      });
      
      // 실제 팔로잉 수 가져오기
      final following = await FollowService.getFollowing(_currentUser.id);
      
      setState(() {
        _currentUser = _currentUser.copyWith(
          following: following.length,
        );
      });
      
      // Firestore에도 업데이트
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.id)
          .update({'following': following.length});
      
      widget.onUserUpdate(_currentUser);
      await StorageService.saveCurrentUser(_currentUser);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.nickname}님을 팔로우했습니다'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('팔로우 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('팔로우 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _unfollowUserFromSearch(User user, StateSetter setModalState) async {
    try {
      await FollowService.unfollowUser(_currentUser.id, user.id);
      
      setModalState(() {
        _myFollowingIds.remove(user.id);
        _followingList.removeWhere((u) => u.id == user.id);
      });
      
      // 실제 팔로잉 수 가져오기
      final following = await FollowService.getFollowing(_currentUser.id);
      
      setState(() {
        _currentUser = _currentUser.copyWith(
          following: following.length,
        );
      });
      
      // Firestore에도 업데이트
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.id)
          .update({'following': following.length});
      
      widget.onUserUpdate(_currentUser);
      await StorageService.saveCurrentUser(_currentUser);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.nickname}님을 언팔로우했습니다'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      debugPrint('언팔로우 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('언팔로우 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _blockUserFromSearch(User user, StateSetter setModalState, List<User> searchResults) async {
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
            onPressed: () async {
              try {
                Navigator.pop(context);
                
                // 팔로우 중이었다면 언팔로우
                final wasFollowing = _myFollowingIds.contains(user.id);
                if (wasFollowing) {
                  await FollowService.unfollowUser(_currentUser.id, user.id);
                  setModalState(() {
                    _myFollowingIds.remove(user.id);
                    _followingList.removeWhere((u) => u.id == user.id);
                  });
                  
                  // 실제 팔로잉 수 가져오기
                  final following = await FollowService.getFollowing(_currentUser.id);
                  setState(() {
                    _currentUser = _currentUser.copyWith(
                      following: following.length,
                    );
                  });
                  
                  // Firestore에도 업데이트
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(_currentUser.id)
                      .update({'following': following.length});
                }
                
                // 차단 실행
                await BlockService.blockUser(_currentUser.id, user.id);
                
                // 검색 결과에서 제거
                setModalState(() {
                  searchResults.removeWhere((u) => u.id == user.id);
                });
                
                widget.onUserUpdate(_currentUser);
                await StorageService.saveCurrentUser(_currentUser);
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${user.nickname}님을 차단했습니다'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } catch (e) {
                debugPrint("차단 처리 오류: $e");
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('차단 처리 중 오류가 발생했습니다: $e'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              }
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

  // 로그아웃 확인 다이얼로그
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // 팝업 닫기
              try {
                // [수정됨] 별명(auth)을 사용해서 로그아웃 호출
                await auth.FirebaseAuth.instance.signOut();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('로그아웃 실패: $e')),
                  );
                }
              }
            },
            child: const Text(
              '로그아웃',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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
                        
                        try {
                          // Firestore에 저장
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(_currentUser.id)
                              .update({
                            'nickname': updatedUser.nickname,
                            'bio': updatedUser.bio,
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
                        } catch (e) {
                          debugPrint('프로필 수정 실패: $e');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('프로필 수정 실패: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
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
                            // 팔로워 수를 실시간으로 감시
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(_currentUser.id)
                                  .collection('followers')
                                  .snapshots(),
                              builder: (context, snapshot) {
                                final followerCount = snapshot.hasData 
                                    ? snapshot.data!.docs.where((doc) => doc.id != '.init').length
                                    : _currentUser.followers;
                                
                                // 상태 업데이트 (다른 곳에서도 사용할 수 있도록)
                                if (snapshot.hasData && mounted) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (_currentUser.followers != followerCount) {
                                      setState(() {
                                        _currentUser = _currentUser.copyWith(
                                          followers: followerCount,
                                        );
                                      });
                                      widget.onUserUpdate(_currentUser);
                                    }
                                  });
                                }
                                
                                return _buildStatItem(
                                  '팔로워',
                                  followerCount.toString(),
                                  _showFollowersModal,
                                );
                              },
                            ),
                            const SizedBox(width: 32),
                            // 팔로잉 수를 실시간으로 감시
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(_currentUser.id)
                                  .collection('following')
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return _buildStatItem(
                                    '팔로잉',
                                    _currentUser.following.toString(),
                                    _showFollowingModal,
                                  );
                                }
                                
                                if (snapshot.hasError) {
                                  debugPrint('팔로잉 StreamBuilder 오류: ${snapshot.error}');
                                  return _buildStatItem(
                                    '팔로잉',
                                    _currentUser.following.toString(),
                                    _showFollowingModal,
                                  );
                                }
                                
                                final followingCount = snapshot.hasData 
                                    ? snapshot.data!.docs.where((doc) => doc.id != '.init').length
                                    : _currentUser.following;
                                
                                debugPrint('팔로잉 StreamBuilder 업데이트: ${_currentUser.id}의 팔로잉 수 = $followingCount (이전: ${_currentUser.following})');
                                
                                // 상태 업데이트 (다른 곳에서도 사용할 수 있도록)
                                if (snapshot.hasData && mounted) {
                                  if (_currentUser.following != followingCount) {
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      if (mounted && _currentUser.following != followingCount) {
                                        setState(() {
                                          _currentUser = _currentUser.copyWith(
                                            following: followingCount,
                                          );
                                        });
                                        widget.onUserUpdate(_currentUser);
                                        debugPrint('팔로잉 수 상태 업데이트 완료: $followingCount');
                                      }
                                    });
                                  }
                                }
                                
                                return _buildStatItem(
                                  '팔로잉',
                                  followingCount.toString(),
                                  _showFollowingModal,
                                );
                              },
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
                        try {
                          // Firestore에 저장
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(_currentUser.id)
                              .update({
                            'locationPublic': value,
                          });
                          
                          await StorageService.saveCurrentUser(_currentUser);
                          widget.onUserUpdate(_currentUser);
                        } catch (e) {
                          debugPrint('위치 공개 설정 실패: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('위치 공개 설정 실패: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),

                  // 로그아웃 버튼 영역
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(),
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      '로그아웃',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                    ),
                    onTap: _showLogoutDialog, // 로그아웃 다이얼로그 호출
                  ),
                  const SizedBox(height: 40),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FutureBuilder<List<User>>(
          future: FollowService.getFollowers(_currentUser.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.7,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: const Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.7,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Center(child: Text('오류 발생: ${snapshot.error}')),
              );
            }

            final followers = snapshot.data ?? [];

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
                                
                                return FutureBuilder<bool>(
                                  future: FollowService.isFollowing(_currentUser.id, user.id),
                                  builder: (context, followingSnapshot) {
                                    final isFollowing = followingSnapshot.data ?? false;
                                    
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
                                                onPressed: () async {
                                                  await _followUserFromSearch(user, setModalState);
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
      },
    );
  }

  Future<void> _unfollowUser(User user, StateSetter setModalState) async {
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
            onPressed: () async {
              try {
                Navigator.pop(context);
                
                // 언팔로우 처리
                await FollowService.unfollowUser(_currentUser.id, user.id);
                
                setModalState(() {
                  _myFollowingIds.remove(user.id);
                  _followingList.removeWhere((u) => u.id == user.id);
                });
                
                // 실제 팔로잉 수 가져오기
                final following = await FollowService.getFollowing(_currentUser.id);
                
                setState(() {
                  _currentUser = _currentUser.copyWith(
                    following: following.length,
                  );
                });
                
                // Firestore에도 업데이트
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(_currentUser.id)
                    .update({'following': following.length});
                
                widget.onUserUpdate(_currentUser);
                await StorageService.saveCurrentUser(_currentUser);
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${user.nickname}님을 언팔로우했습니다'),
                      backgroundColor: Colors.blue,
                    ),
                  );
                }
              } catch (e) {
                debugPrint('언팔로우 실패: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('언팔로우 실패: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
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

  Future<void> _blockUser(User user, StateSetter setModalState, List<User> userList, {required bool isFollowersList}) async {
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
            onPressed: () async {
              try {
                Navigator.pop(context);
                
                // 팔로우 중이었다면 언팔로우
                final wasFollowing = _myFollowingIds.contains(user.id);
                if (wasFollowing) {
                  await FollowService.unfollowUser(_currentUser.id, user.id);
                  setModalState(() {
                    _myFollowingIds.remove(user.id);
                    _followingList.removeWhere((u) => u.id == user.id);
                  });
                  
                  // 실제 팔로잉 수 가져오기
                  final following = await FollowService.getFollowing(_currentUser.id);
                  setState(() {
                    _currentUser = _currentUser.copyWith(
                      following: following.length,
                    );
                  });
                  
                  // Firestore에도 업데이트
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(_currentUser.id)
                      .update({'following': following.length});
                }
                
                // 차단 실행
                await BlockService.blockUser(_currentUser.id, user.id);
                
                // 팔로워/팔로잉 수 업데이트
                if (isFollowersList) {
                  // 팔로워 목록에서 제거
                  final followers = await FollowService.getFollowers(_currentUser.id);
                  setState(() {
                    _currentUser = _currentUser.copyWith(
                      followers: followers.length,
                    );
                  });
                  
                  // Firestore에도 업데이트
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(_currentUser.id)
                      .update({'followers': followers.length});
                }
                
                // 목록에서 제거
                setModalState(() {
                  userList.removeWhere((u) => u.id == user.id);
                });
                
                widget.onUserUpdate(_currentUser);
                await StorageService.saveCurrentUser(_currentUser);
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${user.nickname}님을 차단했습니다'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } catch (e) {
                debugPrint("차단 처리 오류: $e");
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('차단 처리 중 오류가 발생했습니다: $e'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              }
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FutureBuilder<List<User>>(
          future: FollowService.getFollowing(_currentUser.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.7,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: const Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.7,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Center(child: Text('오류 발생: ${snapshot.error}')),
              );
            }

            final following = snapshot.data ?? [];

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
                      child: following.isEmpty
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
                              itemCount: following.length,
                              itemBuilder: (context, index) {
                                final user = following[index];
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
                                            _blockUser(user, setModalState, following, isFollowersList: false);
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
      },
    );
  }
}

