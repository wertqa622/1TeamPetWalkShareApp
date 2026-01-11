import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:geolocator/geolocator.dart'; // [필수] 위치 기능

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
  Map<String, User> _userMap = {};
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
      Set<String> targetUserIds = await FollowService.getFollowingIds(widget.currentUser.id);
      targetUserIds.add(widget.currentUser.id);

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

      List<String> idList = targetUserIds.toList();
      List<List<String>> chunks = [];
      int chunkSize = 10;

      for (int i = 0; i < idList.length; i += chunkSize) {
        chunks.add(idList.sublist(
            i, i + chunkSize > idList.length ? idList.length : i + chunkSize));
      }

      List<QueryDocumentSnapshot> allDocs = [];

      List<Future<QuerySnapshot>> futures = chunks.map((chunk) {
        return FirebaseFirestore.instance
            .collection('walks')
            .where('userId', whereIn: chunk)
            .orderBy('startTime', descending: true)
            .limit(10)
            .get();
      }).toList();

      List<QuerySnapshot> snapshots = await Future.wait(futures);
      for (var snapshot in snapshots) {
        allDocs.addAll(snapshot.docs);
      }

      allDocs.sort((a, b) {
        String timeA = a['startTime'];
        String timeB = b['startTime'];
        return timeB.compareTo(timeA);
      });

      final filteredWalks = await WalkService.filterBlockedUsersWalks(
        allDocs,
        widget.currentUser.id,
      );

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

  // 통합된 검색 로직 (권한/위치/DB검색 모두 포함)
  Future<List<Map<String, dynamic>>> _loadNearbyWalkers() async {
    // 1. 위치 서비스 및 권한 확인
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // 서비스가 꺼져있으면 켜달라는 예외 발생 (사용자에게 알림용)
      throw Exception('위치 서비스를 켜주세요.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('위치 권한이 거부되었습니다.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('설정에서 위치 권한을 허용해주세요.');
    }

    // 2. 현재 위치 가져오기
    Position currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // 3. Firestore 검색 및 필터링 수행
    return _fetchNearbyWalkers(currentPosition);
  }

  // 모달 띄우기
  void _showNearbyWalkersModal() {
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '내 주변 1km 산책러 🐕',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                // 여기서 모든 로직을 수행
                future: _loadNearbyWalkers(),
                builder: (context, snapshot) {
                  // 로딩 중 표시
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            '내 위치 확인 및 주변 친구 찾는 중...',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  // 에러 처리
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          '${snapshot.error}'.replaceAll('Exception: ', ''),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    );
                  }

                  final nearbyUsers = snapshot.data ?? [];

                  if (nearbyUsers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.map_outlined, size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          const Text(
                            '반경 1km 내에 산책 중인 이웃이 없어요.\n먼저 산책을 시작해보세요!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: nearbyUsers.length,
                    itemBuilder: (context, index) {
                      final data = nearbyUsers[index];
                      final User user = data['user'];
                      final double distance = data['distance'];

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          child: const Icon(Icons.person, color: Colors.blue),
                        ),
                        title: Text(
                          user.nickname,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          user.bio.isNotEmpty ? user.bio : '안녕하세요!',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              '산책중',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${distance.toInt()}m',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          // 상세 프로필 이동 등 필요 시 구현
                        },
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
  }

  // [수정됨] Firestore 데이터 가져오기 및 거리 필터링 (순수 로직)
  Future<List<Map<String, dynamic>>> _fetchNearbyWalkers(Position myPos) async {
    try {
      // 1. 산책 중인 상태 값 수정 ('walking' -> 'on')
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('walkingStatus', isEqualTo: 'on')
          .get();

      List<Map<String, dynamic>> result = [];

      for (var doc in snapshot.docs) {
        // 나 자신은 제외
        if (doc.id == widget.currentUser.id) continue;

        final data = doc.data();

        // 2. 위치 데이터 필드 수정 (lastLocation -> latitude, longitude)
        if (data['latitude'] == null || data['longitude'] == null) continue;

        double otherLat = (data['latitude'] as num).toDouble();
        double otherLng = (data['longitude'] as num).toDouble();

        // 3. 거리 계산 (미터 단위)
        double distanceInMeters = Geolocator.distanceBetween(
          myPos.latitude,
          myPos.longitude,
          otherLat,
          otherLng,
        );

        // 4. 1km (1000m) 이내 필터링
        if (distanceInMeters <= 1000) {
          result.add({
            'user': User.fromJson(data),
            'distance': distanceInMeters,
          });
        }
      }

      // 가까운 순서대로 정렬
      result.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

      return result;
    } catch (e) {
      debugPrint('주변 유저 검색 실패: $e');
      return [];
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
                    // [수정됨] 주변 찾기 버튼 + 새로고침 버튼
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.map_outlined, color: Colors.blue),
                          tooltip: '내 주변 산책러 찾기',
                          onPressed: _showNearbyWalkersModal,
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _loadFeed,
                          tooltip: '새로고침',
                        ),
                      ],
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

/// 좋아요와 공유 기능을 관리하기 위한 별도 카드 위젯
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
    _likeCount = widget.walk.likeCount;
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
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    try {
      await WalkService.toggleLike(widget.walk.id, widget.currentUserId);
    } catch (e) {
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