import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  // 이메일 로그인
  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;
    setState(() { _isLoading = true; });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      ).timeout(const Duration(seconds: 5)); //로그인 타임아웃 5초
      // 로그인 성공 시 AuthWrapper가 자동으로 MainScreen으로 이동
    } on FirebaseAuthException catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('로그인 실패: ${e.code}')));
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  // 회원가입
  Future<void> _signUp() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      )
          .timeout(const Duration(seconds: 5)); //회원가입 타임아웃 5초
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('가입 성공!')));
    } on FirebaseAuthException catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('가입 실패: ${e.message}')));
    }
  }

  // 구글 로그인
  Future<void> _signInWithGoogle() async {
    setState(() { _isGoogleLoading = true; });

    try {
      // 1. 구글 팝업 띄우기
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        setState(() { _isGoogleLoading = false; });
        return; // 사용자가 취소함
      }

      // 2. 인증 정보(토큰) 가져오기
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. 파이어베이스용 자격 증명 만들기
      // (주의: 최신 버전은 accessToken이 필요 없고 idToken만 씁니다)
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: null,
      );

      // 4. 파이어베이스 로그인
      await FirebaseAuth.instance.signInWithCredential(credential);
      // 로그인 성공 시 AuthWrapper가 자동으로 MainScreen으로 이동
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('구글 로그인 실패: $e')),
      );
      debugPrint('에러 상세: $e'); // 콘솔에서 에러 확인용
    } finally {
      if (mounted) setState(() { _isGoogleLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.pets, size: 80, color: Colors.blue),
              const SizedBox(height: 16),
              const Text('반려동물 산책 다이어리', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: '이메일', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '비밀번호', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                child: _isLoading ? const CircularProgressIndicator() : const Text('로그인'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _isGoogleLoading ? null : _signInWithGoogle,
                style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                child: _isGoogleLoading
                    ? const CircularProgressIndicator()
                    : const Text('Google 로그인'),
              ),
              TextButton(onPressed: _signUp, child: const Text('회원가입')),
            ],
          ),
        ),
      ),
    );
  }
}