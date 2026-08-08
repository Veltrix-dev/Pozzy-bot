import 'package:pozzy_bot/config/config.dart';
import 'package:pozzy_bot/database/models/user.dart';
import 'package:pozzy_bot/database/models/user_roles.dart';
import 'package:pozzy_bot/database/repositories/user_repositories.dart';

class UserService {
  UserService(this._users);

  final UserRepositories _users;

Future<void> syncRoleFromEnv(int telegramId) async {
  final user = _users.findByTelegramId(telegramId);
  if(user == null) return;

  if(Config.initialAdminTelegramIds.contains(telegramId) &&
      user.role != UserRoles.admin) {
        _users.updateRole(telegramId, UserRoles.admin);
      } 
  }

  Future<User?> getOrCreate({
    required int telegramId,
    String? username,
    String? startReferralCode,
  }) async {
   final existing = _users.findByTelegramId(telegramId);
   if(existing != null) {
    await syncRoleFromEnv(telegramId);
    if (existing.username != username) {
      _users.updateUsername(telegramId, username);
    }
    return _users.findByTelegramId(telegramId)!;
   }

   final user = _users.insert(
    telegramId: telegramId,
    username: username,
     role: _users.roleForNewUser(telegramId)
     );
     
  return _users.findByTelegramId(telegramId);
  }

  Future<User?> find(int telegramId) async {
    return _users.findByTelegramId(telegramId);
  }

  Future<bool> isAdmin(int telegramId) async {
   final user = _users.findByTelegramId(telegramId);
   if(user == null) return false;

   await syncRoleFromEnv(telegramId);
   return _users.findByTelegramId(telegramId)!.isAdmin;
  }

  Future<String> getRoleDbValue(telegramId) async {
   final user =_users.findByTelegramId(telegramId);
   if(user == null) return UserRoles.user;

   await syncRoleFromEnv(telegramId);
   return _users.findByTelegramId(telegramId)!.role; 
  }
}
