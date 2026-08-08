import 'package:pozzy_bot/config/config.dart';
import 'package:pozzy_bot/database/database.dart';
import 'package:pozzy_bot/database/models/user.dart';
import 'package:pozzy_bot/database/models/user_roles.dart';
import 'package:pozzy_bot/utils/referral_code_generator.dart';
import 'package:sqlite3/sqlite3.dart';

class UserRepositories {
  UserRepositories();

  Database get _db => AppDatabase.instance;

  User? findByTelegramId(int telegramId) {
    final result = _db.select('SELECT * FROM users WHERE telegram_id = ?;', [
      telegramId
    ]);
    if (result.isEmpty) return null;
    return User.fromMap(result.first);
  }

  User? findByUsername(String username) {
    final rows = _db.select(
      'SELECT * FROM users WHERE LOWER(username) = LOWER(?) LIMIT 1;',
      [username],
    );
    if(rows.isEmpty) return null;
    return User.fromMap(rows.first);
  }

  User? findByReferralCode(String referralCode) {
    final normalized = referralCode.trim().toUpperCase();
    if (normalized.isEmpty) return null;

    final rows = _db.select(
      '''
      SELECT * FROM users
      WHERE referral_code = ? COLLATE NOCASE
      LIMIT 1;
      ''',
      [normalized]
    );
    if (rows.isEmpty) return null;
    return User.fromMap(rows.first);
  }

  User insert({
    required int telegramId,
    String? username,
    required String role,
  }) {
     final now = DateTime.now().toUtc();
     final iso = now.toIso8601String();
     final referralCode = ReferralCodeGenerator.generateUnique(_db);

     _db.execute(
    '''
      INSERT INTO users (
        telegram_id,
        username,
        role,
        referral_code,
        created_at,
        updated_at
      )
      VALUES (?, ?, ?, ?, ?, ?);
      ''',
      [telegramId, username, role, referralCode, iso, iso],
     );

     final id = _db.lastInsertRowId;
     return User(
      id: id,
      telegramId: telegramId,
      username: username,
      role: role,
      referralCode: referralCode,
      createdAt: now,
      updatedAt: now,
     );
  }

  String roleForNewUser(int telegramId) {
    return Config.initialAdminTelegramIds.contains(telegramId) 
    ? UserRoles.admin
    : UserRoles.user;
  }

  void updateUsername(int telegramId, String? username) {
    final iso = DateTime.now().toUtc().toIso8601String();
    _db.execute(
      'UPDATE users SET username = ?, updated_at = ? WHERE telegram_id = ?;',
      [username, iso, telegramId],
    );
  }

  void updateRole(int telegramId, String? role) {
    final iso = DateTime.now().toUtc().toIso8601String();
    _db.execute(
      'UPDATE users SET role = ?, updated_at = ? WHERE telegram_id = ?;',
      [role, iso, telegramId],
    );
  }


  List<User> findAllByRole(String role) {
    final rows = _db.select(
       '''
      SELECT * FROM users
      WHERE role = ?
      ORDER BY created_at ASC;
      ''',
      [role],
    );
    return rows.map(User.fromMap).toList();
  }

  List<int> listAllTelegramIds() {
    final rows = _db.select(
      'SELECT telegram_id FROM users ORDER BY created_at ASC;',
    );
    return rows.map((row) => row['telegram_id'] as int).toList();
  }
}
