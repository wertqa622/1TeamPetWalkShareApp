import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart'; // [필수] 공유 기능을 위해 추가
import '../models/user.dart';
import '../models/walk.dart';
import '../services/walk_service.dart';
import '../services/follow_service.dart';

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
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. 내가 팔로우한 사용자들의 ID 목록 가져오기
      Set<String> targetUserIds = await FollowService.getFollowingIds(widget.currentUser.id);

      // 내 게시글도 피드에 포함 (선택사항 - 필요 없으면 주석 처리)
      targetUserIds.add(widget.currentUser.id);

      // 팔로우한 사람이 없으면 빈 화면 표시
      if (targetUserIds.isEmpty) {
        if (mounted) {
          setState(() {
            _walks = [];
            _userMap = {};
            _isLoading = false;
          });
        }
        return;
      }

      // 2. Firestore 'whereIn' 쿼리 제한(최대 10개) 해결을 위한 Chunking(쪼개기) 로직
      List<String> idList = targetUserIds.toList();
      List<List<String>> chunks = [];
      int chunkSize = 10;

      for (int i = 0; i < idList.length; i += chunkSize) {
        chunks.add(idList.sublist(
            i, i + chunkSize > idList.length ? idList.length : i + chunkSize));
      }

      List<QueryDocumentSnapshot> allDocs = [];

      // 병렬로 쿼리 실행
      List<Future<QuerySnapshot>> futures = chunks.map((chunk) {
        return FirebaseFirestore.instance
            .collection('walks')
            .where('userId', whereIn: chunk)
            .orderBy('startTime', descending: true)
            .limit(10) // 각 덩어리당 최근 10개씩 (조절 가능)
            .get();
      }).toList();

      List<QuerySnapshot> snapshots = await Future.wait(futures);
      for (var snapshot in snapshots) {
        allDocs.addAll(snapshot.docs);
      }

      // 3. 메모리 상에서 전체 다시 정렬 (여러 쿼리를 합쳤으므로 순서가 섞일 수 있음)
      allDocs.sort((a, b) {
        String timeA = a['startTime'];
        String timeB = b['startTime'];
        return timeB.compareTo(timeA); // 최신순 정렬
      });

      // 4. 차단 필터링 적용 (WalkService에 구현된 로직 사용)
      final filteredWalks = await WalkService.filterBlockedUsersWalks(
        allDocs,
        widget.currentUser.id,
      );

      // 5. walks의 작성자 정보 가져오기
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
            userMap[userId] = User.fromJson(data);
          }
        } catch (e) {
          debugPrint('유저 정보 로드 실패 (userId: $userId): $e');
        }
      }

      if (mounted) {
        setState(() {
          _walks = filteredWalks;
          _userMap = userMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('피드 로드 실패: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_walks.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '새로운 소식이 없습니다.',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '다른 사용자를 팔로우하여\n피드를 채워보세요!',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
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

                    // [수정됨] 별도의 위젯으로 분리하여 좋아요 상태 관리
                    return WalkCard(
                      walk: walk,
                      user: user,
                      currentUserId: widget.currentUser.id,
                    );
                  },
                  childCount: _walks.length,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// [추가됨] 좋아요와 공유 기능을 관리하기 위한 별도 카드 위젯
class WalkCard extends StatefulWidget {
  final Walk walk;
  final User? user;
  final String currentUserId;

  const WalkCard({
    super.key,
    required this.walk,
    required this.user,
    required this.currentUserId,
  });

  @override
  State<WalkCard> createState() => _WalkCardState();
}

class _WalkCardState extends State<WalkCard> {
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isLikeLoading = true;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.walk.likeCount; // Walk 모델에 likeCount가 있어야 함
    _checkIfLiked();
  }

  // 좋아요 여부 초기 확인
  Future<void> _checkIfLiked() async {
    try {
      final liked = await WalkService.isLiked(widget.walk.id, widget.currentUserId);
      if (mounted) {
        setState(() {
          _isLiked = liked;
          _isLikeLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLikeLoading = false);
    }
  }

  // 좋아요 버튼 클릭 핸들러
  Future<void> _handleLike() async {
    // 낙관적 업데이트 (UI 먼저 반영)
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    try {
      await WalkService.toggleLike(widget.walk.id, widget.currentUserId);
    } catch (e) {
      // 실패 시 롤백
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _likeCount += _isLiked ? 1 : -1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오류가 발생했습니다.')),
        );
      }
    }
  }

  // 공유 버튼 클릭 핸들러
  void _handleShare() {
    WalkService.shareWalk(widget.walk, widget.user?.nickname ?? '알 수 없음');
  }

  @override
  Widget build(BuildContext context) {
    final userNickname = widget.user?.nickname ?? '알 수 없음';
    final distance = widget.walk.distance?.toStringAsFixed(2) ?? '0.00';
    final duration = widget.walk.duration != null ? '${widget.walk.duration! ~/ 60}분' : '-';
    final dateFormat = DateFormat('MM.dd (E)', 'ko_KR');
    final timeFormat = DateFormat('HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 헤더: 프로필 + 닉네임 + 공유버튼
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
                      if (widget.user?.bio != null && widget.user!.bio.isNotEmpty)
                        Text(
                          widget.user!.bio,
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
                // [공유 버튼 추가]
                IconButton(
                  icon: const Icon(Icons.share_outlined, color: Colors.grey),
                  onPressed: _handleShare,
                  tooltip: '공유하기',
                ),
              ],
            ),
            const Divider(height: 24),

            // 2. 본문: 날짜 + 기분
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      dateFormat.format(widget.walk.startTime),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.walk.mood ?? '😊',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ],
                ),
                Text(
                  timeFormat.format(widget.walk.startTime),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 3. 뱃지: 거리 + 시간
            Row(
              children: [
                _buildBadge('${distance}km'),
                const SizedBox(width: 8),
                _buildBadge('총 $duration'),
              ],
            ),

            // 4. 메모
            if (widget.walk.notes != null && widget.walk.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                widget.walk.notes!,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 16),

            // 5. 하단 액션: 좋아요
            Row(
              children: [
                InkWell(
                  onTap: _handleLike,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Row(
                      children: [
                        Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_border,
                          color: _isLiked ? Colors.red : Colors.grey,
                          size: 24,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$_likeCount',
                          style: TextStyle(
                            color: _isLiked ? Colors.red : Colors.grey[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }
}