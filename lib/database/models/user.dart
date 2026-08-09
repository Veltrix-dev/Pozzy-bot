import 'package:pozzy_bot/database/models/user_roles.dart';

class User {
  final int id;
  final int telegramId;
  final String? username;
  final String role;
  final String referralCode;
  final int? referredByTelegramId;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.telegramId,
    required this.username,
    required this.role,
    required this.referralCode,
    this.referredByTelegramId,
    required this.createdAt,
    required this.updatedAt
  });

  bool get isAdmin => UserRoles.isAdminRole(role);

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int,
      telegramId: map['telegram_id'] as int,
      username: map['username'] as String?,
      role: UserRoles.normalize(map['role'] as String?),
      referralCode: map['referral_code'] as String? ?? '',
      referredByTelegramId: map['referred_by_telegram_id'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

    User copyWith({
      int? id,
      int? telegramId,
      String? username,
      String? role,
      String? refferalCode,
      int? referredByTelegramId,
      DateTime? createdAt,
      DateTime? updatedAt
    }) {
      return User(
      id: id ?? this.id,
      telegramId: telegramId ?? this.telegramId,
      username: username ?? this.username,
      role: role ?? this.role,
      referralCode: refferalCode ?? this.referralCode,
      referredByTelegramId: referredByTelegramId ?? this.referredByTelegramId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      );
    }

    Map<String, dynamic> toMap() {
      return {
        'id': id,
        'telegram_id': telegramId,
        'username': username,
        'role': role,
        'referral_code': referralCode,
        'referred_by_telegram_id': referredByTelegramId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String()
      };
    }
}
