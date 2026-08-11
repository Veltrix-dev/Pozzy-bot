class UserBalance {
  UserBalance({
    required this.telegramId,
    required this.balanceMicros,
    required this.updatedAt,
  });

  final int telegramId;
  final int balanceMicros;
  final DateTime updatedAt;

  double get balance => balanceMicros / 1000000;

  factory UserBalance.empty(int telegramId) {
    return UserBalance(
      telegramId: telegramId,
      balanceMicros: 0,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  factory UserBalance.fromMap(Map<String, dynamic> map) {
    return UserBalance(
      telegramId: map['telegram_id'] as int,
      balanceMicros: map['balance_micros'] as int,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'telegram_id': telegramId,
      'balance': balance,
      'balance_micros': balanceMicros,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
