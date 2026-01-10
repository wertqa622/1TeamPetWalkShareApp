import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/user.dart';
import '../models/walk.dart';
import '../services/walk_service.dart';

class SocialFeedScreen extends StatefulWidget {
  final User currentUser;

  const SocialFeedScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends State<SocialFeedScreen> {
  List<Walk> _walks = [];
  Map<String, User> _userMap = {}; // userId -> User 매핑
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Firestore에서 모든 walks 가져오기 (최근 순으로 정렬)
      final walksSnapshot = await FirebaseFirestore.instance
          .collection('walks')
          .orderBy('startTime', descending: true)
          .limit(50) // 최근 50개만 가져오기
          .get();

      // 차단 필터링 적용
      final filteredWalks = await WalkService.filterBlockedUsersWalks(
        walksSnapshot.docs,
        widget.currentUser.id,
      );

      // walks의 작성자 정보 가져오기
      final userIds = filteredWalks.map((walk) => walk.userId).toSet();
      final userMap = <String, User>{};

      for (final userId in userIds) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
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
              createdAtStr = DateTime.now().toIso8601String();
            }

            userMap[userId] = User(
              id: userId,
              nickname: data['nickname'] ?? '사용자',
              bio: data['bio'] ?? '',
              email: data['email'] ?? '',
              locationPublic: data['locationPublic'] ?? true,
              followers: (data['followers'] ?? 0) as int,
              following: (data['following'] ?? 0) as int,
              createdAt: createdAtStr,
            );
          }
        } catch (e) {
          debugPrint('유저 정보 로드 실패 (userId: $userId): $e');
        }
      }

      setState(() {
        _walks = filteredWalks;
        _userMap = userMap;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('피드 로드 실패: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadFeed,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '소셜 피드',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadFeed,
                      tooltip: '새로고침',
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
              )
            else if (_walks.isEmpty)
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.favorite,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '아직 산책 기록이 없습니다',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final walk = _walks[index];
                    final user = _userMap[walk.userId];
                    
                    return _buildWalkCard(walk, user);
                  },
                  childCount: _walks.length,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalkCard(Walk walk, User? user) {
    final userNickname = user?.nickname ?? '알 수 없음';
    final distance = walk.distance?.toStringAsFixed(2) ?? '0.00';
    final duration = walk.duration != null ? '${walk.duration! ~/ 60}분' : '-';
    final dateFormat = DateFormat('MM.dd (E)', 'ko_KR');
    final timeFormat = DateFormat('HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 작성자 정보
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: const Icon(Icons.person, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userNickname,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (user?.bio != null && user!.bio.isNotEmpty)
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
              ],
            ),
            const Divider(height: 24),
            // 산책 정보
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      dateFormat.format(walk.startTime),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      walk.mood ?? '😊',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ],
                ),
                Text(
                  timeFormat.format(walk.startTime),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${distance}km',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '총 $duration',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            if (walk.notes != null && walk.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                walk.notes!,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

