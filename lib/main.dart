import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import 'screens/pet_management_screen.dart';
import 'screens/walk_tracking_screen.dart';
import 'screens/social_feed_screen.dart';
import 'screens/user_profile_screen.dart';
import 'screens/login_screen.dart';

import 'models/user.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '반려동물 산책 다이어리',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      // firebase_auth.User? 타입을 명시하고 사용합니다.
      home: StreamBuilder<firebase_auth.User?>(
        stream: firebase_auth.FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasData) {
            return const MainScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  User? _currentUser; // 이건 models/user.dart의 User입니다 (정상)
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await StorageService.getOrCreateDefaultUser();
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onUserUpdate(User user) {
    setState(() {
      _currentUser = user;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _currentUser == null) {
      return Scaffold(
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final screens = [
      PetManagementScreen(userId: _currentUser!.id),
      WalkTrackingScreen(userId: _currentUser!.id),
      SocialFeedScreen(currentUser: _currentUser!),
      UserProfileScreen(
        user: _currentUser!,
        onUserUpdate: _onUserUpdate,
      ),
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEFF6FF), Color(0xFFF3E8FF)],
          ),
        ),
        child: Column(
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.only(top: 50, bottom: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF9333EA)]),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
              ),
              width: double.infinity,
              child: Column(
                children: [
                  const Text('🐾 반려동물 산책 다이어리', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('${_currentUser!.nickname}님 환영합니다', style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            Expanded(child: screens[_currentIndex]),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: '산책'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_outline), label: '피드'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: '프로필'),
        ],
      ),
    );
  }
}