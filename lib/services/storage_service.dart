import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class StorageService {
  static const String _currentUserKey = 'currentUser';

  static Future<User?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_currentUserKey);
    if (userJson != null) {
      return User.fromJson(json.decode(userJson) as Map<String, dynamic>);
    }
    return null;
  }

  static Future<void> saveCurrentUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserKey, json.encode(user.toJson()));
  }

  static Future<User> getOrCreateDefaultUser() async {
    final existingUser = await getCurrentUser();
    if (existingUser != null) {
      return existingUser;
    }

    final defaultUser = User(
      id: '1',
      nickname: '산책러버',
      bio: '우리 강아지와 함께하는 행복한 산책 🐕',
      locationPublic: true,
      followers: 12,
      following: 8,
      createdAt: DateTime.now().toIso8601String(),
    );

    await saveCurrentUser(defaultUser);
    return defaultUser;
  }
}


