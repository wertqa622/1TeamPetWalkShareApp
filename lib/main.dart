import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'services/backgroundservice.dart';

// 화면들 import
import 'screens/login_screen.dart';
import 'screens/pet_management_screen.dart';
import 'screens/walk_tracking_screen.dart';
import 'screens/social_feed_screen.dart';
import 'screens/user_profile_screen.dart';
import 'models/user.dart' as model; // User 모델 이름 충돌 방지

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. 백그라운드 서비스 초기화 (위치 추적용)
  await initializeService();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '반려동물 산책 다이어리',
      debugShowCheckedModeBanner: false, // 오른쪽 위 디버그 띠 제거

      // ▼ 2. 한국어 지원 설정 추가 (이게 없으면 달력에서 앱이 죽습니다)
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'), // 한국어
        Locale('en', 'US'), // 영어
      ],
      // ▲ 여기까지 추가됨

      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2563EB),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        // 달력 테마 커스터마이징 (선택사항, 필요시 주석 해제)
        // datePickerTheme: const DatePickerThemeData(
        //   headerBackgroundColor: Color(0xFF2563EB),
        //   headerForegroundColor: Colors.white,
        // ),
      ),
      // 앱이 켜지면 AuthWrapper가 로그인 여부를 판단합니다.
      home: const AuthWrapper(),
    );
  }
}

// ---------------------------------------------------------
// [AuthWrapper] 로그인 상태에 따라 화면을 바꿔주는 신호등 역할
// ---------------------------------------------------------
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. 연결 상태 대기 중
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        // 2. 로그인 되어 있음 -> 탭 화면(MainScreen) 보여줌
        if (snapshot.hasData) {
          return const MainScreen();
        }
        // 3. 로그인 안 됨 -> 로그인 화면(LoginScreen) 보여줌
        return const LoginScreen();
      },
    );
  }
}

// ---------------------------------------------------------
// [MainScreen] 로그인 성공 후 보여질 탭 메뉴 화면
// ---------------------------------------------------------
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final String _uid = FirebaseAuth.instance.currentUser!.uid;
  
  // 사용자 데이터
  model.User? _currentUser;
  bool _isLoadingUser = true;

  // 탭별 화면 리스트
  List<Widget>? _screens;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final currentUserEmail = FirebaseAuth.instance.currentUser?.email ?? '';
      
      // Firestore에서 사용자 데이터 로드
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();

      model.User user;
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

        user = model.User(
          id: _uid,
          email: data['email'] ?? currentUserEmail,
          nickname: data['nickname'] ?? '사용자',
          bio: data['bio'] ?? '',
          locationPublic: data['locationPublic'] ?? true,
          followers: (data['followers'] ?? 0) as int,
          following: (data['following'] ?? 0) as int,
          createdAt: createdAtStr,
        );
      } else {
        // 사용자 문서가 없으면 생성
        user = model.User(
          id: _uid,
          email: currentUserEmail,
          nickname: '사용자',
          bio: '',
          locationPublic: true,
          followers: 0,
          following: 0,
          createdAt: DateTime.now().toIso8601String(),
        );
        
        // Firestore에 사용자 문서 생성
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_uid)
            .set(user.toJson());
      }

      // email 필드가 없으면 업데이트
      if (userDoc.exists && (userDoc.data()?['email'] == null || userDoc.data()?['email'] == '')) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_uid)
            .update({'email': currentUserEmail});
        user = user.copyWith(email: currentUserEmail);
      }

      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoadingUser = false;
          
          // 화면 리스트 생성
          _screens = [
            PetManagementScreen(userId: _uid),
            WalkTrackingScreen(userId: _uid),
            SocialFeedScreen(currentUser: user),
            UserProfileScreen(
              user: user,
              onUserUpdate: (updatedUser) {
                setState(() {
                  _currentUser = updatedUser;
                });
              },
            ),
          ];
        });
      }
    } catch (e) {
      debugPrint('사용자 데이터 로드 실패: $e');
      if (mounted) {
        final currentUserEmail = FirebaseAuth.instance.currentUser?.email ?? '';
        setState(() {
          _currentUser = model.User(
            id: _uid,
            email: currentUserEmail,
            nickname: '사용자',
            bio: '',
            locationPublic: true,
            followers: 0,
            following: 0,
            createdAt: DateTime.now().toIso8601String(),
          );
          _isLoadingUser = false;
          _screens = [
            PetManagementScreen(userId: _uid),
            WalkTrackingScreen(userId: _uid),
            SocialFeedScreen(currentUser: _currentUser!),
            UserProfileScreen(
              user: _currentUser!,
              onUserUpdate: (u) {
                setState(() {
                  _currentUser = u;
                });
              },
            ),
          ];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser || _screens == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      // IndexedStack: 탭을 이동해도 입력하던 내용이 사라지지 않게 유지
      body: IndexedStack(
        index: _currentIndex,
        children: _screens!,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -1))
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF2563EB),
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.pets), label: '홈'),
            BottomNavigationBarItem(icon: Icon(Icons.directions_walk), label: '산책'),
            BottomNavigationBarItem(icon: Icon(Icons.public), label: '피드'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: '프로필'),
          ],
        ),
      ),
    );
  }
}