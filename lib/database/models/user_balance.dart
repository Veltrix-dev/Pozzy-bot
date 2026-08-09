class UserBalance {
  UserBalance({
    required this.telegramId,
    required this.balance,
    required this.updatedAt,
  });

  final int telegramId;
  final double balance;
  final DateTime updatedAt;

  factory UserBalance.empty(int telegramId) {
    return UserBalance(
      telegramId: telegramId,
      balance: 0,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  factory UserBalance.fromMap(Map<String, dynamic> map) {
    return UserBalance(
      telegramId: map['telegram_id'] as int,
      balance: (map['balance'] as num).toDouble(),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'telegram_id': telegramId,
      'balance': balance,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
