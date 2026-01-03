import '../models/user.dart';
import '../services/storage_service.dart';

class UserRepository {
  Future<User> getUser() async {
    return await StorageService.getOrCreateDefaultUser();
  }

  Future<void> updateUser(User user) async {
    await StorageService.saveCurrentUser(user);
  }
}

